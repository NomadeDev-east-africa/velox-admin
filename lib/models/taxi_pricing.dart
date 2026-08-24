import 'package:cloud_firestore/cloud_firestore.dart';

class TaxiPricingTier {
  final double basePrice;
  final double includedKm;
  final double pricePerKm;

  const TaxiPricingTier({
    required this.basePrice,
    required this.includedKm,
    required this.pricePerKm,
  });

  factory TaxiPricingTier.fromMap(Map<String, dynamic>? data) => TaxiPricingTier(
        basePrice: (data?['basePrice'] as num?)?.toDouble() ?? 0,
        includedKm: (data?['includedKm'] as num?)?.toDouble() ?? 0,
        pricePerKm: (data?['pricePerKm'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'basePrice': basePrice,
        'includedKm': includedKm,
        'pricePerKm': pricePerKm,
      };

  TaxiPricingTier copyWith({double? basePrice, double? includedKm, double? pricePerKm}) =>
      TaxiPricingTier(
        basePrice: basePrice ?? this.basePrice,
        includedKm: includedKm ?? this.includedKm,
        pricePerKm: pricePerKm ?? this.pricePerKm,
      );

  /// `prix = basePrice + pricePerKm × max(0, distanceKm − includedKm)` — même
  /// formule que côté serveur (`onTaxiRideCreated` / `onRideUpdated`).
  double priceForDistance(double distanceKm) {
    final extraKm = distanceKm - includedKm;
    return basePrice + pricePerKm * (extraKm > 0 ? extraKm : 0);
  }
}

/// Valeurs par défaut si le document Firestore n'existe pas encore — DOIVENT rester
/// synchronisées avec `DEFAULT_TAXI_PRICING` dans nomade_client/functions/index.js.
const kDefaultStandardTier = TaxiPricingTier(basePrice: 600, includedKm: 3, pricePerKm: 200);
const kDefaultComfortTier = TaxiPricingTier(basePrice: 750, includedKm: 3, pricePerKm: 200);

class TaxiPricingConfig {
  final TaxiPricingTier standard;
  final TaxiPricingTier comfort;

  const TaxiPricingConfig({required this.standard, required this.comfort});

  factory TaxiPricingConfig.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return TaxiPricingConfig(
      standard: data['standard'] != null
          ? TaxiPricingTier.fromMap(data['standard'] as Map<String, dynamic>)
          : kDefaultStandardTier,
      comfort: data['comfort'] != null
          ? TaxiPricingTier.fromMap(data['comfort'] as Map<String, dynamic>)
          : kDefaultComfortTier,
    );
  }

  static const defaults = TaxiPricingConfig(standard: kDefaultStandardTier, comfort: kDefaultComfortTier);

  TaxiPricingConfig copyWith({TaxiPricingTier? standard, TaxiPricingTier? comfort}) =>
      TaxiPricingConfig(
        standard: standard ?? this.standard,
        comfort: comfort ?? this.comfort,
      );

  Map<String, dynamic> toMap() => {'standard': standard.toMap(), 'comfort': comfort.toMap()};
}
