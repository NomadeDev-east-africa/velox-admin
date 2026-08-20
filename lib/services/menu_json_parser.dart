import 'dart:convert';

import '../models/option_group.dart';
import 'menu_parser.dart';

/// Parser du **schéma JSON standard** (produit par une IA : DeepSeek, Claude…).
///
/// Contrairement au parser texte heuristique, ce schéma est déterministe et
/// couvre n'importe quel menu, quelle que soit sa mise en forme d'origine :
///
/// ```json
/// {
///   "categories": ["Burgers", "Tacos", "Boissons"],
///   "menu": {
///     "Burgers": [ { "nom": "Cheeseburger", "prix_seul": 800, "prix_menu": 1100 } ],
///     "Boissons": [ { "nom": "Coca", "prix": 250 } ],
///     "Tacos":   [ { "taille": "M", "base": 1100,
///                    "supplements": { "Kebab": 400 }, "extra": 100 } ],
///     "supplements": [ { "nom": "Cheddar", "prix": 100 } ]
///   }
/// }
/// ```
///
/// Le résultat alimente le même [ParsedMenu] que le parser texte → l'aperçu
/// éditable, les images de catégorie et la sélection des suppléments par
/// catégorie fonctionnent à l'identique.
class MenuJsonParser {
  /// Tente de parser [raw] comme JSON du schéma standard.
  /// Retourne `null` si ce n'est pas du JSON exploitable (l'appelant retombe
  /// alors sur [MenuParser.parse]).
  static ParsedMenu? tryParse(String raw) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{')) return null;

    dynamic decoded;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
    if (decoded is! Map || decoded['menu'] is! Map) return null;
    final menu = decoded['menu'] as Map;

    // 1. Suppléments globaux (section « supplements » à la racine du menu).
    final globalSupplements = <OptionChoice>[];
    final rawSupp = menu['supplements'];
    if (rawSupp is List) {
      for (final s in rawSupp) {
        if (s is Map) {
          final name = (s['nom'] ?? s['name'])?.toString();
          if (name != null && name.trim().isNotEmpty) {
            globalSupplements.add(
                OptionChoice(name: name.trim(), price: _toInt(s['prix'] ?? s['price'])));
          }
        }
      }
    }

    // 2. Ordre des catégories : champ « categories » d'abord, puis tout reste
    //    présent dans « menu » (hors clé « supplements »).
    final orderedNames = <String>[];
    final catOrder = decoded['categories'];
    if (catOrder is List) {
      for (final c in catOrder) {
        if (c != null) orderedNames.add(c.toString());
      }
    }
    for (final k in menu.keys) {
      final key = k.toString();
      if (key.toLowerCase() != 'supplements' && !orderedNames.contains(key)) {
        orderedNames.add(key);
      }
    }

    // 3. Catégories et plats.
    final categories = <ParsedCategory>[];
    for (final catName in orderedNames) {
      if (catName.toLowerCase() == 'supplements') continue;
      final rawItems = menu[catName]; // clé JSON d'origine (pour le lookup)
      if (rawItems is! List) continue;

      // Nom affiché standardisé (« Nos Glace » → « Glaces ») ; la clé d'origine
      // reste utilisée pour retrouver les plats dans `menu`.
      final displayName = MenuParser.standardizeCategoryName(catName);
      final cat = ParsedCategory(name: displayName);
      for (final item in rawItems) {
        if (item is! Map) continue;
        if (item.containsKey('taille') || item.containsKey('base')) {
          _addSizedItem(cat, displayName, item); // ex. Tacos M/L/XL
        } else {
          final name = (item['nom'] ?? item['name'])?.toString().trim();
          if (name == null || name.isEmpty) continue;
          cat.items.add(ParsedItem(
            name: name,
            basePrice:
                _toInt(item['prix_seul'] ?? item['prix'] ?? item['price']),
            menuPrice: _toIntOrNull(item['prix_menu']),
            // Groupes d'options explicites déclarés sur le plat (garnitures,
            // boisson incluse, choix de pâtes, sauces…).
            extraGroups: _parseOptions(item['options']),
          ));
        }
      }
      if (cat.items.isNotEmpty) categories.add(cat);
    }

    return ParsedMenu(
      categories: categories,
      globalSupplements: globalSupplements,
      // Le schéma ne cible pas de catégories pour les suppléments globaux →
      // laissé « non spécifié » : l'écran applique un défaut intelligent
      // (exclut boissons/desserts) et reste éditable.
    );
  }

  /// Plat à tailles (Tacos…) : fusionne les entrées M/L/XL en UN seul plat
  /// avec un groupe « Taille », et porte ses suppléments propres.
  static void _addSizedItem(ParsedCategory cat, String catName, Map raw) {
    final nm = (raw['nom'] ?? raw['name'])?.toString().trim();
    final itemName = (nm != null && nm.isNotEmpty) ? nm : catName;
    final size = (raw['taille'] ?? raw['size'])?.toString().trim() ?? '';
    final base = _toInt(raw['base'] ?? raw['prix_seul'] ?? raw['prix']);

    // Réutiliser le plat déjà créé (même nom) pour y empiler les tailles.
    final existing =
        cat.items.where((it) => it.name.toLowerCase() == itemName.toLowerCase());
    if (existing.isNotEmpty) {
      if (size.isNotEmpty) existing.first.addSize(size, base);
      return;
    }

    // Première occurrence : construire ses suppléments propres.
    final choices = <OptionChoice>[];
    final supp = raw['supplements'];
    if (supp is Map) {
      supp.forEach((k, v) =>
          choices.add(OptionChoice(name: k.toString(), price: _toInt(v))));
    }
    final extra = _toInt(raw['extra']);
    if (extra > 0) {
      choices.add(OptionChoice(name: 'Ingrédient extra', price: extra));
    }
    final extraGroups = <OptionGroup>[
      if (choices.isNotEmpty)
        OptionGroup(
          name: 'Suppléments',
          type: OptionType.multiple,
          required: false,
          choices: choices,
        ),
      // Groupes d'options explicites éventuels (mêmes que pour un plat simple).
      ..._parseOptions(raw['options']),
    ];

    final item =
        ParsedItem(name: itemName, basePrice: base, extraGroups: extraGroups);
    if (size.isNotEmpty) item.addSize(size, base);
    cat.items.add(item);
  }

  /// Parse un tableau d'**options explicites** déclaré sur un plat dans le JSON
  /// et le convertit en [OptionGroup]s (rattachés au plat via `extraGroups`).
  ///
  /// Permet d'exprimer ce que la génération automatique ne devine pas : choix de
  /// garniture (crêpe), boisson incluse, type de pâtes, sauces au choix…
  ///
  /// Schéma tolérant (clés FR ou EN) :
  /// ```json
  /// "options": [
  ///   { "nom": "Garniture", "type": "single", "obligatoire": true,
  ///     "choix": [ { "nom": "Nutella", "prix": 0 }, { "nom": "Miel", "prix": 0 } ] },
  ///   { "nom": "Sauces", "type": "multiple",
  ///     "choix": [ { "nom": "Roquefort", "prix": 600 } ] }
  /// ]
  /// ```
  /// - `type` : « single »/« unique » → choix unique ; sinon multiple.
  /// - `obligatoire`/`required`/`requis` : booléen (défaut false).
  /// - `maxChoices`/`max`/`nombre` : plafond de sélection pour un groupe multiple
  ///   (ex. Tacos XL → 2). Ignoré pour un groupe `single`. Défaut 0 = illimité.
  /// - `choix`/`choices` : liste d'objets `{nom, prix}` ou de simples chaînes.
  /// - `prix` d'un choix = supplément (0 = inclus). Un choix d'option ne reçoit
  ///   AUCUNE marge (contrairement aux plats principaux).
  static List<OptionGroup> _parseOptions(dynamic raw) {
    if (raw is! List) return const [];
    final groups = <OptionGroup>[];
    for (final g in raw) {
      if (g is! Map) continue;
      final name = (g['nom'] ?? g['name'])?.toString().trim();
      if (name == null || name.isEmpty) continue;
      final typeStr = (g['type'] ?? '').toString().toLowerCase();
      final type = (typeStr == 'single' || typeStr == 'unique')
          ? OptionType.single
          : OptionType.multiple;
      final required =
          (g['obligatoire'] ?? g['required'] ?? g['requis']) == true;
      // Plafond de sélection (groupes multiples) : maxChoices / max / nombre.
      final rawMax = g['maxChoices'] ?? g['max'] ?? g['nombre'];
      final maxChoices = rawMax is num ? rawMax.toInt() : 0;
      final rawChoices = g['choix'] ?? g['choices'];
      final choices = <OptionChoice>[];
      if (rawChoices is List) {
        for (final c in rawChoices) {
          if (c is Map) {
            final cn = (c['nom'] ?? c['name'])?.toString().trim();
            if (cn == null || cn.isEmpty) continue;
            choices.add(
                OptionChoice(name: cn, price: _toInt(c['prix'] ?? c['price'])));
          } else if (c is String && c.trim().isNotEmpty) {
            choices.add(OptionChoice(name: c.trim(), price: 0));
          }
        }
      }
      if (choices.isEmpty) continue;
      groups.add(OptionGroup(
          name: name,
          type: type,
          required: required,
          maxChoices: type == OptionType.multiple ? maxChoices : 0,
          choices: choices));
    }
    return groups;
  }

  // Tous les prix passent par la grille [MenuParser.markupPrice] : règle unique
  // « < 300 → +0, sinon marge par tranche », appliquée à chaque article (plats
  // ET choix d'options — la règle < 300 exempte d'elle-même sauces/suppléments).
  static int _toInt(dynamic v) {
    int raw;
    if (v is int) {
      raw = v;
    } else if (v is num) {
      raw = v.round();
    } else if (v is String) {
      raw = int.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    } else {
      raw = 0;
    }
    return MenuParser.markupPrice(raw);
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    final n = _toInt(v);
    return n == 0 ? null : n;
  }
}
