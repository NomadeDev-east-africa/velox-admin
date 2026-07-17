import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomade_admin_clean/models/option_group.dart';
import 'package:nomade_admin_clean/widgets/option_groups_editor.dart';

/// Monte l'éditeur avec [groups] et renvoie un accès au dernier état émis.
Future<List<OptionGroup> Function()> _pump(
  WidgetTester tester,
  List<OptionGroup> groups,
) async {
  var last = groups;
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: OptionGroupsEditor(
          groups: groups,
          onChanged: (g) => last = g,
        ),
      ),
    ),
  ));
  return () => last;
}

OptionGroup _supplements(List<String> names) => OptionGroup(
      name: 'Suppléments',
      type: OptionType.multiple,
      choices: [
        for (var i = 0; i < names.length; i++)
          OptionChoice(name: names[i], price: (i + 1) * 100),
      ],
    );

void main() {
  group('OptionGroupsEditor — suppression d\'un choix', () {
    testWidgets('supprimer le premier choix retire bien celui-là', (tester) async {
      final read = await _pump(tester, [_supplements(['Emmental', 'Cheddar', 'Œuf'])]);
      await tester.pumpAndSettle();

      // Les trois choix sont affichés.
      expect(find.widgetWithText(TextFormField, 'Emmental'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Cheddar'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Œuf'), findsOneWidget);

      // Croix de la 1re ligne (la 1re est celle du groupe → on prend la suivante).
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // C'est « Emmental » qui doit disparaître — pas un autre.
      expect(find.widgetWithText(TextFormField, 'Emmental'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Cheddar'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Œuf'), findsOneWidget);

      final emitted = read();
      expect(emitted.single.choices.map((c) => c.name), ['Cheddar', 'Œuf']);
    });

    testWidgets('supprimer un choix du milieu', (tester) async {
      final read = await _pump(tester, [_supplements(['Emmental', 'Cheddar', 'Œuf'])]);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).at(1)); // Cheddar
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Emmental'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Cheddar'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Œuf'), findsOneWidget);

      final emitted = read();
      expect(emitted.single.choices.map((c) => c.name), ['Emmental', 'Œuf']);
    });

    testWidgets('les prix suivent le bon choix après suppression', (tester) async {
      final read = await _pump(tester, [_supplements(['Emmental', 'Cheddar', 'Œuf'])]);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).first); // Emmental (100)
      await tester.pumpAndSettle();

      final emitted = read();
      // Cheddar garde 200 et Œuf 300 : les prix ne doivent pas glisser d'un cran.
      expect(emitted.single.choices.map((c) => c.price), [200, 300]);
      expect(find.widgetWithText(TextFormField, '200'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '300'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '100'), findsNothing);
    });

    testWidgets('éditer un champ après suppression vise le bon choix', (tester) async {
      final read = await _pump(tester, [_supplements(['Emmental', 'Cheddar'])]);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close).first); // supprime Emmental
      await tester.pumpAndSettle();

      // Le seul champ restant est Cheddar : le renommer ne doit pas toucher
      // un fantôme d'Emmental.
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Cheddar'), 'Gouda');
      await tester.pumpAndSettle();

      final emitted = read();
      expect(emitted.single.choices.map((c) => c.name), ['Gouda']);
    });
  });

  group('OptionGroupsEditor — suppression d\'un groupe', () {
    testWidgets('supprimer le premier groupe retire bien celui-là', (tester) async {
      final read = await _pump(tester, [
        OptionGroup(name: 'Formule', choices: const [OptionChoice(name: 'Seul')]),
        OptionGroup(name: 'Taille', choices: const [OptionChoice(name: 'M')]),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Formule'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Taille'), findsOneWidget);

      final emitted = read();
      expect(emitted.map((g) => g.name), ['Taille']);
    });
  });
}
