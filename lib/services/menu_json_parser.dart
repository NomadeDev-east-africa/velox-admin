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
      final rawItems = menu[catName];
      if (rawItems is! List) continue;

      final cat = ParsedCategory(name: catName);
      for (final item in rawItems) {
        if (item is! Map) continue;
        if (item.containsKey('taille') || item.containsKey('base')) {
          _addSizedItem(cat, catName, item); // ex. Tacos M/L/XL
        } else {
          final name = (item['nom'] ?? item['name'])?.toString().trim();
          if (name == null || name.isEmpty) continue;
          cat.items.add(ParsedItem(
            name: name,
            basePrice:
                _toInt(item['prix_seul'] ?? item['prix'] ?? item['price']),
            menuPrice: _toIntOrNull(item['prix_menu']),
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
    ];

    final item =
        ParsedItem(name: itemName, basePrice: base, extraGroups: extraGroups);
    if (size.isNotEmpty) item.addSize(size, base);
    cat.items.add(item);
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) {
      return int.tryParse(v.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    }
    return 0;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    final n = _toInt(v);
    return n == 0 ? null : n;
  }
}
