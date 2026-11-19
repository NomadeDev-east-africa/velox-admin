import 'package:flutter_test/flutter_test.dart';
import 'package:nomade_admin_clean/models/order_accounting.dart';
import 'package:nomade_admin_clean/models/private_order.dart';
import 'package:nomade_admin_clean/services/menu_parser.dart';

void main() {
  group('MenuParser.marginIncludedIn', () {
    test('inverse exactement la grille pour tout prix brut', () {
      for (var raw = 1; raw <= 40000; raw++) {
        final finalPrice = MenuParser.markupPrice(raw);
        expect(MenuParser.marginIncludedIn(finalPrice), finalPrice - raw,
            reason: 'raw=$raw final=$finalPrice');
      }
    });

    test('< 300 : aucune marge', () {
      expect(MenuParser.marginIncludedIn(0), 0);
      expect(MenuParser.marginIncludedIn(299), 0);
    });
  });

  group('OrderAccounting', () {
    Map<String, dynamic> order({
      String paymentMethod = 'cash',
      int discount = 0,
      int promoDiscount = 0,
    }) {
      // Plat brut 1800 → 1950 au menu (+150), sauce 200 (+0), x2.
      const subtotal = (1950 + 200) * 2;
      return {
        'status': 'completed',
        'deliveredAt': DateTime(2026, 11, 2).toIso8601String(),
        'paymentMethod': paymentMethod,
        'subtotal': subtotal,
        'deliveryFee': 500,
        'driverEarnings': 500,
        'discount': discount,
        'promoDiscount': promoDiscount,
        'total': subtotal + 500 - discount - promoDiscount,
        'items': [
          {
            'basePrice': 1950,
            'quantity': 2,
            'sauces': [
              {'name': 'Algérienne', 'price': 200, 'isSelected': true},
              {'name': 'Mayo', 'price': 400, 'isSelected': false},
            ],
            'extras': [],
          }
        ],
      };
    }

    test(
        'commission estimée = marges × quantité (choix non sélectionnés exclus)',
        () {
      final o = OrderAccounting.fromMap('a', order());
      expect(o.commission, 300);
    });

    test('le livreur garde la livraison moins les points fidélité', () {
      final o = OrderAccounting.fromMap('a', order(discount: 100));
      expect(o.isDelivered, isTrue);
      expect(o.total, 4300 + 500 - 100);
      expect(o.livreurKeeps, 400);
      expect(o.restaurantNet, 4300 - 300);
    });

    test('commande non livrée : exclue de la compta', () {
      final data = order()
        ..['status'] = 'cancelled'
        ..remove('deliveredAt');
      expect(OrderAccounting.fromMap('a', data).isDelivered, isFalse);
    });
  });

  group('OrderAccounting.fromPrivateOrder', () {
    PrivateOrder privee(String status) => PrivateOrder(
          id: 'p1',
          orderDate: DateTime(2026, 11, 19, 12),
          clientName: 'Client WhatsApp',
          restaurantId: 'r1',
          restaurantName: 'Resto',
          items: const [
            // 1250 = prix menu (brut 1150 + marge 100) ; 650 = 600 + 50.
            PrivateOrderLine(name: 'Burger', quantity: 2, unitPrice: 1250),
            PrivateOrderLine(name: 'Frites', quantity: 1, unitPrice: 650),
          ],
          deliveryFee: 500,
          status: status,
        );

    test("montants et commission par la même grille que l'app", () {
      final o = OrderAccounting.fromPrivateOrder(
          privee(PrivateOrderStatus.delivered));
      expect(o.isPrivate, isTrue);
      expect(o.isDelivered, isTrue);
      expect(o.subtotal, 3150);
      expect(o.total, 3650);
      expect(
          o.commission,
          2 * MenuParser.marginIncludedIn(1250) +
              MenuParser.marginIncludedIn(650));
      expect(o.livreurKeeps, 500);
      expect(o.items.length, 2);
      expect(o.createdAt, DateTime(2026, 11, 19, 12));
    });

    test('seules les privées « Livrée » comptent', () {
      expect(
          OrderAccounting.fromPrivateOrder(privee(PrivateOrderStatus.pending))
              .isDelivered,
          isFalse);
      expect(
          OrderAccounting.fromPrivateOrder(privee(PrivateOrderStatus.cancelled))
              .isDelivered,
          isFalse);
    });
  });
}
