import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/promo_code.dart';

class PromoCodeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _promoCodesCollection =>
      _firestore.collection('promoCodes');

  /// Normalise un code saisi par l'admin : majuscules, sans espaces.
  static String normalizeCode(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  Stream<List<PromoCode>> getPromoCodes() {
    return _promoCodesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PromoCode.fromFirestore(doc)).toList());
  }

  /// Crée un code promo. Le doc ID = le code (garantit l'unicité) — échoue
  /// si le code existe déjà.
  Future<void> createPromoCode(PromoCode promo) async {
    final docRef = _promoCodesCollection.doc(promo.code);
    final existing = await docRef.get();
    if (existing.exists) {
      throw Exception('Ce code promo existe déjà');
    }
    await docRef.set({
      ...promo.toMap(),
      'usageCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': FirebaseAuth.instance.currentUser?.uid,
    });
  }

  Future<void> updatePromoCode(String code, Map<String, dynamic> data) async {
    await _promoCodesCollection.doc(code).update(data);
  }

  Future<void> toggleActive(String code, bool active) async {
    await updatePromoCode(code, {'active': active});
  }

  Future<void> deletePromoCode(String code) async {
    await _promoCodesCollection.doc(code).delete();
  }
}
