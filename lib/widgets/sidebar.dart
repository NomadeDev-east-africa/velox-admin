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
          // Header — logo Velox
          Container(
            padding: const EdgeInsets.fromLTRB(
                largePadding, largePadding, largePadding, defaultPadding),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: veloxBlack,
                    borderRadius: BorderRadius.circular(defaultRadius),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.4)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    veloxLogoAsset,
                    width: 92,
                    height: 92,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'VELOX',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: primaryColor,
                  ),
                ),
                const Text(
                  'Admin Panel',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

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
        color: isSelected
            ? primaryColor.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
      child: Stack(
        children: [
          // Barre d'accent (overlay, ne rogne pas le contenu)
          if (isSelected)
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ListTile(
            leading: Icon(
              icon,
              color: isSelected ? primaryColor : Colors.white60,
            ),
            title: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isSelected ? primaryColor : Colors.white70,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
            onTap: () => onPageChanged(page),
          ),
        ],
      ),
    );
  }
}