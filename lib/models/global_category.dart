import 'package:cloud_firestore/cloud_firestore.dart';

/// Catégorie de menu **globale** (partagée par tous les restaurants).
///
/// Collection racine `menuCategories`. Une catégorie ne porte qu'un **nom** et
/// une **image** : c'est l'unique chose dont héritent les plats (le prix, les
/// suppléments et les tailles restent propres au menu de chaque restaurant).
///
/// [imageUrl] peut être nul → l'UI affiche un fallback gris en attendant qu'une
/// image soit associée.
class GlobalCategory {
  final String id;
  final String name;
  final String? imageUrl;
  final String? storagePath;
  final int order;
  final DateTime? createdAt;

  const GlobalCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.storagePath,
    this.order = 0,
    this.createdAt,
  });

  factory GlobalCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GlobalCategory(
      id: doc.id,
      name: data['name'] ?? '',
      imageUrl: data['imageUrl'],
      storagePath: data['storagePath'],
      order: (data['order'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'order': order,
    };
  }

  GlobalCategory copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? storagePath,
    int? order,
    DateTime? createdAt,
  }) {
    return GlobalCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      storagePath: storagePath ?? this.storagePath,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
