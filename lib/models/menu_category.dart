import 'package:cloud_firestore/cloud_firestore.dart';
import 'option_group.dart';

/// Catégorie d'un restaurant : `restaurants/{restaurantId}/categories/{id}`.
///
/// Compatibilité app resto (Kotlin) : elle ne lit que `name` / `isDefault`,
/// donc les champs ajoutés ici (`imageUrl`, `defaultOptionGroups`, `order`)
/// sont ignorés sans risque côté app restaurant.
///
/// - [imageUrl] : image (de la bibliothèque) appliquée automatiquement aux plats
///   de cette catégorie.
/// - [defaultOptionGroups] : modèle de suppléments/options hérité par les plats
///   de la catégorie à leur création.
class MenuCategory {
  final String id;
  final String restaurantId;
  final String name;
  final String? imageUrl;
  final bool isDefault;
  final int order;
  final List<OptionGroup> defaultOptionGroups;
  final DateTime? createdAt;

  const MenuCategory({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.imageUrl,
    this.isDefault = false,
    this.order = 0,
    this.defaultOptionGroups = const [],
    this.createdAt,
  });

  factory MenuCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuCategory(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'],
      isDefault: data['isDefault'] ?? false,
      order: (data['order'] as num?)?.toInt() ?? 0,
      defaultOptionGroups:
          OptionGroup.listFromRaw(data['defaultOptionGroups']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      'imageUrl': imageUrl,
      'isDefault': isDefault,
      'order': order,
      'defaultOptionGroups': OptionGroup.listToRaw(defaultOptionGroups),
    };
  }

  MenuCategory copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? imageUrl,
    bool? isDefault,
    int? order,
    List<OptionGroup>? defaultOptionGroups,
    DateTime? createdAt,
  }) {
    return MenuCategory(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      isDefault: isDefault ?? this.isDefault,
      order: order ?? this.order,
      defaultOptionGroups: defaultOptionGroups ?? this.defaultOptionGroups,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
