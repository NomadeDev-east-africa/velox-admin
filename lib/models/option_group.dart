import 'dart:math';

/// Modèle générique d'options pour un plat (menuItem) ou une catégorie.
///
/// Un [OptionGroup] regroupe des [OptionChoice]. Il couvre tous les cas du menu :
/// - Formule  (single)  : [Seul +0, Menu +300]
/// - Taille   (single)  : [M +0, L +600, XL +1200]
/// - Viande   (single)  : [Poulet +0, Kebab +400, Tenders +200]
/// - Suppléments (multiple) : [Emmental +100, Cheddar +100, Œuf +100]
/// - Sauces   (multiple) : [...]
///
/// `price` d'un choix = supplément AJOUTÉ au prix de base du plat.
///
/// Stocké tel quel dans `menuItems.optionGroups` (lu plus tard par l'app client)
/// et dans `categories.defaultOptionGroups` (modèle hérité par les plats).
class OptionGroup {
  final String name;
  final OptionType type; // single | multiple
  final bool required;
  final List<OptionChoice> choices;

  /// Nombre **maximum** de choix sélectionnables (uniquement pertinent pour un
  /// groupe `multiple`). `0` = illimité. Ex. Tacos XL → `maxChoices: 2`.
  /// Un groupe `single` vaut toujours 1 choix, quelle que soit cette valeur.
  final int maxChoices;

  const OptionGroup({
    required this.name,
    this.type = OptionType.multiple,
    this.required = false,
    this.choices = const [],
    this.maxChoices = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name, // 'single' | 'multiple'
      'required': required,
      // Écrit uniquement si une limite existe → additif, ne pollue pas les
      // documents existants ni les groupes sans plafond.
      if (maxChoices > 0) 'maxChoices': maxChoices,
      'choices': choices.map((c) => c.toMap()).toList(),
    };
  }

  factory OptionGroup.fromMap(Map<String, dynamic> map) {
    return OptionGroup(
      name: map['name'] ?? '',
      type: OptionTypeX.fromString(map['type']),
      required: map['required'] ?? false,
      maxChoices: (map['maxChoices'] as num?)?.toInt() ?? 0,
      choices: (map['choices'] as List?)
              ?.map((c) => OptionChoice.fromMap(
                    Map<String, dynamic>.from(c as Map),
                  ))
              .toList() ??
          const [],
    );
  }

  static List<OptionGroup> listFromRaw(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => OptionGroup.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static List<Map<String, dynamic>> listToRaw(List<OptionGroup> groups) {
    return groups.map((g) => g.toMap()).toList();
  }

  /// Copie du groupe dont chaque choix reçoit un **nouvel** identifiant. Un
  /// groupe copié dans un autre plat (modèle de catégorie, plat dupliqué,
  /// suppléments globaux d'un import) passe toujours par ici.
  OptionGroup withNewChoiceIds() =>
      copyWith(choices: choices.map((c) => c.withNewId()).toList());

  OptionGroup copyWith({
    String? name,
    OptionType? type,
    bool? required,
    List<OptionChoice>? choices,
    int? maxChoices,
  }) {
    return OptionGroup(
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
      choices: choices ?? this.choices,
      maxChoices: maxChoices ?? this.maxChoices,
    );
  }
}

class OptionChoice {
  /// Identifiant stable du choix (`ch_` + 8 caractères `[a-z0-9]`), généré une
  /// seule fois à la création et jamais modifié ensuite (renommage, prix…).
  /// Recopié par les apps client dans `orders.items[].extras[].choiceId` :
  /// c'est la clé de correspondance avec la caisse Loyverse.
  /// `null` uniquement pour un plat ancien pas encore migré.
  final String? id;
  final String name;
  final int price; // supplément en FDJ (0 = inclus)

  /// `false` = choix en rupture, posé par l'app restaurant. L'admin ne le
  /// modifie pas mais doit le réécrire tel quel quand il sauvegarde un plat.
  final bool available;

  const OptionChoice({
    this.id,
    required this.name,
    this.price = 0,
    this.available = true,
  });

  static final _random = Random.secure();
  static const _idChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// Nouvel identifiant de choix : `ch_` + 8 caractères `[a-z0-9]`.
  static String newId() =>
      'ch_${List.generate(8, (_) => _idChars[_random.nextInt(_idChars.length)]).join()}';

  /// Format attendu d'un identifiant de choix.
  static final idPattern = RegExp(r'^ch_[a-z0-9]{8}$');

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'price': price,
        if (!available) 'available': false,
      };

  factory OptionChoice.fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String?;
    return OptionChoice(
      id: (id == null || id.isEmpty) ? null : id,
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      available: map['available'] != false,
    );
  }

  OptionChoice copyWith({String? name, int? price, bool? available}) {
    return OptionChoice(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      available: available ?? this.available,
    );
  }

  /// Même choix avec un **nouvel** identifiant : à utiliser quand un choix est
  /// copié vers un autre plat (modèle de catégorie, duplication, import).
  OptionChoice withNewId() => OptionChoice(
        id: newId(),
        name: name,
        price: price,
        available: available,
      );
}

enum OptionType { single, multiple }

extension OptionTypeX on OptionType {
  static OptionType fromString(dynamic value) {
    return value == 'single' ? OptionType.single : OptionType.multiple;
  }

  String get label =>
      this == OptionType.single ? 'Choix unique' : 'Choix multiple';
}
