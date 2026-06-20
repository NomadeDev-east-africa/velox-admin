import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

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
          stream:
              FirebaseFirestore.instance.collection('restaurants').snapshots(),
          builder: (context, restaurantsSnapshot) {
            // Compter les chauffeurs
            int totalDrivers = 0;
            int onlineDrivers = 0;

            if (driversSnapshot.hasData) {
              totalDrivers = driversSnapshot.data!.docs.length;
              onlineDrivers = driversSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) return false;
                // Gestion des deux formats de noms de champs
                return (data['isOnline'] ?? data['is_online'] ?? false) == true;
              }).length;
            }

            // Compter les restaurants
            int totalRestaurants = 0;
            int activeRestaurants = 0;

            if (restaurantsSnapshot.hasData) {
              totalRestaurants = restaurantsSnapshot.data!.docs.length;
              activeRestaurants = restaurantsSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>?;
                if (data == null) return false;
                return (data['isActive'] ?? false) == true;
              }).length;
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                if (isMobile(context)) {
                  return Column(
                    children: [
                      _buildStatCard(
                        icon: Icons.people,
                        title: 'Chauffeurs',
                        value: '$totalDrivers',
                        subtitle: '$onlineDrivers en ligne',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: defaultPadding),
                      _buildStatCard(
                        icon: Icons.restaurant,
                        title: 'Restaurants',
                        value: '$totalRestaurants',
                        subtitle: '$activeRestaurants actifs',
                        color: Colors.orange,
                      ),
                      const SizedBox(height: defaultPadding),
                      _buildStatCard(
                        icon: Icons.local_taxi,
                        title: 'Courses',
                        value: '0',
                        subtitle: 'Aujourd\'hui',
                        color: Colors.green,
                      ),
                      const SizedBox(height: defaultPadding),
                      _buildStatCard(
                        icon: Icons.attach_money,
                        title: 'Revenus',
                        value: '0 FDJ',
                        subtitle: 'Ce mois',
                        color: Colors.purple,
                      ),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.people,
                          title: 'Chauffeurs',
                          value: '$totalDrivers',
                          subtitle: '$onlineDrivers en ligne',
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.restaurant,
                          title: 'Restaurants',
                          value: '$totalRestaurants',
                          subtitle: '$activeRestaurants actifs',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.local_taxi,
                          title: 'Courses',
                          value: '0',
                          subtitle: 'Aujourd\'hui',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: defaultPadding),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.attach_money,
                          title: 'Revenus',
                          value: '0 FDJ',
                          subtitle: 'Ce mois',
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  );
                }
              },
            );
          },
        );
      },
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
            // Liste vide pour l'instant
            Center(
              child: Padding(
                padding: const EdgeInsets.all(largePadding),
                child: Column(
                  children: [
                    Icon(
                      Icons.history,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
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
            ),
          ],
        ),
      ),
    );
  }
}
