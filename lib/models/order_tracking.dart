import 'package:flutter/material.dart';
import '../constants.dart';

/// Étape du cycle de vie d'une commande, dérivée de la présence des
/// timestamps Firestore (`acceptedAt`, `readyAt`, `assignedAt`, `pickedUpAt`,
/// `deliveredAt`/`cancelledAt`) plutôt que du champ `status` — celui-ci ne
/// contient de façon fiable que `completed`/`cancelled` côté admin, le reste
/// du cycle varie selon l'app resto/livreur qui écrit les données.
enum OrderPhase {
  awaitingAcceptance,
  preparing,
  readyForPickup,
  driverToRestaurant,
  delivering,
  delivered,
  cancelled,
}

enum DelayLevel { onTime, late, critical }

/// Un article du panier client, tel qu'écrit dans `orders.items[]` (miroir de
/// `OrderItem` côté app resto/client Kotlin). Lecture tolérante : `sauces` et
/// `extras` peuvent être une liste de chaînes ou une liste d'objets
/// `{name, price, isSelected}` selon la version de l'app cliente qui a créé
/// la commande — seul le nom nous intéresse ici.
class OrderLineItem {
  final String name;
  final int quantity;
  final num unitPrice;
  final num totalPrice;
  final List<String> sauces;
  final List<String> extras;

  const OrderLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.sauces,
    required this.extras,
  });

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    List<String> extractNames(dynamic raw) {
      if (raw is! List) return const [];
      return raw
          .map((e) {
            if (e is String) return e;
            if (e is Map) return (e['name'] ?? '').toString();
            return '';
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }

    num? asNum(dynamic v) => v is num ? v : null;

    final quantity = asNum(map['quantity'])?.toInt() ?? 1;
    final unitPrice = asNum(map['unitPrice']) ??
        asNum(map['basePrice']) ??
        asNum(map['price']) ??
        0;
    final totalPrice = asNum(map['totalPrice']) ?? (unitPrice * quantity);

    return OrderLineItem(
      name: (map['name'] ?? '').toString(),
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      sauces: extractNames(map['sauces']),
      extras: extractNames(map['extras']),
    );
  }
}

/// Libellé FR d'une étape, indépendant d'une commande précise (utilisé pour
/// les filtres de l'écran de suivi).
String orderPhaseLabel(OrderPhase phase) {
  switch (phase) {
    case OrderPhase.awaitingAcceptance:
      return 'En attente';
    case OrderPhase.preparing:
      return 'En préparation';
    case OrderPhase.readyForPickup:
      return 'Prête — attente livreur';
    case OrderPhase.driverToRestaurant:
      return 'Livreur → resto';
    case OrderPhase.delivering:
      return 'En livraison';
    case OrderPhase.delivered:
      return 'Livrée';
    case OrderPhase.cancelled:
      return 'Annulée';
  }
}

class OrderTracking {
  final String id;
  final String customerName;
  final String customerPhone;
  final String restaurantId;
  final String restaurantName;
  final String? driverId;
  final String driverName;
  final String deliveryAddress;
  final num total;
  final String status;
  final List<OrderLineItem> items;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? readyAt;
  final DateTime? assignedAt;
  final DateTime? pickedUpAt;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;

  /// Délai cible de préparation resto (minutes) depuis `acceptedAt`.
  static const int prepTargetMinutes = 25;
  static const int prepCriticalMinutes = 40;

  /// Délai cible pour que le livreur atteigne le restaurant (minutes)
  /// depuis `assignedAt`.
  static const int driverToRestaurantTargetMinutes = 15;
  static const int driverToRestaurantCriticalMinutes = 30;

  /// Délai cible de livraison (minutes) depuis `pickedUpAt`.
  static const int deliveringTargetMinutes = 30;
  static const int deliveringCriticalMinutes = 45;

  const OrderTracking({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.restaurantId,
    required this.restaurantName,
    required this.driverId,
    required this.driverName,
    required this.deliveryAddress,
    required this.total,
    required this.status,
    required this.items,
    required this.createdAt,
    required this.acceptedAt,
    required this.readyAt,
    required this.assignedAt,
    required this.pickedUpAt,
    required this.deliveredAt,
    required this.cancelledAt,
  });

  factory OrderTracking.fromMap(String id, Map<String, dynamic> data) {
    return OrderTracking(
      id: id,
      customerName: (data['customerName'] ?? 'N/A').toString(),
      customerPhone: (data['customerPhone'] ?? '').toString(),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      restaurantName: (data['restaurantName'] ?? 'N/A').toString(),
      driverId: data['deliveryDriverId'] as String?,
      driverName: (data['deliveryDriverName'] ?? '').toString(),
      deliveryAddress: (data['deliveryAddress'] ?? '').toString(),
      total: (data['total'] is num) ? data['total'] as num : 0,
      status: (data['status'] ?? '').toString(),
      items: (data['items'] as List?)
              ?.whereType<Map>()
              .map((e) => OrderLineItem.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      createdAt: Formatters.parseFirestoreDate(data['createdAt']),
      acceptedAt: Formatters.parseFirestoreDate(data['acceptedAt']),
      readyAt: Formatters.parseFirestoreDate(data['readyAt']),
      assignedAt: Formatters.parseFirestoreDate(data['assignedAt']),
      pickedUpAt: Formatters.parseFirestoreDate(data['pickedUpAt']),
      deliveredAt: Formatters.parseFirestoreDate(data['deliveredAt']),
      cancelledAt: Formatters.parseFirestoreDate(data['cancelledAt']),
    );
  }

  OrderPhase get phase {
    if (status == 'cancelled' || cancelledAt != null) {
      return OrderPhase.cancelled;
    }
    if (status == 'completed' || deliveredAt != null) {
      return OrderPhase.delivered;
    }
    if (pickedUpAt != null) return OrderPhase.delivering;
    if (assignedAt != null) return OrderPhase.driverToRestaurant;
    if (readyAt != null) return OrderPhase.readyForPickup;
    if (acceptedAt != null) return OrderPhase.preparing;
    return OrderPhase.awaitingAcceptance;
  }

  /// Horodatage marquant le début de la phase en cours.
  DateTime? get _phaseStart {
    switch (phase) {
      case OrderPhase.preparing:
        return acceptedAt;
      case OrderPhase.driverToRestaurant:
        return assignedAt;
      case OrderPhase.delivering:
        return pickedUpAt;
      default:
        return null;
    }
  }

  /// Temps écoulé depuis le début de la phase en cours (0 si pas de budget).
  Duration get phaseElapsed {
    final start = _phaseStart;
    if (start == null) return Duration.zero;
    return DateTime.now().difference(start);
  }

  int? get _targetMinutes {
    switch (phase) {
      case OrderPhase.preparing:
        return prepTargetMinutes;
      case OrderPhase.driverToRestaurant:
        return driverToRestaurantTargetMinutes;
      case OrderPhase.delivering:
        return deliveringTargetMinutes;
      default:
        return null;
    }
  }

  int? get _criticalMinutes {
    switch (phase) {
      case OrderPhase.preparing:
        return prepCriticalMinutes;
      case OrderPhase.driverToRestaurant:
        return driverToRestaurantCriticalMinutes;
      case OrderPhase.delivering:
        return deliveringCriticalMinutes;
      default:
        return null;
    }
  }

  DelayLevel get delayLevel {
    final target = _targetMinutes;
    final critical = _criticalMinutes;
    if (target == null || critical == null) return DelayLevel.onTime;
    final elapsed = phaseElapsed.inMinutes;
    if (elapsed >= critical) return DelayLevel.critical;
    if (elapsed >= target) return DelayLevel.late;
    return DelayLevel.onTime;
  }

  /// Minutes de dépassement par rapport à la cible (négatif = en avance).
  int get delayMinutes {
    final target = _targetMinutes;
    if (target == null) return 0;
    return phaseElapsed.inMinutes - target;
  }

  String get delayLabel {
    if (_targetMinutes == null) return '';
    final d = delayMinutes;
    if (d <= 0) return "à l'heure";
    return '+$d min';
  }

  String get phaseLabel => orderPhaseLabel(phase);

  bool get isTerminal =>
      phase == OrderPhase.delivered || phase == OrderPhase.cancelled;

  Color get phaseColor {
    switch (phase) {
      case OrderPhase.delivered:
        return successColor;
      case OrderPhase.cancelled:
        return errorColor;
      case OrderPhase.awaitingAcceptance:
        return Colors.orange;
      case OrderPhase.readyForPickup:
        return infoColor;
      case OrderPhase.preparing:
      case OrderPhase.driverToRestaurant:
      case OrderPhase.delivering:
        switch (delayLevel) {
          case DelayLevel.onTime:
            return infoColor;
          case DelayLevel.late:
            return warningColor;
          case DelayLevel.critical:
            return errorColor;
        }
    }
  }
}
