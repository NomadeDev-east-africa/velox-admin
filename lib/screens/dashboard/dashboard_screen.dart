import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';
import '../../widgets/sidebar.dart';
import '../drivers/drivers_list_screen.dart';
import '../restaurants/restaurants_list_screen.dart';
import '../categories/global_categories_screen.dart';
import '../livreur/livreurs_list_screen.dart';
import '../map/maps_screen.dart';
import '../orders/orders_screen.dart';
import '../deliveries/delivery_tracking_screen.dart';
import '../taxi/taxi_rides_screen.dart';
import '../users/users_screen.dart';
import 'dashboard_home.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String _currentPage = 'home';
  String _adminName = 'Admin';

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
  }

  Future<void> _loadAdminInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final adminDoc = await FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .get();

      if (adminDoc.exists && mounted) {
        setState(() {
          _adminName = adminDoc.data()?['name'] ?? 'Admin';
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement admin: $e');
    }
  }

  void _changePage(String page) {
    setState(() => _currentPage = page);
    // Fermer drawer sur mobile après sélection
    if (isMobile(context)) {
      Navigator.pop(context);
    }
  }

  Widget _getCurrentPage() {
    switch (_currentPage) {
      case 'home':
        return const DashboardHome();
      case 'map': // CAS AJOUTÉ
        return const MapsScreen();
      case 'drivers':
        return const DriversListScreen();
      case 'restaurants':
        return const RestaurantsListScreen();
      case 'categories':
        return const GlobalCategoriesScreen();
      case 'livreurs':
        return const LivreursListScreen();
      case 'rides':
        return const TaxiRidesScreen();
      case 'orders':
        return const OrdersScreen();
      case 'deliveries':
        return const DeliveryTrackingScreen();
      case 'users':
        return const UsersScreen();
      case 'stats':
        return const Center(child: Text('Statistiques (À venir)'));
      default:
        return const DashboardHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopView = isDesktop(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: isDesktopView
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
        title: Text(_getPageTitle()),
        actions: [
          // Notifications
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
          // Profile
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.person,
                    size: 20,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                if (!isMobile(context))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _adminName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Administrateur',
                        style: TextStyle(
                          fontSize: 12,
                          color: textLightColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      drawer: isDesktopView
          ? null
          : Drawer(
              child: Sidebar(
                currentPage: _currentPage,
                onPageChanged: _changePage,
              ),
            ),
      body: Row(
        children: [
          // Sidebar permanent sur desktop
          if (isDesktopView)
            Sidebar(
              currentPage: _currentPage,
              onPageChanged: _changePage,
            ),
          
          // Contenu principal
          Expanded(
            child: Container(
              color: backgroundColor,
              child: _getCurrentPage(),
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_currentPage) {
      case 'home':
        return 'Dashboard';
      case 'map': // TITRE AJOUTÉ
        return 'Carte Interactive';
      case 'drivers':
        return 'Chauffeurs';
      case 'restaurants':
        return 'Restaurants';
      case 'categories':
        return 'Catégories de menu';
      case 'livreurs':
        return 'Livreurs';
      case 'rides':
        return 'Courses Taxi';
      case 'orders':
        return 'Commandes';
      case 'deliveries':
        return 'Suivi livraisons';
      case 'users':
        return 'Utilisateurs';
      case 'stats':
        return 'Statistiques';
      default:
        return 'Velox Admin';
    }
  }
}