import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomade_admin_clean/models/private_order.dart';

void main() {
  PrivateOrder sample({String status = PrivateOrderStatus.delivered}) =>
      PrivateOrder(
        id: 'x',
        orderDate: DateTime(2026, 11, 19, 13, 30),
        clientName: 'Client',
        restaurantId: 'r1',
        restaurantName: 'Resto',
        items: const [
          PrivateOrderLine(name: 'Burger', quantity: 2, unitPrice: 1200),
          PrivateOrderLine(name: 'Frites', quantity: 1, unitPrice: 500),
        ],
        deliveryFee: 500,
        status: status,
      );

  test('totaux calculés depuis les lignes', () {
    final o = sample();
    expect(o.subtotal, 2900);
    expect(o.total, 3400);
    expect(o.itemCount, 3);
    expect(o.itemsSummary, '2× Burger, 1× Frites');
  });

  test('aller-retour Firestore conserve tout', () {
    final o = sample();
    final back = PrivateOrder.fromMap('x', o.toMap());
    expect(back.orderDate, o.orderDate);
    expect(back.items.length, 2);
    expect(back.items.first.unitPrice, 1200);
    expect(back.total, 3400);
    expect(back.restaurantName, 'Resto');
    expect(o.toMap()['total'], 3400);
    expect(o.toMap()['orderDate'], isA<Timestamp>());
  });

  test('document incomplet : valeurs par défaut sûres', () {
    final o = PrivateOrder.fromMap('y', {'restaurantName': 'R'});
    expect(o.items, isEmpty);
    expect(o.total, 0);
    expect(o.status, PrivateOrderStatus.pending);
    expect(o.paymentMethod, 'cash');
    expect(o.source, 'whatsapp');
  });

  test('annulée', () {
    expect(sample(status: PrivateOrderStatus.cancelled).isCancelled, isTrue);
    expect(PrivateOrderStatus.label('cancelled'), 'Annulée');
  });
}
