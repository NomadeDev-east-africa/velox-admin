import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../constants.dart';
import '../../services/admin_push_notifications_service.dart';
import '../../widgets/sidebar.dart';
import '../drivers/drivers_list_screen.dart';
import '../restaurants/restaurants_list_screen.dart';
import '../categories/global_categories_screen.dart';
import '../livreur/livreurs_list_screen.dart';
import '../map/maps_screen.dart';
import '../notifications/broadcast_notification_screen.dart';
import '../banners/banners_screen.dart';
import '../taxi_pricing/taxi_pricing_screen.dart';
import '../orders/orders_screen.dart';
import '../promo/promo_codes_screen.dart';
import '../stats/statistics_screen.dart';
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
  StreamSubscription<RemoteMessage>? _pushMessagesSub;

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
  }

  @override
  void dispose() {
    _pushMessagesSub?.cancel();
    super.dispose();
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
        await AdminPushNotificationsService.instance.initialize();
        _pushMessagesSub = AdminPushNotificationsService
            .instance.foregroundMessages
            .listen(_onPushMessage);
      }
    } catch (e) {
      debugPrint('Erreur chargement admin: $e');
    }
  }

  void _onPushMessage(RemoteMessage message) {
    if (!mounted) return;
    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearMaterialBanners();
    messenger.showMaterialBanner(
      MaterialBanner(
        backgroundColor: primaryColor,
        dividerColor: veloxGreenDeep,
        padding: const EdgeInsets.symmetric(
          horizontal: largePadding,
          vertical: largePadding,
        ),
        leading: const Icon(Icons.notifications_active,
            color: veloxBlack, size: extraLargeIconSize),
        content: Text(
          '$title\n$body',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: veloxBlack,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => messenger.hideCurrentMaterialBanner(),
            style: TextButton.styleFrom(foregroundColor: veloxBlack),
            child: const Text('Fermer',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted) messenger.hideCurrentMaterialBanner();
    });
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
      case 'users':
        return const UsersScreen();
      case 'stats':
        return const StatisticsScreen();
      case 'notifications':
        return const BroadcastNotificationScreen();
      case 'promoCodes':
        return const PromoCodesScreen();
      case 'banners':
        return const BannersScreen();
      case 'taxiPricing':
        return const TaxiPricingScreen();
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
        return 'Suivi des commandes';
      case 'users':
        return 'Utilisateurs';
      case 'stats':
        return 'Statistiques';
      case 'notifications':
        return 'Notifications';
      case 'promoCodes':
        return 'Codes promo';
      case 'banners':
        return 'Bannières';
      case 'taxiPricing':
        return 'Tarifs VTC';
      default:
        return 'Velox Admin';
    }
  }
}
