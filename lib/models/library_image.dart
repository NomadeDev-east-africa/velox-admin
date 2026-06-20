import 'package:cloud_firestore/cloud_firestore.dart';

/// Image prédéfinie de la bibliothèque globale : `menuImageLibrary/{id}`.
///
/// Uploadée une fois par l'admin (ex. burger, pizza, panini, tacos…) puis
/// réutilisée par toutes les catégories de tous les restaurants.
class LibraryImage {
  final String id;
  final String label;
  final String imageUrl;
  final String? storagePath; // pour suppression du fichier Storage
  final DateTime? createdAt;

  const LibraryImage({
    required this.id,
    required this.label,
    required this.imageUrl,
    this.storagePath,
    this.createdAt,
  });

  factory LibraryImage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LibraryImage(
      id: doc.id,
      label: data['label'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      storagePath: data['storagePath'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
    };
  }
}
