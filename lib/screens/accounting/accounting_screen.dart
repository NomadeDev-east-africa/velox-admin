import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../models/order_accounting.dart';
import '../../widgets/period_filter.dart';

/// Comptabilité : commissions dues par chaque restaurant à NOMADE.
///
/// Le gérant fait le tour des restaurants en fin de mois : pour chacun, une
/// fiche imprimable (détail des commandes + commission) et un bouton
/// « Commission encaissée » qui trace l'encaissement dans
/// `restaurantCommissionPayments`. Livreur et NOMADE n'échangent pas
/// d'argent (voir [OrderAccounting]) : la partie livreurs est informative.
class AccountingScreen extends StatefulWidget {
  const AccountingScreen({super.key});

  @override
  State<AccountingScreen> createState() => _AccountingScreenState();
}

class _RestaurantRow {
  final String id;
  final String name;
  final List<OrderAccounting> orders = [];
  final List<OrderAccounting> unpaid = [];

  _RestaurantRow(this.id, this.name);
}

class _LivreurRow {
  final String name;
  final List<OrderAccounting> orders = [];

  _LivreurRow(this.name);
}

num _sum(Iterable<OrderAccounting> list, num Function(OrderAccounting) f) =>
    list.fold<num>(0, (s, o) => s + f(o));

class _AccountingScreenState extends State<AccountingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Period _period = Period.thisMonth();
  final _money = NumberFormat('#,##0');

  String _fdj(num v) => '${_money.format(v)} FDJ';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('restaurantCommissionPayments').snapshots(),
      builder: (context, paySnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _period
              .apply(_firestore.collection('orders'), 'createdAt')
              .snapshots(),
          builder: (context, ordersSnap) {
            if (ordersSnap.hasError) {
              return Center(child: Text('Erreur: ${ordersSnap.error}'));
            }
            if (!ordersSnap.hasData) {
              return const Center(
                  child: CircularProgressIndicator(color: primaryColor));
            }
            final paidIds = <String>{};
            final payments = paySnap.data?.docs ?? [];
            for (final d in payments) {
              final ids = d.data()['orderIds'];
              if (ids is List) paidIds.addAll(ids.whereType<String>());
            }
            final delivered = ordersSnap.data!.docs
                .map((d) => OrderAccounting.fromMap(d.id, d.data()))
                .where((o) => o.isDelivered)
                .toList();
            return _buildContent(delivered, paidIds, payments, paySnap.error);
          },
        );
      },
    );
  }

  Widget _buildContent(
    List<OrderAccounting> orders,
    Set<String> paidIds,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> payments,
    Object? paymentsError,
  ) {
    final restaurants = <String, _RestaurantRow>{};
    final livreurs = <String, _LivreurRow>{};
    for (final o in orders) {
      final r = restaurants.putIfAbsent(o.restaurantId,
          () => _RestaurantRow(o.restaurantId, o.restaurantName));
      r.orders.add(o);
      if (!paidIds.contains(o.id)) r.unpaid.add(o);
      livreurs
          .putIfAbsent(
              o.livreurId,
              () => _LivreurRow(
                  o.livreurName.isEmpty ? 'Livreur inconnu' : o.livreurName))
          .orders
          .add(o);
    }
    final restaurantRows = restaurants.values.toList()
      ..sort((a, b) => _sum(b.unpaid, (o) => o.commission)
          .compareTo(_sum(a.unpaid, (o) => o.commission)));
    final livreurRows = livreurs.values.toList()
      ..sort((a, b) => b.orders.length.compareTo(a.orders.length));

    final commissionTotal = _sum(orders, (o) => o.commission);
    final commissionUnpaid =
        _sum(restaurantRows.expand((r) => r.unpaid), (o) => o.commission);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Comptabilité — commissions restaurants',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textDarkColor),
                ),
              ),
              ElevatedButton.icon(
                onPressed: orders.isEmpty ? null : () => _exportCsv(orders),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Exporter (Excel)'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          PeriodFilterBar(
            period: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: defaultPadding),
          _infoBanner(),
          if (paymentsError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Encaissements illisibles ($paymentsError) — les règles '
                'Firestore `restaurantCommissionPayments` sont-elles publiées ?',
                style: const TextStyle(color: errorColor),
              ),
            ),
          const SizedBox(height: largePadding),
          Wrap(
            spacing: defaultPadding,
            runSpacing: defaultPadding,
            children: [
              _statCard(Icons.check_circle, 'Commandes livrées',
                  '${orders.length}', successColor),
              _statCard(Icons.storefront, 'Ventes restaurants (prix menu)',
                  _fdj(_sum(orders, (o) => o.subtotal)), infoColor),
              _statCard(Icons.trending_up, 'Commissions NOMADE (est.)',
                  _fdj(commissionTotal), primaryColor),
              _statCard(Icons.savings, 'Déjà encaissé',
                  _fdj(commissionTotal - commissionUnpaid), successColor),
              _statCard(Icons.pending_actions, 'Reste à encaisser',
                  _fdj(commissionUnpaid), warningColor),
            ],
          ),
          const SizedBox(height: largePadding),
          _sectionTitle('Commissions dues par restaurant'),
          _restaurantsTable(restaurantRows, payments),
          const SizedBox(height: largePadding),
          _sectionTitle('Derniers encaissements'),
          _paymentsList(payments),
          const SizedBox(height: largePadding),
          _sectionTitle('Livreurs (pour information)'),
          _livreursTable(livreurRows),
        ],
      ),
    );
  }

  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: infoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(defaultRadius),
        border: Border.all(color: infoColor.withValues(alpha: 0.3)),
      ),
      child: const Text(
        'Seules les commandes LIVRÉES comptent. Le client paie le livreur, le '
        'livreur paie le prix menu complet au restaurant et garde la livraison '
        '(moins les points fidélité). En fin de mois, chaque restaurant doit à '
        'NOMADE la commission incluse dans ses prix.\n'
        "La commission est estimée à partir de la grille de prix (elle n'est "
        'pas enregistrée sur les commandes).',
        style: TextStyle(fontSize: 12, color: textDarkColor),
      ),
    );
  }

  DateTime? _lastPaymentDate(String restaurantId,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> payments) {
    DateTime? last;
    for (final d in payments) {
      if (d.data()['restaurantId'] != restaurantId) continue;
      final t = Formatters.parseFirestoreDate(d.data()['createdAt']);
      if (t != null && (last == null || t.isAfter(last))) last = t;
    }
    return last;
  }

  Widget _restaurantsTable(List<_RestaurantRow> rows,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> payments) {
    if (rows.isEmpty) return _empty();
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Restaurant')),
            DataColumn(label: Text('Commandes'), numeric: true),
            DataColumn(label: Text('Ventes'), numeric: true),
            DataColumn(label: Text('Commission due'), numeric: true),
            DataColumn(label: Text('Reste à encaisser'), numeric: true),
            DataColumn(label: Text('Dernier encaissement')),
            DataColumn(label: Text('')),
          ],
          rows: rows.map((r) {
            final remaining = _sum(r.unpaid, (o) => o.commission);
            final last = _lastPaymentDate(r.id, payments);
            return DataRow(cells: [
              DataCell(Text(r.name,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('${r.orders.length}')),
              DataCell(Text(_fdj(_sum(r.orders, (o) => o.subtotal)))),
              DataCell(Text(_fdj(_sum(r.orders, (o) => o.commission)))),
              DataCell(r.unpaid.isEmpty
                  ? const Text('Encaissé ✓',
                      style: TextStyle(
                          color: successColor, fontWeight: FontWeight.w600))
                  : Text(_fdj(remaining),
                      style: const TextStyle(
                          color: warningColor, fontWeight: FontWeight.w600))),
              DataCell(Text(last != null
                  ? DateFormat('dd/MM/yyyy').format(last)
                  : 'Jamais')),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    onPressed: () => _printSheet(r),
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text('Fiche'),
                  ),
                  if (r.unpaid.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _confirmPaid(r, remaining),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Encaissée'),
                    ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _livreursTable(List<_LivreurRow> rows) {
    if (rows.isEmpty) return _empty();
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Livreur')),
            DataColumn(label: Text('Livraisons'), numeric: true),
            DataColumn(label: Text('Reçu des clients'), numeric: true),
            DataColumn(label: Text('Payé aux restaurants'), numeric: true),
            DataColumn(label: Text('Points fidélité déduits'), numeric: true),
            DataColumn(label: Text('Gain livreur'), numeric: true),
          ],
          rows: rows.map((r) {
            return DataRow(cells: [
              DataCell(Text(r.name,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text('${r.orders.length}')),
              DataCell(Text(_fdj(_sum(r.orders, (o) => o.total)))),
              DataCell(Text(_fdj(_sum(r.orders, (o) => o.subtotal)))),
              DataCell(Text(_fdj(_sum(r.orders, (o) => o.loyaltyDiscount)))),
              DataCell(Text(_fdj(_sum(r.orders, (o) => o.livreurKeeps)),
                  style: const TextStyle(fontWeight: FontWeight.w600))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _paymentsList(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.isEmpty) return _empty('Aucun encaissement enregistré.');
    final sorted = docs.toList()
      ..sort((a, b) {
        final ta = Formatters.parseFirestoreDate(a.data()['createdAt']);
        final tb = Formatters.parseFirestoreDate(b.data()['createdAt']);
        if (ta == null || tb == null) return 0;
        return tb.compareTo(ta);
      });
    final f = DateFormat('dd/MM/yyyy');
    return Card(
      child: Column(
        children: sorted.take(20).map((d) {
          final data = d.data();
          final amount = data['amount'] is num ? data['amount'] as num : 0;
          final count = (data['orderIds'] as List?)?.length ?? 0;
          final start = Formatters.parseFirestoreDate(data['periodStart']);
          final end = Formatters.parseFirestoreDate(data['periodEnd']);
          final period = start != null && end != null
              ? ' (commandes du ${f.format(start)} au ${f.format(end.subtract(const Duration(days: 1)))})'
              : '';
          return ListTile(
            dense: true,
            leading: const Icon(Icons.handshake, color: successColor),
            title: Text(
                '${data['restaurantName'] ?? 'Restaurant'} — ${_fdj(amount)}$period'),
            subtitle: Text(
              '$count commande(s) • encaissé le '
              '${Formatters.formatFirestoreDate(data['createdAt'])} • '
              'par ${data['createdByEmail'] ?? '?'}',
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _confirmPaid(_RestaurantRow row, num remaining) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Commission encaissée — ${row.name}'),
        content: Text(
          'Le gérant a bien encaissé ${_fdj(remaining)} auprès de '
          '${row.name} pour ${row.unpaid.length} commande(s) livrée(s) '
          '${_period.label} ?\n\n'
          "L'encaissement sera enregistré avec la date et votre compte "
          '(non annulable).',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor, foregroundColor: Colors.white),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final user = FirebaseAuth.instance.currentUser;
    try {
      await _firestore.collection('restaurantCommissionPayments').add({
        'restaurantId': row.id,
        'restaurantName': row.name,
        'amount': remaining,
        'orderIds': row.unpaid.map((o) => o.id).toList(),
        'periodStart': Timestamp.fromDate(_period.start),
        'periodEnd': Timestamp.fromDate(_period.end),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user?.uid,
        'createdByEmail': user?.email,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Encaissement de ${row.name} enregistré'),
            backgroundColor: successColor),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: errorColor),
      );
    }
  }

  /// Fiche de tournée : détail des commandes livrées du restaurant sur la
  /// période, commission par commande et total dû. Ouverte dans un nouvel
  /// onglet avec la boîte d'impression.
  void _printSheet(_RestaurantRow r) {
    const esc = HtmlEscape();
    final f = DateFormat('dd/MM/yyyy HH:mm');
    final orders = r.orders.toList()
      ..sort((a, b) {
        if (a.createdAt == null || b.createdAt == null) return 0;
        return a.createdAt!.compareTo(b.createdAt!);
      });
    final rows = orders.map((o) {
      final items = o.items
          .map((i) => '${i.quantity} × ${esc.convert(i.name)}')
          .join('<br>');
      final paid = !r.unpaid.contains(o);
      return '<tr${paid ? ' class="paid"' : ''}>'
          '<td>${o.createdAt != null ? f.format(o.createdAt!) : ''}</td>'
          '<td>${esc.convert(o.customerName)}</td>'
          '<td>$items</td>'
          '<td class="n">${_fdj(o.subtotal)}</td>'
          '<td class="n">${_fdj(o.commission)}${paid ? ' (déjà encaissé)' : ''}</td>'
          '</tr>';
    }).join();
    final remaining = _sum(r.unpaid, (o) => o.commission);
    final doc = '''
<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8">
<title>Commissions ${esc.convert(r.name)}</title>
<style>
body{font-family:Arial,sans-serif;margin:24px;color:#222}
h1{font-size:20px;margin:0}h2{font-size:14px;font-weight:normal;color:#555}
table{border-collapse:collapse;width:100%;font-size:12px;margin-top:12px}
th,td{border:1px solid #ccc;padding:6px;vertical-align:top;text-align:left}
th{background:#f0f0f0}.n{text-align:right;white-space:nowrap}
tr.paid{color:#999}.total{font-size:16px;margin-top:16px;text-align:right}
.sign{margin-top:48px;display:flex;justify-content:space-between;font-size:12px}
</style></head><body>
<h1>NOMADE — Commissions dues par ${esc.convert(r.name)}</h1>
<h2>Commandes livrées ${esc.convert(_period.label)} — ${orders.length} commande(s) — éditée le ${f.format(DateTime.now())}</h2>
<table><thead><tr><th>Date</th><th>Client</th><th>Articles</th><th>Prix menu</th><th>Commission NOMADE</th></tr></thead>
<tbody>$rows</tbody></table>
<p class="total">Ventes : <b>${_fdj(_sum(orders, (o) => o.subtotal))}</b> — Commission totale : <b>${_fdj(_sum(orders, (o) => o.commission))}</b><br>
Reste à encaisser : <b>${_fdj(remaining)}</b></p>
<div class="sign"><span>Signature restaurant :</span><span>Signature gérant NOMADE :</span></div>
<script>window.onload=function(){window.print();}</script>
</body></html>''';
    final blob = html.Blob([doc], 'text/html;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
  }

  /// CSV « ; » + BOM UTF-8 : s'ouvre directement dans Excel (FR).
  void _exportCsv(List<OrderAccounting> orders) {
    String cell(Object? v) {
      final s = (v ?? '').toString();
      return s.contains(RegExp(r'[;"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final f = DateFormat('dd/MM/yyyy HH:mm');
    final lines = <String>[
      [
        'Date',
        'Commande',
        'Restaurant',
        'Livreur',
        'Client',
        'Paiement',
        'Prix menu (payé au resto)',
        'Commission NOMADE (est.)',
        'Net restaurant',
        'Frais livraison',
        'Points fidélité',
        'Code promo',
        'Payé par le client',
        'Gain livreur',
      ].map(cell).join(';'),
      ...orders.map((o) => [
            o.createdAt != null ? f.format(o.createdAt!) : '',
            o.id,
            o.restaurantName,
            o.livreurName,
            o.customerName,
            o.paymentLabel,
            o.subtotal,
            o.commission,
            o.restaurantNet,
            o.deliveryFee,
            o.loyaltyDiscount,
            o.promoDiscount,
            o.total,
            o.livreurKeeps,
          ].map(cell).join(';')),
    ];
    final bytes = utf8.encode('﻿${lines.join('\r\n')}');
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final name =
        'comptabilite_${DateFormat('yyyy-MM-dd').format(_period.start)}'
        '_${DateFormat('yyyy-MM-dd').format(_period.end.subtract(const Duration(days: 1)))}.csv';
    html.AnchorElement(href: url)
      ..download = name
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textDarkColor)),
      );

  Widget _empty([String text = 'Aucune commande livrée sur cette période.']) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Text(text, style: TextStyle(color: Colors.grey.shade600)),
        ),
      );

  Widget _statCard(IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(largePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 10),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textDarkColor)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }
}
