import 'package:flutter_test/flutter_test.dart';
import 'package:nomade_admin_clean/models/option_group.dart';
import 'package:nomade_admin_clean/utils/option_choice_ids.dart';

void main() {
  group('OptionChoice — identifiant et rupture', () {
    test('newId respecte le format ch_ + 8 [a-z0-9]', () {
      for (var i = 0; i < 200; i++) {
        expect(OptionChoice.newId(), matches(OptionChoice.idPattern));
      }
    });

    test('aller-retour toMap/fromMap conserve id et available: false', () {
      const choice = OptionChoice(
          id: 'ch_k3f9x2ab', name: 'Cheddar', price: 100, available: false);
      final map = choice.toMap();
      expect(map, {
        'id': 'ch_k3f9x2ab',
        'name': 'Cheddar',
        'price': 100,
        'available': false,
      });
      final back = OptionChoice.fromMap(map);
      expect(back.id, 'ch_k3f9x2ab');
      expect(back.available, isFalse);
    });

    test("available n'est écrit que s'il vaut false", () {
      const choice = OptionChoice(id: 'ch_aaaaaaaa', name: 'Œuf', price: 100);
      expect(choice.toMap().containsKey('available'), isFalse);
      expect(OptionChoice.fromMap({'name': 'Œuf'}).available, isTrue);
    });

    test('id vide ou absent est lu comme null et non écrit', () {
      expect(OptionChoice.fromMap({'name': 'X', 'id': ''}).id, isNull);
      expect(OptionChoice.fromMap({'name': 'X'}).toMap().containsKey('id'),
          isFalse);
    });

    test('copyWith conserve id et available', () {
      const choice = OptionChoice(
          id: 'ch_k3f9x2ab', name: 'Cheddar', price: 100, available: false);
      final copy = choice.copyWith(name: 'Gouda', price: 150);
      expect(copy.id, 'ch_k3f9x2ab');
      expect(copy.available, isFalse);
      expect(copy.name, 'Gouda');
    });

    test('withNewChoiceIds donne un nouvel id à chaque choix copié', () {
      const group = OptionGroup(name: 'Suppléments', choices: [
        OptionChoice(id: 'ch_aaaaaaaa', name: 'Cheddar', available: false),
        OptionChoice(name: 'Œuf'),
      ]);
      final copy = group.withNewChoiceIds();
      expect(copy.choices.map((c) => c.id),
          everyElement(matches(OptionChoice.idPattern)));
      expect(copy.choices.first.id, isNot('ch_aaaaaaaa'));
      expect(copy.choices.first.available, isFalse);
    });
  });

  group('fillMissingChoiceIds — migration', () {
    List<Map<String, dynamic>> raw() => [
          {
            'name': 'Suppléments',
            'type': 'multiple',
            'required': false,
            'choices': [
              {'name': 'Cheddar', 'price': 100, 'available': false},
              {'id': 'ch_existing', 'name': 'Œuf', 'price': 100},
              {'name': 'Bacon', 'price': 200, 'loyverseModifierOptionId': 'x'},
            ],
          },
        ];

    test('donne un id aux seuls choix qui n\'en ont pas, sans perdre de champ',
        () {
      final fill = fillMissingChoiceIds(raw());
      expect(fill.added, 2);
      final choices = (fill.groups.single as Map)['choices'] as List;
      expect(choices[0]['id'], matches(OptionChoice.idPattern));
      expect(choices[0]['available'], isFalse);
      expect(choices[1]['id'], 'ch_existing');
      expect(choices[2]['loyverseModifierOptionId'], 'x');
      expect((fill.groups.single as Map)['type'], 'multiple');
    });

    test('est idempotente : relancée, elle ne change rien', () {
      final first = fillMissingChoiceIds(raw());
      final second = fillMissingChoiceIds(first.groups);
      expect(second.added, 0);
      expect(second.groups, first.groups);
    });

    test('plat sans options : rien à faire', () {
      expect(fillMissingChoiceIds(null).added, 0);
      expect(fillMissingChoiceIds(const []).added, 0);
    });
  });
}
