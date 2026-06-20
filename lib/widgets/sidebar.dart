import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';

class Sidebar extends StatelessWidget {
  final String currentPage;
  final Function(String) onPageChanged;

  const Sidebar({
    super.key,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: sidebarWidth,
      color: sidebarColor,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(largePadding),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_taxi,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nomade 253',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 1),

          const SizedBox(height: 16),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard,
                  title: 'Dashboard',
                  page: 'home',
                ),
                _buildMenuItem(
                  icon: Icons.map,
                  title: 'Carte',
                  page: 'map',
                ),
                _buildMenuItem(
                  icon: Icons.people,
                  title: 'Chauffeurs',
                  page: 'drivers',
                ),
                _buildMenuItem(
                  icon: Icons.restaurant,
                  title: 'Restaurants',
                  page: 'restaurants',
                ),
                _buildMenuItem(
                  icon: Icons.category,
                  title: 'Catégories',
                  page: 'categories',
                ),
                _buildMenuItem(
                  icon: Icons.delivery_dining,
                  title: 'Livreurs',
                  page: 'livreurs',
                ),
                _buildMenuItem(
                  icon: Icons.local_taxi,
                  title: 'Courses Taxi',
                  page: 'rides',
                ),
                _buildMenuItem(
                  icon: Icons.receipt_long,
                  title: 'Commandes',
                  page: 'orders',
                ),
                _buildMenuItem(
                  icon: Icons.timer_outlined,
                  title: 'Suivi livraisons',
                  page: 'deliveries',
                ),
                _buildMenuItem(
                  icon: Icons.people_outline,
                  title: 'Utilisateurs',
                  page: 'users',
                ),
                _buildMenuItem(
                  icon: Icons.analytics,
                  title: 'Statistiques',
                  page: 'stats',
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 1),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white70),
            title: const Text(
              'Déconnexion',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Déconnexion'),
                  content: const Text('Voulez-vous vraiment vous déconnecter ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: errorColor),
                      child: const Text('Déconnexion'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await FirebaseAuth.instance.signOut();
              }
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String page,
  }) {
    final isSelected = currentPage == page;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white70,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => onPageChanged(page),
      ),
    );
  }
}