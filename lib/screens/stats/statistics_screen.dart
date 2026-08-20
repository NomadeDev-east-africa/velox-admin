import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../models/order_tracking.dart';

/// Page Statistiques — remplace le placeholder "À venir". Suit le pattern
/// déjà utilisé dans dashboard_home.dart (StreamBuilders imbriqués, comptage
/// client-side), sans dépendance de graphique.
class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  static const _ordersWindow = 500;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collection('restaurants').snapshots(),
        builder: (context, restoSnap) {
          return StreamBuilder<QuerySnapshot>(
            stream:
                FirebaseFirestore.instance.collection('livreurs').snapshots(),
            builder: (context, livreursSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('drivers')
                    .snapshots(),
                builder: (context, driversSnap) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (context, usersSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('orders')
                            .orderBy('createdAt', descending: true)
                            .limit(_ordersWindow)
                            .snapshots(),
                        builder: (context, ordersSnap) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('taxiRides')
                                .orderBy('requestedAt', descending: true)
                                .limit(_ordersWindow)
                                .snapshots(),
                            builder: (context, ridesSnap) {
                              final loading = !restoSnap.hasData ||
                                  !livreursSnap.hasData ||
                                  !driversSnap.hasData ||
                                  !usersSnap.hasData ||
                                  !ordersSnap.hasData ||
                                  !ridesSnap.hasData;

                              if (loading) {
                                return const Padding(
                                  padding: EdgeInsets.all(48),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                        color: primaryColor),
                                  ),
                                );
                              }

                              return _buildContent(
                                restoSnap.data!.docs,
                                livreursSnap.data!.docs,
                                driversSnap.data!.docs,
                                usersSnap.data!.docs,
                                ordersSnap.data!.docs,
                                ridesSnap.data!.docs,
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(
    List<QueryDocumentSnapshot> restoDocs,
    List<QueryDocumentSnapshot> livreurDocs,
    List<QueryDocumentSnapshot> driverDocs,
    List<QueryDocumentSnapshot> userDocs,
    List<QueryDocumentSnapshot> orderDocs,
    List<QueryDocumentSnapshot> rideDocs,
  ) {
    // Restaurants
    int activeRestos = 0, openRestos = 0;
    for (final d in restoDocs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['isActive'] ?? true) activeRestos++;
      if (data['isOpen'] ?? false) openRestos++;
    }

    // Livreurs
    int activeLivreurs = 0, onlineLivreurs = 0;
    for (final d in livreurDocs) {
      final data = d.data() as Map<String, dynamic>;
      if (data['isActive'] ?? true) activeLivreurs++;
      if (data['isOnline'] ?? false) onlineLivreurs++;
    }

    // Chauffeurs (taxi)
    int onlineDrivers = 0;
    for (final d in driverDocs) {
      final data = d.data() as Map<String, dynamic>;
      if ((data['isOnline'] ?? data['is_online'] ?? false) == true) {
        onlineDrivers++;
      }
    }

    // Commandes (fenêtre des 500 dernières)
    final orders = orderDocs
        .map((d) =>
            OrderTracking.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList();
    final delivered =
        orders.where((o) => o.phase == OrderPhase.delivered).toList();
    final cancelled =
        orders.where((o) => o.phase == OrderPhase.cancelled).length;
    final ongoing = orders.where((o) => !o.isTerminal).length;
    final revenue = delivered.fold<num>(0, (sum, o) => sum + o.total);

    // Top 5 restaurants par nombre de commandes (fenêtre des 500 dernières)
    final countByRestaurant = <String, int>{};
    for (final o in orders) {
      if (o.restaurantName.isEmpty) continue;
      countByRestaurant[o.restaurantName] =
          (countByRestaurant[o.restaurantName] ?? 0) + 1;
    }
    final topRestaurants = countByRestaurant.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Courses VTC (fenêtre des 500 dernières) — mêmes valeurs de `status`
    // que `taxi_rides_screen.dart` (requested/accepted/started/completed/cancelled).
    int rideCompleted = 0, rideCancelled = 0;
    num rideRevenue = 0;
    for (final d in rideDocs) {
      final data = d.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'requested';
      if (status == 'completed') {
        rideCompleted++;
        final fare = data['finalFare'] ?? data['estimatedFare'];
        if (fare is num) rideRevenue += fare;
      } else if (status == 'cancelled') {
        rideCancelled++;
      }
    }
    final rideOngoing = rideDocs.length - rideCompleted - rideCancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistiques',
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: textDarkColor),
        ),
        const SizedBox(height: defaultPadding),
        _sectionTitle('Restaurants'),
        _statsRow([
          _StatCardData(
              Icons.restaurant, 'Total', '${restoDocs.length}', Colors.orange),
          _StatCardData(
              Icons.check_circle, 'Actifs', '$activeRestos', successColor),
          _StatCardData(Icons.storefront, 'Ouverts', '$openRestos', infoColor),
        ]),
        const SizedBox(height: largePadding),
        _sectionTitle('Livreurs'),
        _statsRow([
          _StatCardData(Icons.delivery_dining, 'Total', '${livreurDocs.length}',
              Colors.orange),
          _StatCardData(
              Icons.check_circle, 'Actifs', '$activeLivreurs', successColor),
          _StatCardData(Icons.wifi, 'En ligne', '$onlineLivreurs', infoColor),
        ]),
        const SizedBox(height: largePadding),
        _sectionTitle('Chauffeurs (taxi)'),
        _statsRow([
          _StatCardData(
              Icons.local_taxi, 'Total', '${driverDocs.length}', Colors.blue),
          _StatCardData(Icons.wifi, 'En ligne', '$onlineDrivers', infoColor),
        ]),
        const SizedBox(height: largePadding),
        _sectionTitle('Clients'),
        _statsRow([
          _StatCardData(Icons.people, 'Total inscrits', '${userDocs.length}',
              Colors.purple),
        ]),
        const SizedBox(height: largePadding),
        _sectionTitle('Commandes (${orders.length} dernières)'),
        _statsRow([
          _StatCardData(
              Icons.receipt_long, 'Total', '${orders.length}', Colors.orange),
          _StatCardData(Icons.check_circle, 'Livrées', '${delivered.length}',
              successColor),
          _StatCardData(Icons.cancel, 'Annulées', '$cancelled', errorColor),
          _StatCardData(Icons.timelapse, 'En cours', '$ongoing', infoColor),
        ]),
        const SizedBox(height: defaultPadding),
        _statsRow([
          _StatCardData(Icons.attach_money, 'Chiffre d\'affaires (livrées)',
              '${NumberFormat('#,###').format(revenue)} FDJ', successColor),
        ]),
        const SizedBox(height: largePadding),
        _sectionTitle('Courses VTC (${rideDocs.length} dernières)'),
        _statsRow([
          _StatCardData(
              Icons.local_taxi, 'Total', '${rideDocs.length}', Colors.blue),
          _StatCardData(
              Icons.check_circle, 'Terminées', '$rideCompleted', successColor),
          _StatCardData(Icons.cancel, 'Annulées', '$rideCancelled', errorColor),
          _StatCardData(Icons.timelapse, 'En cours', '$rideOngoing', infoColor),
        ]),
        const SizedBox(height: defaultPadding),
        _statsRow([
          _StatCardData(Icons.attach_money, 'Chiffre d\'affaires (terminées)',
              '${NumberFormat('#,###').format(rideRevenue)} FDJ', successColor),
        ]),
        const SizedBox(height: largePadding),
        _sectionTitle('Top restaurants (${orders.length} dernières commandes)'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: topRestaurants.isEmpty
                ? Text('Aucune donnée',
                    style: TextStyle(color: Colors.grey.shade600))
                : Column(
                    children: topRestaurants.take(5).map((e) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(e.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                            ),
                            Text('${e.value} commandes',
                                style: TextStyle(color: Colors.grey.shade600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: textDarkColor),
      ),
    );
  }

  Widget _statsRow(List<_StatCardData> cards) {
    return Wrap(
      spacing: defaultPadding,
      runSpacing: defaultPadding,
      children: cards.map((c) {
        return SizedBox(
          width: 220,
          child: _buildStatCard(c),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(_StatCardData c) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(c.icon, size: 28, color: c.color),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              c.value,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textDarkColor),
            ),
            const SizedBox(height: 4),
            Text(
              c.label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  _StatCardData(this.icon, this.label, this.value, this.color);
}
