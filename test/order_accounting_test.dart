import 'package:flutter_test/flutter_test.dart';
import 'package:nomade_admin_clean/models/order_accounting.dart';
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
}
