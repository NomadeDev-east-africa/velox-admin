import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../models/private_order.dart';
import '../../widgets/period_filter.dart';
import 'private_order_editor.dart';

/// Commandes **privées** : passées hors de l'app (WhatsApp surtout) et saisies
/// à la main par les admins, pour garder la trace de toutes les commandes et
/// de leur argent. Collection `privateOrders`.
class PrivateOrdersScreen extends StatefulWidget {
  const PrivateOrdersScreen({super.key});

  @override
  State<PrivateOrdersScreen> createState() => _PrivateOrdersScreenState();
}

class _PrivateOrdersScreenState extends State<PrivateOrdersScreen> {
  final _col = FirebaseFirestore.instance.collection('privateOrders');
  Period _period = Period.thisMonth();
  String _search = '';
  String? _statusFilter; // null = tous
  final _money = NumberFormat('#,##0');
  final _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

  String _fdj(num v) => '${_money.format(v)} FDJ';

  bool _matches(PrivateOrder o) {
    if (_statusFilter != null && o.status != _statusFilter) return false;
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      o.clientName,
      o.clientPhone,
      o.restaurantName,
      o.livreurName,
      o.itemsSummary,
      o.notes,
    ].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
        onPressed: () => openPrivateOrderEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Commande privée'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _period.apply(_col, 'orderDate').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(largePadding),
                child: Text(
                  'Erreur de chargement : ${snap.error}\n\n'
                  'Si le message parle de permissions, les règles Firestore '
                  '(bloc privateOrders) ne sont pas encore publiées.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: errorColor),
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: primaryColor));
          }
          final all = snap.data!.docs
              .map((d) => PrivateOrder.fromMap(d.id, d.data()))
              .toList();
          final shown = all.where(_matches).toList();
          return _content(all, shown);
        },
      ),
    );
  }

  Widget _content(List<PrivateOrder> all, List<PrivateOrder> shown) {
    final valid = all.where((o) => !o.isCancelled).toList();
    final totalAmount = valid.fold<num>(0, (s, o) => s + o.total);
    final menuAmount = valid.fold<num>(0, (s, o) => s + o.subtotal);
    final deliveryAmount = valid.fold<num>(0, (s, o) => s + o.deliveryFee);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          defaultPadding, defaultPadding, defaultPadding, 96),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Commandes privées (WhatsApp, téléphone…)',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textDarkColor),
              ),
            ),
            ElevatedButton.icon(
              onPressed: shown.isEmpty ? null : () => _exportCsv(shown),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Exporter (Excel)'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, foregroundColor: Colors.black),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PeriodFilterBar(
          period: _period,
          onChanged: (p) => setState(() => _period = p),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat('Commandes', '${valid.length}', Icons.receipt_long),
            _stat('Montant total', _fdj(totalAmount), Icons.payments),
            _stat(
                'Prix menu (restaurants)', _fdj(menuAmount), Icons.restaurant),
            _stat('Frais de livraison', _fdj(deliveryAmount),
                Icons.delivery_dining),
          ],
        ),
        if (all.length != valid.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '${all.length - valid.length} commande(s) annulée(s) non comptée(s).',
              style: const TextStyle(fontSize: 12, color: textLightColor),
            ),
          ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Client, téléphone, restaurant, plat…',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            _statusChip(null, 'Toutes'),
            for (final s in PrivateOrderStatus.all)
              _statusChip(s, PrivateOrderStatus.label(s)),
          ],
        ),
        const SizedBox(height: 16),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                all.isEmpty
                    ? 'Aucune commande privée ${_period.label}.\n'
                        'Cliquez sur « Commande privée » pour en saisir une.'
                    : 'Aucune commande ne correspond au filtre.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: textLightColor),
              ),
            ),
          )
        else
          ...shown.map(_orderCard),
      ],
    );
  }

  Widget _statusChip(String? status, String label) {
    final selected = _statusFilter == status;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: primaryColor.withValues(alpha: 0.2),
      onSelected: (_) => setState(() => _statusFilter = status),
    );
  }

  Widget _stat(String label, String value, IconData icon) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 12, color: textLightColor)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textDarkColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case PrivateOrderStatus.delivered:
        return successColor;
      case PrivateOrderStatus.cancelled:
        return errorColor;
      default:
        return warningColor;
    }
  }

  Widget _orderCard(PrivateOrder o) {
    final color = _statusColor(o.status);
    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${o.restaurantName} — ${o.clientName.isEmpty ? 'Client' : o.clientName}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textDarkColor,
                  decoration: o.isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(_fdj(o.total),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: primaryColor)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(_dateFmt.format(o.orderDate),
                  style: const TextStyle(color: textLightColor)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(PrivateOrderStatus.label(o.status),
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w600)),
              ),
              Text(PrivateOrder.sourceLabel(o.source),
                  style: const TextStyle(color: textLightColor)),
              Text(o.itemsSummary,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: textLightColor)),
            ],
          ),
        ),
        children: [_details(o)],
      ),
    );
  }

  Widget _details(PrivateOrder o) {
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  width: 150,
                  child:
                      Text(k, style: const TextStyle(color: textLightColor))),
              Expanded(
                  child: Text(v.isEmpty ? '—' : v,
                      style: const TextStyle(color: textDarkColor))),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        row('Client', o.clientName),
        row('Téléphone', o.clientPhone),
        row('Adresse', o.deliveryAddress),
        row('Restaurant', o.restaurantName),
        row('Livreur', o.livreurName),
        row('Paiement', PrivatePayment.label(o.paymentMethod)),
        row('Saisie par', o.createdByEmail),
        const SizedBox(height: 8),
        const Text('Détail de la commande',
            style:
                TextStyle(fontWeight: FontWeight.w600, color: textDarkColor)),
        const SizedBox(height: 4),
        for (final l in o.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                    child: Text('${l.quantity}× ${l.name}',
                        style: const TextStyle(color: textDarkColor))),
                Text(
                    '${_money.format(l.unitPrice)} × ${l.quantity} = ${_fdj(l.lineTotal)}',
                    style: const TextStyle(color: textLightColor)),
              ],
            ),
          ),
        const Divider(),
        row('Prix menu', _fdj(o.subtotal)),
        row('Frais de livraison', _fdj(o.deliveryFee)),
        row('Total payé', _fdj(o.total)),
        if (o.notes.isNotEmpty) row('Notes', o.notes),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: () => _delete(o),
              icon: const Icon(Icons.delete_outline, color: errorColor),
              label:
                  const Text('Supprimer', style: TextStyle(color: errorColor)),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => openPrivateOrderEditor(context, existing: o),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Modifier'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, foregroundColor: Colors.black),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _delete(PrivateOrder o) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la commande ?'),
        content: Text(
          'Commande ${o.restaurantName} du ${_dateFmt.format(o.orderDate)} '
          '(${_fdj(o.total)}).\n\nPour garder une trace, préférez le statut '
          '« Annulée ». La suppression est définitive.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _col.doc(o.id).delete();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: errorColor));
    }
  }

  void _exportCsv(List<PrivateOrder> orders) {
    String cell(Object? v) {
      final s = (v ?? '').toString();
      return s.contains(RegExp(r'[;"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final lines = <String>[
      [
        'Date',
        'Source',
        'Statut',
        'Client',
        'Téléphone',
        'Adresse',
        'Restaurant',
        'Détail',
        'Nb articles',
        'Prix menu',
        'Frais livraison',
        'Total',
        'Paiement',
        'Livreur',
        'Notes',
        'Saisie par',
      ].map(cell).join(';'),
      ...orders.map((o) => [
            _dateFmt.format(o.orderDate),
            PrivateOrder.sourceLabel(o.source),
            PrivateOrderStatus.label(o.status),
            o.clientName,
            o.clientPhone,
            o.deliveryAddress,
            o.restaurantName,
            o.itemsSummary,
            o.itemCount,
            o.subtotal,
            o.deliveryFee,
            o.total,
            PrivatePayment.label(o.paymentMethod),
            o.livreurName,
            o.notes,
            o.createdByEmail,
          ].map(cell).join(';')),
    ];
    final bytes = utf8.encode('﻿${lines.join('\r\n')}');
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final d = DateFormat('yyyy-MM-dd');
    final name = 'commandes_privees_${d.format(_period.start)}'
        '_${d.format(_period.end.subtract(const Duration(days: 1)))}.csv';
    html.AnchorElement(href: url)
      ..download = name
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
