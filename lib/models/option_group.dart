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

  const OptionGroup({
    required this.name,
    this.type = OptionType.multiple,
    this.required = false,
    this.choices = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.name, // 'single' | 'multiple'
      'required': required,
      'choices': choices.map((c) => c.toMap()).toList(),
    };
  }

  factory OptionGroup.fromMap(Map<String, dynamic> map) {
    return OptionGroup(
      name: map['name'] ?? '',
      type: OptionTypeX.fromString(map['type']),
      required: map['required'] ?? false,
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

  OptionGroup copyWith({
    String? name,
    OptionType? type,
    bool? required,
    List<OptionChoice>? choices,
  }) {
    return OptionGroup(
      name: name ?? this.name,
      type: type ?? this.type,
      required: required ?? this.required,
      choices: choices ?? this.choices,
    );
  }
}

class OptionChoice {
  final String name;
  final int price; // supplément en FDJ (0 = inclus)

  const OptionChoice({required this.name, this.price = 0});

  Map<String, dynamic> toMap() => {'name': name, 'price': price};

  factory OptionChoice.fromMap(Map<String, dynamic> map) {
    return OptionChoice(
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
    );
  }

  OptionChoice copyWith({String? name, int? price}) {
    return OptionChoice(name: name ?? this.name, price: price ?? this.price);
  }
}

enum OptionType { single, multiple }

extension OptionTypeX on OptionType {
  static OptionType fromString(dynamic value) {
    return value == 'single' ? OptionType.single : OptionType.multiple;
  }

  String get label =>
      this == OptionType.single ? 'Choix unique' : 'Choix multiple';
}
