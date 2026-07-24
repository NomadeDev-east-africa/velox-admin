import '../models/option_group.dart';

/// Résultat d'un import : des catégories (avec leurs plats) + une liste de
/// suppléments globaux détectés dans une section « Suppléments ».
class ParsedMenu {
  final List<ParsedCategory> categories;
  final List<OptionChoice> globalSupplements;

  /// Noms de catégories (normalisés en minuscules) auxquelles les suppléments
  /// doivent s'appliquer, tels que listés entre parenthèses après le titre
  /// « Suppléments » (ex. « SUPPLÉMENTS (Hamburgers, Tacos) »).
  final List<String> supplementCategories;

  /// `true` si une liste de catégories a été précisée dans le fichier.
  /// Permet de distinguer « aucune catégorie précisée » (→ rétro-compat :
  /// appliquer à toutes) de « catégories explicitement listées ».
  final bool supplementCategoriesSpecified;

  ParsedMenu({
    required this.categories,
    required this.globalSupplements,
    this.supplementCategories = const [],
    this.supplementCategoriesSpecified = false,
  });

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

  /// Groupes d'options déjà construits, propres à ce plat (ex. suppléments
  /// d'un Tacos issus de l'import JSON). Le parser texte le laisse vide ;
  /// ils sont ajoutés tels quels par [buildOptionGroups].
  final List<OptionGroup> extraGroups;

  ParsedItem({
    required this.name,
    required this.basePrice,
    this.menuPrice,
    List<MapEntry<String, int>>? sizes,
    List<OptionGroup>? extraGroups,
  })  : sizes = sizes ?? [],
        extraGroups = extraGroups ?? [];

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
    groups.addAll(extraGroups);
    return groups;
  }
}

/// Parser heuristique d'un menu collé en texte (best-effort, éditable ensuite).
///
/// Reconnaît :
/// - les en-têtes de catégorie (lignes en majuscules, ex. « HAMBURGERS (…) »)
/// - les plats « Nom : 600 FDJ (menu 900 FDJ) » OU « Nom – 1800 FJ »
///   (séparateur deux-points OU tiret/​demi-cadratin ; devise FDJ, FJ ou DJF)
/// - une section « Suppléments » → choix d'options réutilisables
class MenuParser {
  // Séparateur nom/prix : « : » ou tiret « - », demi-cadratin « – », cadratin « — ».
  // Devise : FDJ, FJ ou DJF.
  static final _itemRegex = RegExp(
    r'^(.+?)\s*[:–—-]\s*\+?\s*([\d][\d\s.,]*)\s*(?:FDJ|FJ|DJF)\b',
    caseSensitive: false,
  );
  static final _menuPriceRegex = RegExp(
    r'menu\s*\+?\s*([\d][\d\s.,]*)\s*(?:FDJ|FJ|DJF)\b',
    caseSensitive: false,
  );

  static ParsedMenu parse(String raw) {
    final categories = <ParsedCategory>[];
    final supplements = <OptionChoice>[];
    final supplementCategories = <String>[];
    var supplementCategoriesSpecified = false;
    ParsedCategory? current;
    var inSupplements = false;
    var firstContentSeen = false;
    String? currentSize; // suffixe de taille actif (Tacos M/L/XL)
    // Dernière ligne « texte » sans prix : sert de nom de repli quand le plat a
    // son nom sur une ligne et son prix sur la suivante (ex. menu Davido :
    // « Yassa poulet ou poisson » / « (accompagnement riz blanc) – 3500 FJ »).
    String? pendingName;

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
        var name = m.group(1)!.trim();
        // Le « nom » n'est qu'une parenthèse de description (le vrai nom était
        // sur la ligne précédente) → reprendre cette ligne précédente.
        if (name.startsWith('(') && pendingName != null) {
          name = pendingName;
        }
        pendingName = null;
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
        pendingName = null;
        if (RegExp(r'^suppl[ée]ments', caseSensitive: false).hasMatch(l)) {
          inSupplements = true;
          current = null;
          // Catégories ciblées entre parenthèses : « Suppléments (Hamburgers,
          // Tacos) ». Sans parenthèse → suppléments globaux (rétro-compat).
          final paren = RegExp(r'\(([^)]*)\)').firstMatch(l);
          if (paren != null) {
            // Tolère un préfixe « pour : » avant la liste.
            final inside = paren.group(1)!.replaceFirst(
                RegExp(r'^\s*pour\s*:?\s*', caseSensitive: false), '');
            final names = inside
                .split(RegExp(r'[,;/]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
            if (names.isNotEmpty) {
              supplementCategoriesSpecified = true;
              for (final n in names) {
                supplementCategories.add(standardizeCategoryName(n).toLowerCase());
              }
            }
          }
        } else {
          inSupplements = false;
          current = _pushCategory(categories, standardizeCategoryName(l));
        }
      } else if (!l.startsWith('(')) {
        // Ligne « texte » sans prix ni en-tête : nom potentiel d'un plat dont
        // le prix figure sur la ligne suivante. (On ignore les parenthèses,
        // qui sont des descriptions.)
        pendingName = l;
      }
      // Sinon : ligne descriptive/note — ignorée.
    }

    // Retirer les catégories vides
    categories.removeWhere((c) => c.items.isEmpty);
    return ParsedMenu(
      categories: categories,
      globalSupplements: supplements,
      supplementCategories: supplementCategories,
      supplementCategoriesSpecified: supplementCategoriesSpecified,
    );
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

  /// Nom de catégorie standardisé (partagé par le parser texte et le parser
  /// JSON) :
  /// - la parenthèse explicative et la ponctuation de fin sont retirées ;
  /// - un préfixe possessif « Nos »/« Notre » est retiré (« Nos Burgers » →
  ///   « Burgers ») ;
  /// - chaque mot significatif est mis au pluriel (« Glace » → « Glaces ») ;
  /// - Title Case.
  static String standardizeCategoryName(String raw) {
    var s = raw.replaceAll(RegExp(r'\(.*?\)'), '').trim();
    s = s.replaceAll(RegExp(r'[:–-]+$'), '').trim();
    // Préfixe possessif retiré (« Nos Burgers » → « Burgers »).
    s = s.replaceFirst(RegExp(r'^(nos|notre)\s+', caseSensitive: false), '');
    if (s.isEmpty) return 'Autres';
    return s
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => _capitalize(_pluralize(w)))
        .join(' ');
  }

  // Petits mots (articles, prépositions, conjonctions) laissés invariables.
  static const _invariantWords = {
    'de', 'du', 'des', 'd', 'la', 'le', 'les', 'l', 'au', 'aux', 'a', 'à',
    'et', 'ou', 'en', 'sur', 'par', 'pour', 'avec', 'sans', 'un', 'une',
  };

  /// Met un mot français au pluriel selon une heuristique simple.
  static String _pluralize(String w) {
    final lower = w.toLowerCase();
    if (lower.length < 3 || _invariantWords.contains(lower)) return w;
    // Déjà au pluriel (…s / …x / …z).
    if (lower.endsWith('s') || lower.endsWith('x') || lower.endsWith('z')) {
      return w;
    }
    // …eau / …eu → …eaux / …eux (gâteau → gâteaux).
    if (lower.endsWith('eau') || lower.endsWith('eu')) return '${w}x';
    // …al → …aux (cheval → chevaux).
    if (lower.endsWith('al')) return '${w.substring(0, w.length - 2)}aux';
    return '${w}s';
  }

  static String _capitalize(String w) => w.isEmpty
      ? w
      : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';

  /// Grille tarifaire : marge FIXE ajoutée au prix brut resto, par tranche de
  /// prix. Remplace l'ancien +10 %. Un prix nul (non renseigné) reste nul.
  ///
  /// | Tranche (brut)  | Marge |
  /// |---|---|
  /// | < 300           | +0    |
  /// | 300 – 799       | +50   |
  /// | 800 – 1399      | +100  |
  /// | 1400 – 1849     | +150  |
  /// | 1850 – 2349     | +200  |
  /// | 2350 – 2849     | +250  |
  /// | 2850 – 3399     | +300  |
  /// | 3400 – 3849     | +350  |
  /// | 3850 – 4399     | +400  |
  /// | 4400 – 4849     | +500  |
  /// | 4850 – 7999     | +600  |
  /// | 8000 – 9999     | +1000 |
  /// | 10000 – 19999   | +1500 |
  /// | 20000 – 29999   | +2000 |
  /// | ≥ 30000         | +2500 |
  ///
  /// Les bornes suivent une logique de **seuil** (la tranche s'étend jusqu'au
  /// seuil suivant) : un prix « entre deux tranches » (750, 1375…) reçoit la
  /// marge de la tranche inférieure, jamais 0.
  ///
  /// ⚠️ Ne s'applique qu'aux **plats principaux** (via [applyPricingGrid]). Les
  /// boissons, les frites et TOUS les choix d'options (sauces, extras,
  /// suppléments) gardent leur prix brut : ils ne passent jamais par ici.
  static int markupPrice(int raw) {
    if (raw <= 0) return raw;
    return raw + _margin(raw);
  }

  static int _margin(int p) {
    if (p < 300) return 0;
    if (p < 800) return 50;
    if (p < 1400) return 100;
    if (p < 1850) return 150;
    if (p < 2350) return 200;
    if (p < 2850) return 250;
    if (p < 3400) return 300;
    if (p < 3850) return 350;
    if (p < 4400) return 400;
    if (p < 4850) return 500;
    if (p < 8000) return 600;
    if (p < 10000) return 1000;
    if (p < 20000) return 1500;
    if (p < 30000) return 2000;
    return 2500;
  }

  /// Catégories « boisson » exclues de la marge (mais PAS les desserts ni les
  /// glaces, qui sont de la nourriture et suivent la grille).
  static final _drinkCategoryRegex = RegExp(
    r'boisson|jus|cocktail|smoothie|milk\s*shake|frappe|soda|limonade'
    r'|soft|th[ée]|infusion|caf[ée]|\beau\b',
    caseSensitive: false,
  );

  /// Boissons reconnues par leur **nom** (filet de sécurité si la catégorie n'a
  /// pas un nom « boisson » explicite). Couvre les marques courantes à Djibouti.
  static final _drinkNameRegex = RegExp(
    r'\b(coca|cola|pepsi|fanta|sprite|mizone?|mizo|grenadine|oasis|schweppes'
    r'|red\s*bull|redbull|soda|limonade|ice\s*tea|ice-?tea|th[ée]\s*glac|perrier'
    r'|san\s*pellegrino|vittel|evian|ambo|smoothie|milk\s*shake|frapp[ée])\b',
    caseSensitive: false,
  );

  /// Frites vendues seules (accompagnement) : exclues de la marge. On exige que
  /// le nom COMMENCE par « frite(s) » pour ne pas capturer un plat composé
  /// (« Poulet frites » garde la marge). Reste corrigeable dans l'aperçu.
  static final _friesRegex =
      RegExp(r'^\s*frites?\b', caseSensitive: false);

  static bool isDrinkCategory(String name) =>
      _drinkCategoryRegex.hasMatch(name);
  static bool isDrinkName(String name) => _drinkNameRegex.hasMatch(name);
  static bool isFries(String name) => _friesRegex.hasMatch(name);

  /// Applique la grille tarifaire à un [ParsedMenu] tout juste parsé (prix
  /// bruts). Majoré : prix de base, formule menu et prix par taille des **plats
  /// principaux**. Conservé au prix brut : les catégories boisson, les frites,
  /// et tous les choix d'options (jamais touchés ici).
  static void applyPricingGrid(ParsedMenu menu) {
    for (final cat in menu.categories) {
      final drink = isDrinkCategory(cat.name);
      for (final item in cat.items) {
        // Prix brut conservé : catégorie boisson, OU nom de boisson (filet de
        // sécurité), OU frites vendues seules.
        if (drink || isDrinkName(item.name) || isFries(item.name)) continue;
        item.basePrice = markupPrice(item.basePrice);
        final mp = item.menuPrice;
        if (mp != null) item.menuPrice = markupPrice(mp);
        for (var i = 0; i < item.sizes.length; i++) {
          final e = item.sizes[i];
          item.sizes[i] = MapEntry(e.key, markupPrice(e.value));
        }
      }
    }
  }

  /// Prix brut (aucune marge) : la grille est désormais appliquée en une passe
  /// unique par [applyPricingGrid], après le parsing.
  static int _toInt(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    return int.tryParse(digits) ?? 0;
  }
}
