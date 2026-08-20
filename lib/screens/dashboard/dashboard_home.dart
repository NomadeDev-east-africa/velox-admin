import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';

/// Élément unifié du flux d'activité récente.
class _ActivityItem {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DateTime? date;

  _ActivityItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.date,
  });
}

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          const Text(
            'Vue d\'ensemble',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textDarkColor,
            ),
          ),
          const SizedBox(height: defaultPadding),

          // Stats Cards
          _buildStatsCards(),

          const SizedBox(height: largePadding),

          // Activité récente
          const Text(
            'Activité récente',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textDarkColor,
            ),
          ),
          const SizedBox(height: defaultPadding),

          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
      builder: (context, driversSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('livreurs').snapshots(),
          builder: (context, livreursSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restaurants')
                  .snapshots(),
              builder: (context, restaurantsSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('orders')
                      .snapshots(),
                  builder: (context, ordersSnapshot) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection(FirebaseKeys.taxiRides)
                          .snapshots(),
                      builder: (context, ridesSnapshot) {
                        // Chauffeurs (taxi)
                        int totalDrivers = 0;
                        int activeDrivers = 0;
                        if (driversSnapshot.hasData) {
                          totalDrivers = driversSnapshot.data!.docs.length;
                          activeDrivers =
                              driversSnapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return false;
                            return (data['isActive'] ?? true) == true;
                          }).length;
                        }

                        // Livreurs
                        int totalLivreurs = 0;
                        int activeLivreurs = 0;
                        if (livreursSnapshot.hasData) {
                          totalLivreurs = livreursSnapshot.data!.docs.length;
                          activeLivreurs =
                              livreursSnapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return false;
                            return (data['isActive'] ?? true) == true;
                          }).length;
                        }

                        // Restaurants
                        int totalRestaurants = 0;
                        int activeRestaurants = 0;
                        if (restaurantsSnapshot.hasData) {
                          totalRestaurants =
                              restaurantsSnapshot.data!.docs.length;
                          activeRestaurants =
                              restaurantsSnapshot.data!.docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>?;
                            if (data == null) return false;
                            return (data['isActive'] ?? false) == true;
                          }).length;
                        }

                        final totalOrders =
                            ordersSnapshot.data?.docs.length ?? 0;
                        final totalRides = ridesSnapshot.data?.docs.length ?? 0;

                        return Wrap(
                          spacing: defaultPadding,
                          runSpacing: defaultPadding,
                          children: [
                            _wrappedStatCard(
                              icon: Icons.people,
                              title: 'Chauffeurs',
                              value: '$totalDrivers',
                              subtitle: '$activeDrivers actifs',
                              color: Colors.blue,
                            ),
                            _wrappedStatCard(
                              icon: Icons.delivery_dining,
                              title: 'Livreurs',
                              value: '$totalLivreurs',
                              subtitle: '$activeLivreurs actifs',
                              color: Colors.deepOrange,
                            ),
                            _wrappedStatCard(
                              icon: Icons.restaurant,
                              title: 'Restaurants',
                              value: '$totalRestaurants',
                              subtitle: '$activeRestaurants actifs',
                              color: Colors.orange,
                            ),
                            _wrappedStatCard(
                              icon: Icons.receipt_long,
                              title: 'Commandes',
                              value: '$totalOrders',
                              subtitle: 'Total',
                              color: Colors.purple,
                            ),
                            _wrappedStatCard(
                              icon: Icons.local_taxi,
                              title: 'Courses',
                              value: '$totalRides',
                              subtitle: 'Total',
                              color: Colors.green,
                            ),
                          ],
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
  }

  Widget _wrappedStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return SizedBox(
      width: 220,
      child: _buildStatCard(
        icon: icon,
        title: title,
        value: value,
        subtitle: subtitle,
        color: color,
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 32, color: color),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textDarkColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final db = FirebaseFirestore.instance;
    // orderBy sur un seul champ => index automatique (pas d'index composite).
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('orders')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (context, ordersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: db
              .collection('restaurants')
              .orderBy('createdAt', descending: true)
              .limit(15)
              .snapshots(),
          builder: (context, restoSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .limit(15)
                  .snapshots(),
              builder: (context, usersSnap) {
                final items = <_ActivityItem>[];

                if (ordersSnap.hasData) {
                  for (final doc in ordersSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final total = data['total'];
                    items.add(_ActivityItem(
                      icon: Icons.receipt_long,
                      color: Colors.blue,
                      title:
                          'Nouvelle commande — ${data['restaurantName'] ?? 'N/A'}',
                      subtitle: [
                        if (data['customerName'] != null)
                          'Client: ${data['customerName']}',
                        if (total != null) '$total FDJ',
                      ].join('  •  '),
                      date: _parseDate(data['createdAt']),
                    ));
                  }
                }

                if (restoSnap.hasData) {
                  for (final doc in restoSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    items.add(_ActivityItem(
                      icon: Icons.restaurant,
                      color: Colors.orange,
                      title: 'Nouveau restaurant — ${data['name'] ?? 'N/A'}',
                      subtitle: data['address']?.toString() ?? '',
                      date: _parseDate(data['createdAt']),
                    ));
                  }
                }

                if (usersSnap.hasData) {
                  for (final doc in usersSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    items.add(_ActivityItem(
                      icon: Icons.person_add,
                      color: Colors.purple,
                      title:
                          'Nouvel utilisateur — ${data['name'] ?? data['displayName'] ?? 'N/A'}',
                      subtitle: (data['phone'] ??
                              data['phoneNumber'] ??
                              data['email'] ??
                              '')
                          .toString(),
                      date: _parseDate(data['createdAt']),
                    ));
                  }
                }

                // Tri global du plus récent au plus ancien
                items.sort((a, b) {
                  if (a.date == null && b.date == null) return 0;
                  if (a.date == null) return 1;
                  if (b.date == null) return -1;
                  return b.date!.compareTo(a.date!);
                });

                final recent = items.take(15).toList();

                final waiting =
                    ordersSnap.connectionState == ConnectionState.waiting &&
                        restoSnap.connectionState == ConnectionState.waiting &&
                        usersSnap.connectionState == ConnectionState.waiting;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(largePadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Activités récentes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: defaultPadding),
                        if (waiting)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(largePadding),
                              child: CircularProgressIndicator(
                                  color: primaryColor),
                            ),
                          )
                        else if (recent.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(largePadding),
                              child: Column(
                                children: [
                                  Icon(Icons.history,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Aucune activité récente',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...recent.map(_buildActivityRow),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActivityRow(_ActivityItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: item.color.withValues(alpha: 0.1),
            child: Icon(item.icon, size: 18, color: item.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle.isNotEmpty)
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.date != null
                ? DateFormat('dd/MM HH:mm').format(item.date!)
                : '',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
