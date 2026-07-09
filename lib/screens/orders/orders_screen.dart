import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _filterStatus = 'tous';

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(dynamic value, {String pattern = 'dd/MM/yyyy HH:mm'}) {
    final dt = _parseDate(value);
    if (dt == null) return 'N/A';
    return DateFormat(pattern).format(dt);
  }
  String _searchQuery = '';

  static const _statusList = [
    'tous',
    'pending',
    'ready',
    'delivering',
    'completed',
    'cancelled',
  ];

  static const _statusLabels = {
    'tous': 'Tous',
    'pending': 'En attente',
    'ready': 'Prête',
    'delivering': 'En livraison',
    'completed': 'Terminée',
    'cancelled': 'Annulée',
  };

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return successColor;
      case 'delivering':
        return infoColor;
      case 'ready':
        return warningColor;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return errorColor;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(defaultPadding),
          color: cardColor,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher une commande...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: backgroundColor,
                ),
                onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              ),
              const SizedBox(height: 12),
              // Filtres statut
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusList.map((s) {
                    final selected = _filterStatus == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(_statusLabels[s]!),
                        selected: selected,
                        onSelected: (_) =>
                            setState(() => _filterStatus = s),
                        selectedColor: primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: primaryColor,
                        labelStyle: TextStyle(
                          color: selected ? primaryColor : Colors.grey.shade700,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // Liste commandes
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('orders')
                .orderBy('createdAt', descending: true)
                .limit(200)
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

              var docs = snapshot.data!.docs.toList();

              // Tri par date décroissante (du plus récent au plus ancien)
              docs.sort((a, b) {
                final da = _parseDate(
                    (a.data() as Map<String, dynamic>)['createdAt']);
                final db = _parseDate(
                    (b.data() as Map<String, dynamic>)['createdAt']);
                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return db.compareTo(da);
              });

              // Filtre statut
              if (_filterStatus != 'tous') {
                docs = docs
                    .where((d) =>
                        (d.data() as Map<String, dynamic>)['status'] ==
                        _filterStatus)
                    .toList();
              }

              // Filtre recherche
              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final customer =
                      (data['customerName'] ?? '').toString().toLowerCase();
                  final restaurant =
                      (data['restaurantName'] ?? '').toString().toLowerCase();
                  final address =
                      (data['deliveryAddress'] ?? '').toString().toLowerCase();
                  return customer.contains(_searchQuery) ||
                      restaurant.contains(_searchQuery) ||
                      address.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune commande',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return isMobile(context)
                  ? _buildMobileList(docs)
                  : _buildDesktopTable(docs);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final data = docs[i].data() as Map<String, dynamic>;
        final status = data['status'] ?? 'pending';
        final createdAt = data['createdAt'] != null
            ? _formatDate(data['createdAt'])
            : 'N/A';

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
                        data['restaurantName'] ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Client: ${data['customerName'] ?? 'N/A'}'),
                Text('Tél: ${data['customerPhone'] ?? 'N/A'}'),
                Text(
                    'Total: ${data['total'] != null ? '${data['total']} FDJ' : 'N/A'}'),
                Text('Date: $createdAt'),
                if (data['deliveryDriverName'] != null)
                  Text('Livreur: ${data['deliveryDriverName']}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<QueryDocumentSnapshot> docs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          columns: const [
            DataColumn(label: Text('Statut')),
            DataColumn(label: Text('Restaurant')),
            DataColumn(label: Text('Client')),
            DataColumn(label: Text('Téléphone')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Livreur')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'pending';
            final createdAt = data['createdAt'] != null
                ? _formatDate(data['createdAt'], pattern: 'dd/MM HH:mm')
                : 'N/A';

            return DataRow(cells: [
              DataCell(_buildStatusBadge(status)),
              DataCell(Text(data['restaurantName'] ?? 'N/A')),
              DataCell(Text(data['customerName'] ?? 'N/A')),
              DataCell(Text(data['customerPhone'] ?? 'N/A')),
              DataCell(Text(
                  data['total'] != null ? '${data['total']} FDJ' : 'N/A')),
              DataCell(Text(data['deliveryDriverName'] ?? '-')),
              DataCell(Text(createdAt)),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, size: 20),
                      onPressed: () => _showOrderDetails(doc.id, data),
                      tooltip: 'Voir détails',
                    ),
                    if (['pending', 'confirmed', 'preparing', 'ready', 'delivering']
                        .contains(status))
                      IconButton(
                        icon: const Icon(Icons.cancel,
                            size: 20, color: errorColor),
                        onPressed: () => _confirmCancel(doc.id),
                        tooltip: 'Annuler',
                      ),
                  ],
                ),
              ),
            ]);
          }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor(status)),
      ),
      child: Text(
        _statusLabels[status] ?? status,
        style: TextStyle(
          fontSize: 12,
          color: _statusColor(status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showOrderDetails(String id, Map<String, dynamic> data) {
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
              _detailRow('ID', id),
              _detailRow('Statut', _statusLabels[data['status']] ?? data['status']),
              _detailRow('Restaurant', data['restaurantName']),
              _detailRow('Client', data['customerName']),
              _detailRow('Téléphone', data['customerPhone']),
              _detailRow('Adresse', data['deliveryAddress']),
              _detailRow('Sous-total', '${data['subtotal'] ?? 0} FDJ'),
              _detailRow('Livraison', '${data['deliveryFee'] ?? 0} FDJ'),
              _detailRow('Total', '${data['total'] ?? 0} FDJ'),
              _detailRow('Paiement', data['paymentMethod']),
              if (data['deliveryDriverName'] != null)
                _detailRow('Livreur', data['deliveryDriverName']),
              if (data['createdAt'] != null)
                _detailRow('Créée le', _formatDate(data['createdAt'])),
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

  Future<void> _confirmCancel(String orderId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler la commande'),
        content: const Text(
            'Voulez-vous vraiment annuler cette commande ?'),
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
        await _firestore.collection('orders').doc(orderId).update({
          'status': 'cancelled',
          'updatedAt': FieldValue.serverTimestamp(),
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
