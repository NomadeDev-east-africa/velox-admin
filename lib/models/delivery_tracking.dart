import 'package:cloud_firestore/cloud_firestore.dart';

/// Niveau de retard d'une livraison en cours.
enum DelayLevel { onTime, late, critical }

/// Modèle dérivé d'un document `orders` pour la « Timeline des livreurs retardataires ».
///
/// ⚠️ Les timestamps des commandes sont stockés en **chaînes ISO 8601**
/// (ex. "2026-06-08T16:41:21.964Z") côté app cliente, PAS en `Timestamp`
/// Firestore. [parseTimestamp] tolère les deux formats.
///
/// Base de calcul du retard (décision produit) :
///   ETA = pickedUpAt + [targetMinutes]
///   retard = now - ETA
class DeliveryTracking {
  final String orderId;
  final String? driverId;
  final String driverName;
  final String customerName;
  final String customerPhone;
  final String restaurantName;
  final String deliveryAddress;
  final String status;
  final DateTime? readyAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final num total;

  /// Délai cible de livraison après prise en charge (minutes).
  /// Au-delà → « en retard ». Voir décision produit (seuil 30 min).
  static const int targetMinutes = 30;

  /// Au-delà de ce délai depuis la prise en charge → « critique ».
  static const int criticalMinutes = 45;

  const DeliveryTracking({
    required this.orderId,
    required this.driverId,
    required this.driverName,
    required this.customerName,
    required this.customerPhone,
    required this.restaurantName,
    required this.deliveryAddress,
    required this.status,
    required this.readyAt,
    required this.pickedUpAt,
    required this.deliveredAt,
    required this.total,
  });

  /// Parse un timestamp tolérant : `Timestamp`, String ISO 8601 ou `DateTime`.
  static DateTime? parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  factory DeliveryTracking.fromMap(String id, Map<String, dynamic> data) {
    return DeliveryTracking(
      orderId: id,
      driverId: data['deliveryDriverId'] as String?,
      driverName: (data['deliveryDriverName'] ?? '—').toString(),
      customerName: (data['customerName'] ?? '—').toString(),
      customerPhone: (data['customerPhone'] ?? '').toString(),
      restaurantName: (data['restaurantName'] ?? '—').toString(),
      deliveryAddress: (data['deliveryAddress'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      readyAt: parseTimestamp(data['readyAt']),
      pickedUpAt: parseTimestamp(data['pickedUpAt']),
      deliveredAt: parseTimestamp(data['deliveredAt']),
      total: (data['total'] is num) ? data['total'] as num : 0,
    );
  }

  /// Une livraison « active à suivre » : prise en charge, ni livrée ni annulée.
  /// Indépendant de la chaîne exacte de `status` (qui varie selon l'app livreur).
  static bool isActiveDelivery(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    if (status == 'completed' || status == 'cancelled') return false;
    if (parseTimestamp(data['deliveredAt']) != null) return false;
    return parseTimestamp(data['pickedUpAt']) != null;
  }

  /// ETA estimée de livraison = prise en charge + délai cible.
  DateTime? get eta =>
      pickedUpAt?.add(const Duration(minutes: targetMinutes));

  /// Temps écoulé depuis la prise en charge.
  Duration get elapsedSincePickup => pickedUpAt == null
      ? Duration.zero
      : DateTime.now().difference(pickedUpAt!);

  /// Minutes de retard par rapport à l'ETA (négatif = en avance sur la cible).
  int get delayMinutes => elapsedSincePickup.inMinutes - targetMinutes;

  /// Niveau de retard pour le code couleur.
  DelayLevel get level {
    final elapsed = elapsedSincePickup.inMinutes;
    if (elapsed >= criticalMinutes) return DelayLevel.critical;
    if (elapsed >= targetMinutes) return DelayLevel.late;
    return DelayLevel.onTime;
  }

  /// Libellé court du retard (ex. "+12 min" / "à l'heure").
  String get delayLabel {
    final d = delayMinutes;
    if (d <= 0) return "à l'heure";
    return '+$d min';
  }
}
