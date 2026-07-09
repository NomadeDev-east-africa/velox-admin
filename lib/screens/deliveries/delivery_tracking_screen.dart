import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../models/delivery_tracking.dart';

/// Suivi temps réel des livraisons en cours, mettant en évidence les livreurs
/// en retard (« Timeline des livreurs retardataires »).
///
/// Source : collection `orders`, filtrée sur les commandes prises en charge
/// (`pickedUpAt` renseigné) et non terminées. Retard calculé sur
/// `pickedUpAt + DeliveryTracking.targetMinutes`.
class DeliveryTrackingScreen extends StatefulWidget {
  const DeliveryTrackingScreen({super.key});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Rafraîchit l'UI périodiquement pour recalculer les retards (le temps passe
  /// même sans nouvelle écriture Firestore).
  Timer? _ticker;

  /// IDs déjà signalés comme critiques, pour ne biper qu'aux nouveaux.
  final Set<String> _knownCriticalIds = {};
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Color _levelColor(DelayLevel level) {
    switch (level) {
      case DelayLevel.onTime:
        return successColor;
      case DelayLevel.late:
        return warningColor;
      case DelayLevel.critical:
        return errorColor;
    }
  }

  String _levelLabel(DelayLevel level) {
    switch (level) {
      case DelayLevel.onTime:
        return "À l'heure";
      case DelayLevel.late:
        return 'En retard';
      case DelayLevel.critical:
        return 'Critique';
    }
  }

  void _playAlert() {
    if (!_soundEnabled) return;
    try {
      html.AudioElement(_beepDataUri()).play();
    } catch (_) {
      // Audio indisponible (autoplay bloqué tant que l'admin n'a pas interagi).
    }
  }

  /// Génère un court bip (880 Hz, ~0,25 s) encodé en WAV/base64, sans fichier
  /// asset ni dépendance externe.
  String _beepDataUri() {
    const sampleRate = 8000;
    const seconds = 0.25;
    const freq = 880.0;
    final sampleCount = (sampleRate * seconds).round();
    final dataBytes = sampleCount * 2; // 16-bit mono
    final buffer = ByteData(44 + dataBytes);

    void writeString(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        buffer.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    buffer.setUint32(4, 36 + dataBytes, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    buffer.setUint32(16, 16, Endian.little); // PCM chunk size
    buffer.setUint16(20, 1, Endian.little); // PCM format
    buffer.setUint16(22, 1, Endian.little); // mono
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    buffer.setUint16(32, 2, Endian.little); // block align
    buffer.setUint16(34, 16, Endian.little); // bits per sample
    writeString(36, 'data');
    buffer.setUint32(40, dataBytes, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      // Légère enveloppe pour éviter le clic.
      final env = math.min(1.0, math.min(i, sampleCount - i) / 200.0);
      final sample =
          (math.sin(2 * math.pi * freq * i / sampleRate) * 0.3 * env * 32767)
              .round();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    final b64 = base64Encode(buffer.buffer.asUint8List());
    return 'data:audio/wav;base64,$b64';
  }

  void _call(String phone) {
    final cleaned = phone.replaceAll(' ', '');
    if (cleaned.isEmpty) return;
    html.window.open('tel:$cleaned', '_self');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(150)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }

        // Filtre : livraisons actives (prises en charge, non terminées).
        final items = <DeliveryTracking>[];
        for (var i = 0; i < snapshot.data!.docs.length; i++) {
          final doc = snapshot.data!.docs[i];
          final data = doc.data() as Map<String, dynamic>;
          if (DeliveryTracking.isActiveDelivery(data)) {
            items.add(DeliveryTracking.fromMap(doc.id, data));
          }
        }
        // Tri : retard décroissant (les plus en retard en haut).
        items.sort((a, b) => b.delayMinutes.compareTo(a.delayMinutes));

        // Détection des nouveaux critiques → bip sonore.
        final currentCritical = items
            .where((e) => e.level == DelayLevel.critical)
            .map((e) => e.orderId)
            .toSet();
        final newCritical = currentCritical.difference(_knownCriticalIds);
        if (newCritical.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _playAlert());
        }
        _knownCriticalIds
          ..clear()
          ..addAll(currentCritical);

        final lateCount =
            items.where((e) => e.level == DelayLevel.late).length;
        final criticalCount = currentCritical.length;

        return Column(
          children: [
            _buildHeader(items.length, lateCount, criticalCount),
            Expanded(
              child: items.isEmpty
                  ? _buildEmpty()
                  : (isMobile(context)
                      ? _buildMobileList(items)
                      : _buildDesktopTable(items)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int total, int late, int critical) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      color: cardColor,
      child: Row(
        children: [
          _statChip('En cours', total, infoColor, Icons.delivery_dining),
          const SizedBox(width: 12),
          _statChip('En retard', late, warningColor, Icons.schedule),
          const SizedBox(width: 12),
          _statChip('Critique', critical, errorColor, Icons.warning_amber),
          const Spacer(),
          IconButton(
            tooltip: _soundEnabled ? 'Couper le son' : 'Activer le son',
            icon: Icon(
              _soundEnabled ? Icons.volume_up : Icons.volume_off,
              color: _soundEnabled ? primaryColor : Colors.grey,
            ),
            onPressed: () => setState(() => _soundEnabled = !_soundEnabled),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(defaultRadius),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucune livraison en cours',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(List<DeliveryTracking> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          columns: const [
            DataColumn(label: Text('Retard')),
            DataColumn(label: Text('Livreur')),
            DataColumn(label: Text('Restaurant')),
            DataColumn(label: Text('Client')),
            DataColumn(label: Text('Téléphone')),
            DataColumn(label: Text('Prise en charge')),
            DataColumn(label: Text('Actions')),
          ],
          rows: items.map((e) {
            final color = _levelColor(e.level);
            return DataRow(cells: [
              DataCell(_delayBadge(e)),
              DataCell(Text(e.driverName,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(e.restaurantName)),
              DataCell(Text(e.customerName)),
              DataCell(Text(e.customerPhone.isEmpty ? '—' : e.customerPhone)),
              DataCell(Text(e.pickedUpAt != null
                  ? DateFormat('dd/MM HH:mm').format(e.pickedUpAt!)
                  : '—')),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.phone, size: 20, color: color),
                    tooltip: 'Appeler le client',
                    onPressed: e.customerPhone.isEmpty
                        ? null
                        : () => _call(e.customerPhone),
                  ),
                ],
              )),
            ]);
          }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileList(List<DeliveryTracking> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final color = _levelColor(e.level);
        return Card(
          margin: const EdgeInsets.only(bottom: defaultPadding),
          child: Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        e.driverName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    _delayBadge(e),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Resto : ${e.restaurantName}'),
                Text('Client : ${e.customerName}'),
                if (e.pickedUpAt != null)
                  Text(
                    'Pris en charge : ${DateFormat('dd/MM HH:mm').format(e.pickedUpAt!)}',
                    style: const TextStyle(color: textLightColor, fontSize: 13),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(Icons.phone, size: 18, color: color),
                    label: Text(
                      e.customerPhone.isEmpty ? 'Sans numéro' : 'Appeler client',
                      style: TextStyle(color: color),
                    ),
                    onPressed: e.customerPhone.isEmpty
                        ? null
                        : () => _call(e.customerPhone),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _delayBadge(DeliveryTracking e) {
    final color = _levelColor(e.level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _levelLabel(e.level),
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          Text(
            e.delayLabel,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
