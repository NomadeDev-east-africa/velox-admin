import 'package:cloud_firestore/cloud_firestore.dart';

/// Ligne d'une commande privée : un plat, sa quantité, son prix unitaire.
class PrivateOrderLine {
  final String name;
  final int quantity;
  final num unitPrice;

  const PrivateOrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  num get lineTotal => quantity * unitPrice;

  factory PrivateOrderLine.fromMap(Map<String, dynamic> m) => PrivateOrderLine(
        name: (m['name'] ?? '').toString(),
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: (m['unitPrice'] as num?) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };
}

/// Statuts d'une commande privée.
class PrivateOrderStatus {
  static const pending = 'pending';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  static const all = [pending, delivered, cancelled];

  static String label(String s) {
    switch (s) {
      case delivered:
        return 'Livrée';
      case cancelled:
        return 'Annulée';
      default:
        return 'En cours';
    }
  }
}

/// Moyens de paiement (mêmes valeurs que les commandes de l'app).
class PrivatePayment {
  static const all = ['cash', 'dmoney', 'waafi'];

  static String label(String p) {
    switch (p) {
      case 'dmoney':
        return 'D-Money';
      case 'waafi':
        return 'Waafi';
      default:
        return 'Espèces';
    }
  }
}

/// Commande **privée** : passée hors de l'app (WhatsApp, téléphone…) et
/// saisie à la main par un admin. Collection `privateOrders`, séparée de
/// `orders` pour ne déclencher aucune Cloud Function, notification ou
/// statistique de l'app.
class PrivateOrder {
  final String id;
  final DateTime orderDate;
  final String source; // whatsapp | phone | other
  final String clientName;
  final String clientPhone;
  final String deliveryAddress;
  final String restaurantId;
  final String restaurantName;
  final List<PrivateOrderLine> items;
  final num deliveryFee;
  final String livreurId;
  final String livreurName;
  final String paymentMethod;
  final String status;
  final String notes;
  final String createdByEmail;

  const PrivateOrder({
    required this.id,
    required this.orderDate,
    this.source = 'whatsapp',
    this.clientName = '',
    this.clientPhone = '',
    this.deliveryAddress = '',
    required this.restaurantId,
    required this.restaurantName,
    this.items = const [],
    this.deliveryFee = 0,
    this.livreurId = '',
    this.livreurName = '',
    this.paymentMethod = 'cash',
    this.status = PrivateOrderStatus.pending,
    this.notes = '',
    this.createdByEmail = '',
  });

  /// Montant des plats (prix menu).
  num get subtotal => items.fold<num>(0, (s, l) => s + l.lineTotal);

  /// Montant payé par le client.
  num get total => subtotal + deliveryFee;

  int get itemCount => items.fold<int>(0, (s, l) => s + l.quantity);

  bool get isCancelled => status == PrivateOrderStatus.cancelled;

  /// Résumé une ligne : « 2× Burger, 1× Frites ».
  String get itemsSummary =>
      items.map((l) => '${l.quantity}× ${l.name}').join(', ');

  static String sourceLabel(String s) {
    switch (s) {
      case 'phone':
        return 'Téléphone';
      case 'other':
        return 'Autre';
      default:
        return 'WhatsApp';
    }
  }

  factory PrivateOrder.fromMap(String id, Map<String, dynamic> m) {
    final raw = m['items'];
    return PrivateOrder(
      id: id,
      orderDate: (m['orderDate'] as Timestamp?)?.toDate() ?? DateTime(2000),
      source: (m['source'] ?? 'whatsapp').toString(),
      clientName: (m['clientName'] ?? '').toString(),
      clientPhone: (m['clientPhone'] ?? '').toString(),
      deliveryAddress: (m['deliveryAddress'] ?? '').toString(),
      restaurantId: (m['restaurantId'] ?? '').toString(),
      restaurantName: (m['restaurantName'] ?? '').toString(),
      items: raw is List
          ? raw
              .whereType<Map>()
              .map(
                  (e) => PrivateOrderLine.fromMap(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      deliveryFee: (m['deliveryFee'] as num?) ?? 0,
      livreurId: (m['livreurId'] ?? '').toString(),
      livreurName: (m['livreurName'] ?? '').toString(),
      paymentMethod: (m['paymentMethod'] ?? 'cash').toString(),
      status: (m['status'] ?? PrivateOrderStatus.pending).toString(),
      notes: (m['notes'] ?? '').toString(),
      createdByEmail: (m['createdByEmail'] ?? '').toString(),
    );
  }

  /// `subtotal` et `total` sont stockés (dénormalisés) pour l'export et
  /// d'éventuelles requêtes, mais l'écran les recalcule toujours depuis
  /// `items` + `deliveryFee`.
  Map<String, dynamic> toMap() => {
        'orderDate': Timestamp.fromDate(orderDate),
        'source': source,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'deliveryAddress': deliveryAddress,
        'restaurantId': restaurantId,
        'restaurantName': restaurantName,
        'items': items.map((l) => l.toMap()).toList(),
        'deliveryFee': deliveryFee,
        'subtotal': subtotal,
        'total': total,
        'livreurId': livreurId,
        'livreurName': livreurName,
        'paymentMethod': paymentMethod,
        'status': status,
        'notes': notes,
        'createdByEmail': createdByEmail,
      };
}
