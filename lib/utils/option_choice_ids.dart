import '../models/option_group.dart';

/// Résultat de [fillMissingChoiceIds] pour un plat.
class ChoiceIdFill {
  /// `optionGroups` à réécrire — identique à l'entrée si [added] vaut 0.
  final List<dynamic> groups;

  /// Nombre de choix qui ont reçu un identifiant.
  final int added;

  const ChoiceIdFill(this.groups, this.added);
}

/// Donne un identifiant à chaque choix de [rawGroups] (le champ brut
/// `menuItems/{id}.optionGroups`) qui n'en a pas.
///
/// Travaille sur les maps Firestore brutes, sans passer par [OptionChoice] :
/// tous les autres champs des groupes et des choix (`available`, champs posés
/// par d'autres apps…) sont recopiés tels quels. Idempotente : un plat dont
/// tous les choix ont déjà un `id` renvoie `added == 0`.
ChoiceIdFill fillMissingChoiceIds(dynamic rawGroups) {
  if (rawGroups is! List) return ChoiceIdFill(const [], 0);
  var added = 0;
  final groups = rawGroups.map((g) {
    if (g is! Map || g['choices'] is! List) return g;
    final choices = (g['choices'] as List).map((c) {
      if (c is! Map) return c;
      final id = c['id'];
      if (id is String && id.isNotEmpty) return c;
      added++;
      return {...c, 'id': OptionChoice.newId()};
    }).toList();
    return {...g, 'choices': choices};
  }).toList();
  return ChoiceIdFill(groups, added);
}
