import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/taxi_pricing.dart';

class TaxiPricingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference get _doc => _firestore.collection('config').doc('taxiPricing');

  Stream<TaxiPricingConfig> watchPricing() {
    return _doc.snapshots().map((snap) =>
        snap.exists ? TaxiPricingConfig.fromFirestore(snap) : TaxiPricingConfig.defaults);
  }

  Future<void> savePricing(TaxiPricingConfig config) async {
    await _doc.set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
