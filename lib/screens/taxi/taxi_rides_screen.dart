import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';

class TaxiRidesScreen extends StatefulWidget {
  const TaxiRidesScreen({super.key});

  @override
  State<TaxiRidesScreen> createState() => _TaxiRidesScreenState();
}

class _TaxiRidesScreenState extends State<TaxiRidesScreen> {
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
    'requested',
    'accepted',
    'started',
    'completed',
    'cancelled',
  ];

  static const _statusLabels = {
    'tous': 'Tous',
    'requested': 'Demandée',
    'accepted': 'Acceptée',
    'started': 'En cours',
    'completed': 'Terminée',
    'cancelled': 'Annulée',
  };

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return successColor;
      case 'started':
        return infoColor;
      case 'accepted':
        return warningColor;
      case 'requested':
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
          color: Colors.white,
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un passager ou chauffeur...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: backgroundColor,
                ),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
              ),
              const SizedBox(height: 12),
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
                          color:
                              selected ? primaryColor : Colors.grey.shade700,
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

        // Liste courses
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('taxiRides')
                .orderBy('requestedAt', descending: true)
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

              var docs = snapshot.data!.docs;

              if (_filterStatus != 'tous') {
                docs = docs
                    .where((d) =>
                        (d.data() as Map<String, dynamic>)['status'] ==
                        _filterStatus)
                    .toList();
              }

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final user =
                      (data['userName'] ?? '').toString().toLowerCase();
                  final driver =
                      (data['driverName'] ?? '').toString().toLowerCase();
                  final phone =
                      (data['userPhone'] ?? '').toString().toLowerCase();
                  return user.contains(_searchQuery) ||
                      driver.contains(_searchQuery) ||
                      phone.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_taxi,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune course',
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
        final status = data['status'] ?? 'requested';
        final requestedAt = data['requestedAt'] != null
            ? _formatDate(data['requestedAt'])
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
                        data['userName'] ?? 'N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    _buildStatusBadge(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Tél: ${data['userPhone'] ?? 'N/A'}'),
                Text('Type: ${data['vehicleType'] ?? 'N/A'}'),
                Text(
                    'Tarif estimé: ${data['estimatedFare'] != null ? '${data['estimatedFare'].toStringAsFixed(0)} FDJ' : 'N/A'}'),
                if (data['finalFare'] != null)
                  Text('Tarif final: ${data['finalFare']} FDJ'),
                if (data['driverName'] != null)
                  Text('Chauffeur: ${data['driverName']}'),
                Text('Date: $requestedAt'),
                if (data['cancellationReason'] != null)
                  Text(
                    'Raison annulation: ${data['cancellationReason']}',
                    style: const TextStyle(color: errorColor),
                  ),
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
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Statut')),
            DataColumn(label: Text('Passager')),
            DataColumn(label: Text('Téléphone')),
            DataColumn(label: Text('Type véhicule')),
            DataColumn(label: Text('Tarif estimé')),
            DataColumn(label: Text('Tarif final')),
            DataColumn(label: Text('Chauffeur')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? 'requested';
            final requestedAt = data['requestedAt'] != null
                ? _formatDate(data['requestedAt'], pattern: 'dd/MM HH:mm')
                : 'N/A';

            return DataRow(cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _statusLabels[status] ?? status,
                      style: TextStyle(
                        fontSize: 11,
                        color: _statusColor(status),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(Text(data['userName'] ?? 'N/A')),
              DataCell(Text(data['userPhone'] ?? 'N/A')),
              DataCell(Text(data['vehicleType'] ?? 'N/A')),
              DataCell(Text(data['estimatedFare'] != null
                  ? '${(data['estimatedFare'] as num).toStringAsFixed(0)} FDJ'
                  : 'N/A')),
              DataCell(Text(
                  data['finalFare'] != null ? '${data['finalFare']} FDJ' : '-')),
              DataCell(Text(data['driverName'] ?? '-')),
              DataCell(Text(requestedAt)),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.visibility, size: 20),
                  onPressed: () => _showRideDetails(doc.id, data),
                  tooltip: 'Voir détails',
                ),
              ),
            ]);
          }).toList(),
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

  void _showRideDetails(String id, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.local_taxi, color: primaryColor),
            SizedBox(width: 8),
            Text('Détails de la course'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('ID', id),
              _detailRow('Statut', _statusLabels[data['status']] ?? data['status']),
              _detailRow('Passager', data['userName']),
              _detailRow('Téléphone', data['userPhone']),
              _detailRow('Type', data['vehicleType']),
              _detailRow('Paiement', data['paymentMethod']),
              _detailRow(
                  'Tarif estimé',
                  data['estimatedFare'] != null
                      ? '${(data['estimatedFare'] as num).toStringAsFixed(0)} FDJ'
                      : null),
              if (data['finalFare'] != null)
                _detailRow('Tarif final', '${data['finalFare']} FDJ'),
              _detailRow(
                  'Distance',
                  data['distance'] != null
                      ? '${(data['distance'] as num).toStringAsFixed(2)} km'
                      : null),
              _detailRow(
                  'Durée estimée',
                  data['estimatedDuration'] != null
                      ? '${data['estimatedDuration']} min'
                      : null),
              if (data['driverName'] != null)
                _detailRow('Chauffeur', data['driverName']),
              if (data['driverPhone'] != null)
                _detailRow('Tél chauffeur', data['driverPhone']),
              if (data['cancellationReason'] != null)
                _detailRow('Annulation', data['cancellationReason']),
              if (data['requestedAt'] != null)
                _detailRow('Demandée le', _formatDate(data['requestedAt'])),
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
            width: 110,
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
}
