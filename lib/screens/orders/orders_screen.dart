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
import '../../models/order_tracking.dart';
import '../../widgets/period_filter.dart';

/// Suivi complet du cycle de vie des commandes : créée → en préparation
/// (resto) → prête → livreur en route vers le resto → en livraison →
/// livrée/annulée. Les délais (25 min préparation, 15 min trajet livreur→
/// resto, 30 min livraison) sont dérivés des timestamps déjà écrits sur
/// `orders` par les apps resto/livreur — voir [OrderTracking].
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Rafraîchit l'UI périodiquement pour recalculer les délais.
  Timer? _ticker;

  /// IDs déjà signalés comme critiques, pour ne biper qu'aux nouveaux.
  final Set<String> _knownCriticalIds = {};
  bool _soundEnabled = true;

  String _searchQuery = '';
  OrderPhase? _filterPhase;

  /// Période chargée (toutes les commandes de la période, sans plafond).
  /// 7 jours par défaut pour garder sous les yeux les commandes en cours
  /// passées la veille au soir.
  Period _period = Period.last7Days();

  /// Titre d'onglet capturé au démarrage, restauré quand plus rien n'est
  /// critique — permet d'alerter l'admin même si le son est coupé ou que
  /// l'onglet est en arrière-plan (pas soumis à la politique d'autoplay).
  late final String _baseTitle;
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalTableController = ScrollController();

  static const _filterablePhases = [
    OrderPhase.awaitingAcceptance,
    OrderPhase.preparing,
    OrderPhase.readyForPickup,
    OrderPhase.driverToRestaurant,
    OrderPhase.delivering,
    OrderPhase.delivered,
    OrderPhase.cancelled,
  ];

  @override
  void initState() {
    super.initState();
    _baseTitle = html.document.title;
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _horizontalController.dispose();
    _verticalTableController.dispose();
    html.document.title = _baseTitle;
    super.dispose();
  }

  void _updateTitleAlert(int criticalCount) {
    html.document.title =
        criticalCount > 0 ? '🔴 ($criticalCount) $_baseTitle' : _baseTitle;
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
    buffer.setUint32(16, 16, Endian.little);
    buffer.setUint16(20, 1, Endian.little);
    buffer.setUint16(22, 1, Endian.little);
    buffer.setUint32(24, sampleRate, Endian.little);
    buffer.setUint32(28, sampleRate * 2, Endian.little);
    buffer.setUint16(32, 2, Endian.little);
    buffer.setUint16(34, 16, Endian.little);
    writeString(36, 'data');
    buffer.setUint32(40, dataBytes, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
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
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _period
                .apply(_firestore.collection('orders'), 'createdAt')
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

              var items = snapshot.data!.docs
                  .map((d) => OrderTracking.fromMap(
                      d.id, d.data() as Map<String, dynamic>))
                  .toList();

              if (_filterPhase != null) {
                items = items.where((o) => o.phase == _filterPhase).toList();
              }

              if (_searchQuery.isNotEmpty) {
                items = items.where((o) {
                  return o.customerName.toLowerCase().contains(_searchQuery) ||
                      o.restaurantName.toLowerCase().contains(_searchQuery) ||
                      o.driverName.toLowerCase().contains(_searchQuery) ||
                      o.deliveryAddress.toLowerCase().contains(_searchQuery);
                }).toList();
              }

              // Détection des nouveaux critiques → bip sonore.
              final currentCritical = items
                  .where((o) =>
                      !o.isTerminal && o.delayLevel == DelayLevel.critical)
                  .map((o) => o.id)
                  .toSet();
              final newCritical = currentCritical.difference(_knownCriticalIds);
              if (newCritical.isNotEmpty) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _playAlert());
              }
              _knownCriticalIds
                ..clear()
                ..addAll(currentCritical);
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _updateTitleAlert(currentCritical.length));

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune commande ${_period.label}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return isMobile(context)
                  ? _buildMobileList(items)
                  : _buildDesktopTable(items);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      color: cardColor,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher une commande...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: backgroundColor,
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
              const SizedBox(width: 8),
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
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: PeriodFilterBar(
              period: _period,
              onChanged: (p) => setState(() => _period = p),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Tous'),
                    selected: _filterPhase == null,
                    onSelected: (_) => setState(() => _filterPhase = null),
                    selectedColor: primaryColor.withValues(alpha: 0.2),
                    checkmarkColor: primaryColor,
                    labelStyle: TextStyle(
                      color: _filterPhase == null
                          ? primaryColor
                          : Colors.grey.shade700,
                      fontWeight: _filterPhase == null
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                ..._filterablePhases.map((phase) {
                  final selected = _filterPhase == phase;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(orderPhaseLabel(phase)),
                      selected: selected,
                      onSelected: (_) => setState(() => _filterPhase = phase),
                      selectedColor: primaryColor.withValues(alpha: 0.2),
                      checkmarkColor: primaryColor,
                      labelStyle: TextStyle(
                        color: selected ? primaryColor : Colors.grey.shade700,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _phaseBadge(OrderTracking o) {
    final delay = o.delayLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: o.phaseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: o.phaseColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            o.phaseLabel,
            style: TextStyle(
              fontSize: 12,
              color: o.phaseColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (delay.isNotEmpty)
            Text(
              delay,
              style: TextStyle(
                fontSize: 11,
                color: o.phaseColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<OrderTracking> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final o = items[i];
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
                        o.restaurantName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _phaseBadge(o),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Client : ${o.customerName}'),
                if (o.customerPhone.isNotEmpty)
                  Text('Tél : ${o.customerPhone}'),
                if (o.driverName.isNotEmpty) Text('Livreur : ${o.driverName}'),
                Text('Total : ${o.total} FDJ'),
                Text('Créée le : ${_formatDate(o.createdAt)}'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (o.customerPhone.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.phone,
                            size: 20, color: primaryColor),
                        tooltip: 'Appeler le client',
                        onPressed: () => _call(o.customerPhone),
                      ),
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () => _showOrderDetails(o),
                      tooltip: 'Voir détails',
                    ),
                    _cancelButton(o),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tableau à hauteur bornée (= zone visible sous les filtres) : le scroll
  // horizontal ET le scroll vertical des lignes restent tous les deux
  // ancrés dans cette zone, donc leurs barres de défilement sont toujours
  // visibles et atteignables sans avoir à d'abord scroller la page entière
  // jusqu'en bas pour "tomber" dessus.
  Widget _buildDesktopTable(List<OrderTracking> items) {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableHeight = constraints.maxHeight;
          return SizedBox(
            height: tableHeight,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Scrollbar(
                controller: _horizontalController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    height: tableHeight,
                    child: Scrollbar(
                      controller: _verticalTableController,
                      thumbVisibility: true,
                      trackVisibility: true,
                      notificationPredicate: (notif) => notif.depth == 1,
                      child: SingleChildScrollView(
                        controller: _verticalTableController,
                        padding: const EdgeInsets.only(bottom: 12, right: 12),
                        child: DataTable(
                          columnSpacing: 24,
                          horizontalMargin: 16,
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 72,
                          // Ordre pensé pour rester lisible sans scroll
                          // horizontal sur un écran standard :
                          // Statut/Actions/Date d'abord (l'essentiel au
                          // premier coup d'œil — bouton "Voir détails" et
                          // heure de la commande), Téléphone/Livreur en
                          // dernier (consultables via le scroll horizontal,
                          // moins souvent nécessaires immédiatement).
                          columns: const [
                            DataColumn(label: Text('Statut')),
                            DataColumn(label: Text('Actions')),
                            DataColumn(label: Text('Créée le')),
                            DataColumn(label: Text('Restaurant')),
                            DataColumn(label: Text('Client')),
                            DataColumn(label: Text('Téléphone')),
                            DataColumn(label: Text('Livreur')),
                          ],
                          rows: items.map((o) {
                            return DataRow(cells: [
                              DataCell(_phaseBadge(o)),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.visibility,
                                          size: 20),
                                      onPressed: () => _showOrderDetails(o),
                                      tooltip: 'Voir détails',
                                    ),
                                    if (o.customerPhone.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.phone,
                                            size: 20, color: primaryColor),
                                        tooltip: 'Appeler le client',
                                        onPressed: () =>
                                            _call(o.customerPhone),
                                      ),
                                    _cancelButton(o),
                                  ],
                                ),
                              ),
                              DataCell(Text(_formatDate(o.createdAt,
                                  pattern: 'dd/MM HH:mm'))),
                              DataCell(Text(o.restaurantName)),
                              DataCell(Text(o.customerName)),
                              DataCell(Text(o.customerPhone.isEmpty
                                  ? '—'
                                  : o.customerPhone)),
                              DataCell(Text(
                                  o.driverName.isEmpty ? '—' : o.driverName)),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime? dt, {String pattern = 'dd/MM/yyyy HH:mm'}) {
    if (dt == null) return 'N/A';
    return DateFormat(pattern).format(dt);
  }

  void _showOrderDetails(OrderTracking o) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: primaryColor),
            const SizedBox(width: 8),
            const Text('Détails commande'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('ID', o.id),
              _detailRow('Statut', o.phaseLabel),
              if (o.delayLabel.isNotEmpty) _detailRow('Délai', o.delayLabel),
              _detailRow('Restaurant', o.restaurantName),
              _detailRow('Client', o.customerName),
              _detailRow('Téléphone', o.customerPhone),
              _detailRow('Adresse', o.deliveryAddress),
              _detailRow('Total', '${o.total} FDJ'),
              if (o.driverName.isNotEmpty) _detailRow('Livreur', o.driverName),
              const Divider(height: 20),
              _buildItemsSection(o.items),
              const Divider(height: 20),
              _detailRow('Créée le', _formatDate(o.createdAt)),
              _detailRow('Acceptée à', _formatDate(o.acceptedAt)),
              _detailRow('Prête à', _formatDate(o.readyAt)),
              _detailRow('Assignée à', _formatDate(o.assignedAt)),
              _detailRow('Récupérée à', _formatDate(o.pickedUpAt)),
              if (o.phase == OrderPhase.cancelled)
                _detailRow('Annulée à', _formatDate(o.cancelledAt))
              else
                _detailRow('Livrée à', _formatDate(o.deliveredAt)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Panier complet du client : chaque plat/produit avec sa quantité, son
  /// prix et — surtout — les sauces et suppléments choisis (un milkshake ou
  /// tout autre article ajouté au panier apparaît comme une ligne à part
  /// entière). Sans ça, l'admin ne voyait qu'un total global, incapable de
  /// vérifier ce que le client attend réellement.
  Widget _buildItemsSection(List<OrderLineItem> items) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Panier indisponible pour cette commande.',
          style: TextStyle(color: textLightColor, fontStyle: FontStyle.italic),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Panier du client',
            style: TextStyle(fontWeight: FontWeight.w600, color: textLightColor),
          ),
        ),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.name}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('${item.totalPrice.toInt()} FDJ',
                          style: const TextStyle(color: textLightColor)),
                    ],
                  ),
                  if (item.sauces.isNotEmpty || item.extras.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (item.sauces.isNotEmpty)
                            _optionTag('Sauce', item.sauces.join(', '), infoColor),
                          if (item.extras.isNotEmpty)
                            _optionTag(
                                'Supplément', item.extras.join(', '), warningColor),
                        ],
                      ),
                    ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _optionTag(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label : $value',
        style: TextStyle(fontSize: 12, color: color),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label :',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: textLightColor),
            ),
          ),
          Expanded(child: Text(value?.toString() ?? '-')),
        ],
      ),
    );
  }

  /// Icône Annuler toujours rendue (jamais masquée) : grisée/désactivée sur
  /// une commande déjà terminée, avec un tooltip qui explique pourquoi — pour
  /// qu'elle ne soit jamais perçue comme "absente".
  Widget _cancelButton(OrderTracking o) {
    final disabled = o.isTerminal;
    final tooltip = switch (o.phase) {
      OrderPhase.cancelled => 'Commande déjà annulée',
      OrderPhase.delivered => 'Commande déjà livrée',
      _ => 'Annuler la commande',
    };
    return IconButton(
      icon: Icon(Icons.cancel,
          size: 20, color: disabled ? Colors.grey.shade400 : errorColor),
      onPressed: disabled ? null : () => _confirmCancel(o.id),
      tooltip: tooltip,
    );
  }

  Future<void> _confirmCancel(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: const Text('Voulez-vous vraiment annuler cette commande ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Transaction : si un livreur est assigné (deliveryDriverId), le
        // libérer dans la même écriture que l'annulation, sinon il reste
        // bloqué à vie (currentOrderId rempli → canAcceptOrders faux côté
        // app Kotlin, sans aucun message d'erreur pour lui).
        final orderRef = _firestore.collection('orders').doc(orderId);
        await _firestore.runTransaction((tx) async {
          final orderSnap = await tx.get(orderRef);
          final driverId = orderSnap.data()?['deliveryDriverId'] as String?;

          var driverRef = driverId != null && driverId.isNotEmpty
              ? _firestore.collection('livreurs').doc(driverId)
              : null;
          if (driverRef != null && !(await tx.get(driverRef)).exists) {
            driverRef = null;
          }

          tx.update(orderRef, {
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (driverRef != null) {
            tx.update(driverRef, {
              'isAvailable': true,
              'currentOrderId': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Commande annulée'),
              backgroundColor: successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
          );
        }
      }
    }
  }
}
