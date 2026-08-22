import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/banner_item.dart';

class BannerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _bannersCollection => _firestore.collection('banners');

  Stream<List<BannerItem>> getBanners() {
    return _bannersCollection.orderBy('order').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => BannerItem.fromFirestore(doc)).toList());
  }

  Future<String> _uploadImage(Uint8List bytes) async {
    final path = 'banners/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  }

  /// Crée une bannière. Place-la en dernière position (max(order) + 1).
  Future<void> createBanner(BannerItem banner, {Uint8List? imageBytes}) async {
    String? storagePath;
    String? imageUrl;
    if (banner.type == BannerType.image && imageBytes != null) {
      storagePath = await _uploadImage(imageBytes);
      imageUrl = await _storage.ref(storagePath).getDownloadURL();
    }

    final existing = await _bannersCollection.orderBy('order', descending: true).limit(1).get();
    final nextOrder = existing.docs.isEmpty
        ? 0
        : ((existing.docs.first.data() as Map<String, dynamic>)['order'] as num? ?? 0).toInt() + 1;

    await _bannersCollection.add({
      ...banner.toMap(),
      'order': nextOrder,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Met à jour une bannière. Si [imageBytes] est fourni, remplace l'image
  /// (l'ancien fichier Storage est supprimé après upload du nouveau).
  Future<void> updateBanner(
    BannerItem banner, {
    Uint8List? imageBytes,
  }) async {
    final data = banner.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();

    if (banner.type == BannerType.image && imageBytes != null) {
      final oldPath = banner.storagePath;
      final newPath = await _uploadImage(imageBytes);
      data['storagePath'] = newPath;
      data['imageUrl'] = await _storage.ref(newPath).getDownloadURL();
      if (oldPath != null) {
        await _storage.ref(oldPath).delete().catchError((_) {});
      }
    }

    await _bannersCollection.doc(banner.id).update(data);
  }

  Future<void> toggleActive(String id, bool active) async {
    await _bannersCollection.doc(id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteBanner(BannerItem banner) async {
    await _bannersCollection.doc(banner.id).delete();
    if (banner.storagePath != null) {
      await _storage.ref(banner.storagePath!).delete().catchError((_) {});
    }
  }

  /// Réécrit le champ `order` de chaque bannière selon son nouvel index
  /// dans [orderedIds] (glisser-déposer côté admin).
  Future<void> reorder(List<String> orderedIds) async {
    final batch = _firestore.batch();
    for (var i = 0; i < orderedIds.length; i++) {
      batch.update(_bannersCollection.doc(orderedIds[i]), {'order': i});
    }
    await batch.commit();
  }
}
