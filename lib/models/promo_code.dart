import 'package:cloud_firestore/cloud_firestore.dart';

enum PromoDiscountType { percentage, fixed }

PromoDiscountType promoDiscountTypeFromString(String? value) {
  return value == 'fixed' ? PromoDiscountType.fixed : PromoDiscountType.percentage;
}

String promoDiscountTypeToString(PromoDiscountType type) {
  return type == PromoDiscountType.fixed ? 'fixed' : 'percentage';
}

/// Code promo appliqué par le client au checkout, sur (sous-total nourriture
/// + frais de livraison). Le doc ID Firestore = le code lui-même (uppercase)
/// afin de garantir l'unicité et permettre une lecture directe côté
/// Cloud Function (`promoCodes/{CODE}`), sans requête.
class PromoCode {
  final String code;
  final PromoDiscountType discountType;
  final num discountValue; // % (0-100) si percentage, FDJ si fixed
  final String? restaurantId; // null = valable sur tous les restaurants
  final String? restaurantName; // dénormalisé, affichage uniquement
  final DateTime? expiresAt; // null = pas d'expiration
  final bool active;
  final int usageCount; // incrémenté uniquement côté serveur (Cloud Function)
  final num totalDiscountGiven; // FDJ cumulés, incrémenté côté serveur
  final DateTime? createdAt;
  final String? createdBy;

  const PromoCode({
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.restaurantId,
    this.restaurantName,
    this.expiresAt,
    this.active = true,
    this.usageCount = 0,
    this.totalDiscountGiven = 0,
    this.createdAt,
    this.createdBy,
  });

  bool get isGlobal => restaurantId == null;

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory PromoCode.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PromoCode(
      code: (data['code'] ?? doc.id).toString(),
      discountType: promoDiscountTypeFromString(data['discountType'] as String?),
      discountValue: (data['discountValue'] as num?) ?? 0,
      restaurantId: data['restaurantId'] as String?,
      restaurantName: data['restaurantName'] as String?,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      active: data['active'] as bool? ?? true,
      usageCount: (data['usageCount'] as num?)?.toInt() ?? 0,
      totalDiscountGiven: (data['totalDiscountGiven'] as num?) ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'discountType': promoDiscountTypeToString(discountType),
      'discountValue': discountValue,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'active': active,
    };
  }

  String get discountLabel {
    return discountType == PromoDiscountType.percentage
        ? '-${discountValue.toStringAsFixed(0)}%'
        : '-${discountValue.toStringAsFixed(0)} FDJ';
  }
}
