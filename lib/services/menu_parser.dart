import '../models/option_group.dart';

/// Résultat d'un import : des catégories (avec leurs plats) + une liste de
/// suppléments globaux détectés dans une section « Suppléments ».
class ParsedMenu {
  final List<ParsedCategory> categories;
  final List<OptionChoice> globalSupplements;

  ParsedMenu({required this.categories, required this.globalSupplements});

  int get itemCount =>
      categories.fold(0, (sum, c) => sum + c.items.length);
}

class ParsedCategory {
  String name;
  final List<ParsedItem> items;
  ParsedCategory({required this.name, List<ParsedItem>? items})
      : items = items ?? [];
}

class ParsedItem {
  String name;
  int basePrice;
  int? menuPrice; // si une formule "menu" est détectée
  // Tailles (Tacos) : ordre d'apparition + prix par taille. Vide = plat sans
  // tailles. La 1re taille (M) fixe le prix de base ; les autres deviennent un
  // supplément (delta) dans le groupe « Taille ».
  final List<MapEntry<String, int>> sizes;

  ParsedItem({
    required this.name,
    required this.basePrice,
    this.menuPrice,
    List<MapEntry<String, int>>? sizes,
  }) : sizes = sizes ?? [];

  bool get hasSizes => sizes.isNotEmpty;

  /// Ajoute (ou met à jour) le prix d'une taille et recale le prix de base
  /// sur la première taille rencontrée (la plus petite).
  void addSize(String size, int price) {
    final i = sizes.indexWhere((e) => e.key == size);
    if (i >= 0) {
      sizes[i] = MapEntry(size, price);
    } else {
      sizes.add(MapEntry(size, price));
    }
    basePrice = sizes.first.value;
  }

  /// Modifie le prix de base depuis l'aperçu (synchronise la 1re taille).
  void setBasePrice(int price) {
    if (hasSizes) sizes[0] = MapEntry(sizes[0].key, price);
    basePrice = price;
  }

  /// Construit les groupes d'options pour ce plat :
  /// - « Taille » (single, requis) si des tailles ont été détectées ;
  /// - « Formule » (single) si un prix menu a été détecté.
  List<OptionGroup> buildOptionGroups() {
    final groups = <OptionGroup>[];
    if (hasSizes) {
      final base = sizes.first.value;
      groups.add(OptionGroup(
        name: 'Taille',
        type: OptionType.single,
        required: true,
        choices: [
          for (final e in sizes) OptionChoice(name: e.key, price: e.value - base),
        ],
      ));
    }
    if (menuPrice != null && menuPrice! > basePrice) {
      groups.add(OptionGroup(
        name: 'Formule',
        type: OptionType.single,
        required: false,
        choices: [
          const OptionChoice(name: 'Seul', price: 0),
          OptionChoice(name: 'Menu', price: menuPrice! - basePrice),
        ],
      ));
    }
    return groups;
  }
}

/// Parser heuristique d'un menu collé en texte (best-effort, éditable ensuite).
///
/// Reconnaît :
/// - les en-têtes de catégorie (lignes en majuscules, ex. « HAMBURGERS (…) »)
/// - les plats « Nom : 600 FDJ (menu 900 FDJ) »
/// - une section « Suppléments » → choix d'options réutilisables
class MenuParser {
  static final _itemRegex = RegExp(
    r'^(.+?)\s*:\s*\+?\s*([\d][\d\s.]*)\s*FDJ',
    caseSensitive: false,
  );
  static final _menuPriceRegex = RegExp(
    r'menu\s*\+?\s*([\d][\d\s.]*)\s*FDJ',
    caseSensitive: false,
  );

  static ParsedMenu parse(String raw) {
    final categories = <ParsedCategory>[];
    final supplements = <OptionChoice>[];
    ParsedCategory? current;
    var inSupplements = false;
    var firstContentSeen = false;
    String? currentSize; // suffixe de taille actif (Tacos M/L/XL)

    for (final line in raw.split('\n')) {
      final l = line.trim();
      if (l.isEmpty) continue;

      // 1. Titre global du menu (1re ligne type "… MENU COMPLET")
      if (!firstContentSeen &&
          RegExp(r'menu\s+complet', caseSensitive: false).hasMatch(l)) {
        firstContentSeen = true;
        continue;
      }
      firstContentSeen = true;

      // 2. Ligne de plat / supplément (avec prix « … : 600 FDJ »)
      final m = _itemRegex.firstMatch(l);
      if (m != null) {
        final name = m.group(1)!.trim();
        final price = _toInt(m.group(2)!);
        if (inSupplements) {
          supplements.add(OptionChoice(name: name, price: price));
        } else {
          current ??= _pushCategory(categories, 'Autres');
          int? menuPrice;
          final mm = _menuPriceRegex.firstMatch(l);
          if (mm != null) menuPrice = _toInt(mm.group(1)!);

          if (currentSize != null) {
            // Tacos M/L/XL : la même garniture revient sous chaque taille →
            // on fusionne en UN seul plat avec un groupe d'options « Taille ».
            final existing = current.items.where(
              (it) => it.name.toLowerCase() == name.toLowerCase(),
            );
            if (existing.isNotEmpty) {
              existing.first.addSize(currentSize, price);
            } else {
              current.items.add(
                ParsedItem(name: name, basePrice: price)
                  ..addSize(currentSize, price),
              );
            }
          } else {
            current.items.add(ParsedItem(
              name: name,
              basePrice: price,
              menuPrice: menuPrice,
            ));
          }
        }
        continue;
      }

      // 3. Note de taille (Tacos) : « Taille L (prix de base = 1600 FDJ) »
      final sizeMatch =
          RegExp(r'^taille\s+(\S+)', caseSensitive: false).firstMatch(l);
      if (sizeMatch != null) {
        currentSize = sizeMatch.group(1)!.toUpperCase();
        continue;
      }
      // Autre note de prix de base sans taille — ignorée
      if (RegExp(r'prix de base', caseSensitive: false).hasMatch(l)) {
        continue;
      }

      // 4. En-tête de section/catégorie : uniquement les lignes "titre"
      //    (majuscules dominantes). Évite d'avaler les notes inline du type
      //    « Suppléments possibles : Emmental, Cheddar… ».
      if (_isHeader(l)) {
        currentSize = null;
        if (RegExp(r'^suppl[ée]ments', caseSensitive: false).hasMatch(l)) {
          inSupplements = true;
          current = null;
        } else {
          inSupplements = false;
          current = _pushCategory(categories, _cleanCategoryName(l));
        }
      }
      // Sinon : ligne descriptive/note — ignorée.
    }

    // Retirer les catégories vides
    categories.removeWhere((c) => c.items.isEmpty);
    return ParsedMenu(categories: categories, globalSupplements: supplements);
  }

  /// Un en-tête est une ligne « titre » : une fois la parenthèse retirée,
  /// les lettres sont majoritairement en MAJUSCULES.
  static bool _isHeader(String line) {
    final base = line.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    final letters = base.replaceAll(RegExp(r'[^A-Za-zÀ-ÿ]'), '');
    if (letters.length < 3) return false;
    var upper = 0;
    for (final ch in letters.split('')) {
      if (ch == ch.toUpperCase() && ch != ch.toLowerCase()) upper++;
    }
    return upper / letters.length >= 0.6;
  }

  static ParsedCategory _pushCategory(
      List<ParsedCategory> categories, String name) {
    // Réutiliser une catégorie déjà ouverte avec le même nom
    final existing = categories.where(
      (c) => c.name.toLowerCase() == name.toLowerCase(),
    );
    if (existing.isNotEmpty) return existing.first;
    final cat = ParsedCategory(name: name);
    categories.add(cat);
    return cat;
  }

  static String _cleanCategoryName(String raw) {
    // Retirer la parenthèse explicative, puis Title Case
    var s = raw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    s = s.replaceAll(RegExp(r'[:–-]+$'), '').trim();
    if (s.isEmpty) return 'Autres';
    return s
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty
            ? w
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  static int _toInt(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digits) ?? 0;
  }
}
