import 'package:flutter_test/flutter_test.dart';
import 'package:nomade_admin_clean/utils/category_naming.dart';

void main() {
  group('categoryKey — regroupe les variantes', () {
    void same(String a, String b) => expect(
          categoryKey(a),
          categoryKey(b),
          reason: '« $a » et « $b » devraient partager la même clé',
        );

    test('pluriel', () {
      same('Burger', 'Burgers');
      same('Shawarma', 'Shawarmas');
      same('Panini', 'Paninis');
    });

    test('article en tête', () {
      same('Boissons', 'Nos Boissons');
      same('Desserts', 'Les Desserts');
      same('Pâtes', 'Nos Pâtes');
    });

    test('accents et casse', () {
      same('Pâtes', 'pates');
      same('tacos', 'Tacos');
      same('Entrées froides et chaudes', 'Entrées Froides Et Chaudes');
    });

    test('apostrophes', () {
      same("Str'eat Bowl", "Str'eats Bowls");
    });

    test('espacement et ponctuation', () {
      same('Tandoori  Non Veg', 'Tandoori Non Veg');
      same('Wrap / Crousty', 'Wraps / Crousty');
      same('Brochettes Et Steak', 'Brochettes et Steaks');
    });

    test('ordre des mots', () {
      same('Burger Viande / Chicken', 'Burgers Viandes / Chickens');
      same('Fish Burger', 'Fishs Burgers');
    });

    test('la famille Milkshake au complet', () {
      for (final v in ['Milkshakes', 'Milk Shake', 'Milks Shakes', 'Nos Milk Shake']) {
        same('Milkshake', v);
      }
    });

    test('synonymes validés à la fusion (table d\'alias)', () {
      // Décisions métier : la normalisation seule ne peut pas les déduire.
      same('Hamburgers', 'Burgers');
      same("Str'eat Bowls", 'Bowls');
    });
  });

  group('categoryKey — ne confond pas des catégories distinctes', () {
    void differ(String a, String b) => expect(
          categoryKey(a),
          isNot(categoryKey(b)),
          reason: '« $a » et « $b » ne devraient PAS fusionner',
        );

    test('un qualificatif change la catégorie', () {
      differ('Salades', 'Salades Combo');
      differ('Glaces', 'Glaces Rouleaux');
      differ('Shawarma', 'Shawarma Trays');
      differ('Wraps', 'Wraps / Crousty');
      differ('Burgers', 'Burgers Viandes / Chickens');
    });

    test('catégories sans rapport', () {
      differ('Boissons', 'Boissons chaudes');
      differ('Milkshakes', 'Freakshakes');
      differ('Menu Enfants', 'Kids Menu');
      differ('Pizza', 'Pâtes');
    });
  });

  group('cas limites', () {
    test('un nom fait de mots vides ne produit pas une clé vide', () {
      expect(categoryKey('Les'), isNotEmpty);
      expect(categoryKey('Les'), isNot(categoryKey('Nos')));
    });

    test('nom vide ou espaces', () {
      expect(categoryKey(''), isEmpty);
      expect(categoryKey('   '), isEmpty);
    });
  });

  group('canonicalCategoryName — aligne un menu importé sur le catalogue', () {
    // Le catalogue réel après fusion.
    const catalogue = [
      'Milkshakes', 'Boissons', 'Desserts', 'Burgers', 'Tacos', 'Pâtes', 'Viandes',
    ];

    test('une variante du fichier retombe sur le nom du catalogue', () {
      expect(canonicalCategoryName('Milks Shakes', catalogue), 'Milkshakes');
      expect(canonicalCategoryName('Nos Boissons', catalogue), 'Boissons');
      expect(canonicalCategoryName('Les Desserts', catalogue), 'Desserts');
      expect(canonicalCategoryName('Hamburgers', catalogue), 'Burgers');
      expect(canonicalCategoryName('tacos', catalogue), 'Tacos');
      expect(canonicalCategoryName('nos pates', catalogue), 'Pâtes');
    });

    test('un menu JSON écrivant « Nos Viandes » range ses plats dans « Viandes »', () {
      // Le cas concret : le fichier du restaurant porte l'article, le catalogue
      // non. C'est le catalogue qui fait foi.
      expect(canonicalCategoryName('Nos Viandes', catalogue), 'Viandes');
      expect(canonicalCategoryName('nos viandes', catalogue), 'Viandes');
      expect(canonicalCategoryName('Viande', catalogue), 'Viandes');
    });

    test('un nom déjà canonique est renvoyé tel quel', () {
      expect(canonicalCategoryName('Boissons', catalogue), 'Boissons');
    });

    test('une catégorie inconnue garde son nom (juste nettoyé)', () {
      expect(canonicalCategoryName('  Sushi  ', catalogue), 'Sushi');
      expect(canonicalCategoryName('Poke Bowl', catalogue), 'Poke Bowl');
    });

    test('ne rattache pas une catégorie distincte', () {
      expect(canonicalCategoryName('Boissons chaudes', catalogue), 'Boissons chaudes');
      expect(canonicalCategoryName('Burgers Viandes / Chickens', catalogue),
          'Burgers Viandes / Chickens');
    });

    test('catalogue vide', () {
      expect(canonicalCategoryName('Milks Shakes', const []), 'Milks Shakes');
    });
  });

  group('isOwnDishPhoto', () {
    test('photo propre au plat', () {
      expect(
        isOwnDishPhoto(
            'https://firebasestorage.googleapis.com/v0/b/x/o/menuItems%2FabC%2F123.jpg?alt=media'),
        isTrue,
      );
    });

    test('image héritée de la catégorie', () {
      expect(
        isOwnDishPhoto(
            'https://firebasestorage.googleapis.com/v0/b/x/o/menu_categories%2F178_boissons.jpg?alt=media'),
        isFalse,
      );
    });

    test('absence d\'image', () {
      expect(isOwnDishPhoto(null), isFalse);
      expect(isOwnDishPhoto(''), isFalse);
    });
  });
}
