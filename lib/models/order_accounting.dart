import '../constants.dart';
import '../services/menu_parser.dart';
import 'order_tracking.dart';

/// Lecture « comptable » d'une commande, pour l'écran Comptabilité.
///
/// Circuit de l'argent (confirmé par l'exploitation, 02/11/2026) :
/// - le client paie TOUJOURS le livreur (espèces, D-Money ou Waafi sur le
///   téléphone du livreur) — jamais NOMADE ;
/// - le livreur paie au restaurant le prix menu complet (`subtotal`) ;
/// - le livreur garde le reste : frais de livraison moins les points
///   fidélité (toujours déduits des frais de livraison) ;
/// - en fin de mois, le gérant passe dans chaque restaurant encaisser la
///   COMMISSION NOMADE contenue dans les prix menu.
/// Livreur et NOMADE n'échangent donc pas d'argent : la seule dette à suivre
/// est la commission due par chaque restaurant.
///
/// La commission est incluse dans les prix menu (grille
/// [MenuParser.markupPrice]) et n'est pas stockée sur la commande : elle est
/// ESTIMÉE en inversant la grille sur chaque prix du panier.
class OrderAccounting {
  final String id;
  final DateTime? createdAt;
  final String restaurantId;
  final String restaurantName;
  final String livreurId;
  final String livreurName;
  final String customerName;
  final String paymentMethod;
  final OrderPhase phase;
  final List<OrderLineItem> items;

  /// Panier au prix menu (commission incluse, promo restaurant déduite) —
  /// payé par le livreur au restaurant.
  final num subtotal;
  final num deliveryFee;

  /// Points fidélité (déduits des frais de livraison du livreur).
  final num loyaltyDiscount;

  /// Code promo plateforme.
  final num promoDiscount;

  /// Payé par le client au livreur.
  final num total;

  /// Commission NOMADE estimée contenue dans [subtotal], due par le
  /// restaurant.
  final num commission;

  const OrderAccounting({
    required this.id,
    required this.createdAt,
    required this.restaurantId,
    required this.restaurantName,
    required this.livreurId,
    required this.livreurName,
    required this.customerName,
    required this.paymentMethod,
    required this.phase,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.loyaltyDiscount,
    required this.promoDiscount,
    required this.total,
    required this.commission,
  });

  bool get isDelivered => phase == OrderPhase.delivered;

  String get paymentLabel {
    switch (paymentMethod) {
      case '':
      case 'cash':
        return 'Espèces';
      case 'd-money':
      case 'dmoney':
        return 'D-Money';
      case 'waafi':
        return 'Waafi';
      default:
        return paymentMethod;
    }
  }

  /// Ce qui reste réellement au livreur : payé par le client − payé au
  /// restaurant (= frais de livraison − points fidélité − code promo).
  num get livreurKeeps => total - subtotal;

  /// Ce que le restaurant garde une fois la commission reversée.
  num get restaurantNet => subtotal - commission;

  factory OrderAccounting.fromMap(String id, Map<String, dynamic> data) {
    num n(dynamic v) => v is num ? v : 0;
    final tracking = OrderTracking.fromMap(id, data);
    return OrderAccounting(
      id: id,
      createdAt: Formatters.parseFirestoreDate(data['createdAt']),
      restaurantId: (data['restaurantId'] ?? '').toString(),
      restaurantName: (data['restaurantName'] ?? 'N/A').toString(),
      livreurId: (data['deliveryDriverId'] ?? '').toString(),
      livreurName: (data['deliveryDriverName'] ?? '').toString(),
      customerName: (data['customerName'] ?? '').toString(),
      paymentMethod:
          (data['paymentMethod'] ?? '').toString().trim().toLowerCase(),
      phase: tracking.phase,
      items: tracking.items,
      subtotal: n(data['subtotal']),
      deliveryFee: n(data['deliveryFee']),
      loyaltyDiscount: n(data['discount']),
      promoDiscount: n(data['promoDiscount']),
      total: n(data['total']),
      commission: estimateCommission(data['items']),
    );
  }

  /// Somme des marges de chaque prix du panier (plat + choix sélectionnés),
  /// multipliée par la quantité.
  static int estimateCommission(dynamic items) {
    if (items is! List) return 0;
    int toInt(dynamic v) => v is num ? v.round() : 0;
    var total = 0;
    for (final raw in items) {
      if (raw is! Map) continue;
      final qty = raw['quantity'] is num ? (raw['quantity'] as num).toInt() : 1;
      final base = raw.containsKey('basePrice')
          ? toInt(raw['basePrice'])
          : toInt(raw['unitPrice'] ?? raw['price']);
      var unitMargin = MenuParser.marginIncludedIn(base);
      for (final key in const ['extras', 'sauces']) {
        final choices = raw[key];
        if (choices is! List) continue;
        for (final c in choices) {
          if (c is! Map || c['isSelected'] == false) continue;
          unitMargin += MenuParser.marginIncludedIn(toInt(c['price']));
        }
      }
      total += unitMargin * qty;
    }
    return total;
  }
}
