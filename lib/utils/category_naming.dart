/// Normalisation des noms de catégories de menu.
///
/// Les plats (`menuItems`) référencent leur catégorie **par son nom**, saisi
/// librement dans le fichier de menu de chaque restaurant. « Milkshake »,
/// « Milk Shake », « Milks Shakes » et « Nos Milk Shake » désignent donc la même
/// chose sans qu'aucun identifiant ne les relie. [categoryKey] produit une clé
/// commune à toutes ces variantes, pour les regrouper au lieu d'en créer une
/// nouvelle à chaque import.
library;

const Map<String, String> _accents = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

/// Articles et conjonctions ignorés : « Nos Boissons » == « Boissons ».
const Set<String> _stopWords = {
  'nos', 'no', 'les', 'le', 'la', 'des', 'de', 'du', 'et',
  'and', 'aux', 'au', 'a', 'our', 'the',
};

/// Synonymes tranchés manuellement, que la normalisation ne peut pas deviner.
///
/// [categoryKey] rapproche les variantes d'un même mot (pluriel, accents,
/// articles, ordre des mots) mais « hamburger » et « burger » restent deux mots
/// distincts. Ces rapprochements-là sont des décisions **métier** : sans cette
/// table, un menu important « Hamburgers » recréerait une catégorie séparée de
/// « Burgers », et la fusion serait à refaire.
///
/// Clé = clé normalisée de la variante, valeur = clé normalisée de la catégorie
/// cible. N'y ajouter que des synonymes réellement validés.
const Map<String, String> _keyAliases = {
  'hamburger': 'burger', // « Hamburgers » → « Burgers »
  'bowlstreat': 'bowl', // « Str'eat Bowls » → « Bowls »
};

/// Clé de regroupement d'un nom de catégorie.
///
/// Insensible à la casse, aux accents, aux apostrophes, à la ponctuation, aux
/// articles en tête, au pluriel et à l'ordre des mots. Deux noms partageant
/// cette clé désignent la même catégorie.
///
/// ```
/// categoryKey('Nos Milk Shake') == categoryKey('Milkshakes')   // true
/// categoryKey("Str'eats Bowls") == categoryKey("Str'eat Bowl") // true
/// categoryKey('Salades')        == categoryKey('Salades Combo')// false
/// ```
String categoryKey(String name) {
  final lowered = name.trim().toLowerCase();
  final unaccented = StringBuffer();
  for (final ch in lowered.split('')) {
    unaccented.write(_accents[ch] ?? ch);
  }

  final cleaned = unaccented
      .toString()
      .replaceAll(RegExp(r"['’`]"), '') // Str'eat -> streat
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
  if (cleaned.isEmpty) return '';

  final tokens = cleaned
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty && !_stopWords.contains(t))
      // Pluriel naïf : le « s » final ne distingue pas deux catégories.
      .map((t) => t.length > 3 && t.endsWith('s') ? t.substring(0, t.length - 1) : t)
      .toList()
    ..sort(); // l'ordre des mots ne distingue pas deux catégories

  // Un nom composé uniquement de mots vides ne doit pas produire une clé vide,
  // sinon toutes ces catégories fusionneraient entre elles.
  if (tokens.isEmpty) return cleaned.replaceAll(' ', '');

  final key = tokens.join();
  return _keyAliases[key] ?? key;
}

/// Renvoie le nom que le [catalogue] utilise déjà pour cette catégorie, ou
/// [name] nettoyé si le catalogue ne la connaît pas.
///
/// Sert à aligner un menu importé sur le catalogue existant : un fichier qui
/// écrit « Milks Shakes » là où le catalogue dit « Milkshakes » doit produire
/// des plats rangés dans « Milkshakes ». Sans cela, les plats porteraient un nom
/// qu'aucune catégorie ne porte — donc pas d'image (fallback gris) et une
/// rubrique fantôme dans l'admin.
String canonicalCategoryName(String name, Iterable<String> catalogue) {
  final key = categoryKey(name);
  if (key.isEmpty) return name.trim();
  for (final known in catalogue) {
    if (categoryKey(known) == key) return known.trim();
  }
  return name.trim();
}

/// `true` si l'image est une **photo propre au plat**, uploadée via
/// `uploadMenuItemImage` sous `menuItems/{restaurantId}/…`.
///
/// À distinguer d'une image simplement **héritée** de la catégorie
/// (`menu_categories/…`), qui peut être remplacée sans rien perdre.
bool isOwnDishPhoto(String? imageUrl) =>
    imageUrl != null && imageUrl.contains('/menuItems%2F');
