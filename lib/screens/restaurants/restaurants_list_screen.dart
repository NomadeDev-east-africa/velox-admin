import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/restaurant.dart';
import '../../services/restaurant_service.dart';
import 'add_restaurant_screen.dart';
import 'restaurant_details_screen.dart';
import '../menu/menu_management_screen.dart';

class RestaurantsListScreen extends StatefulWidget {
  const RestaurantsListScreen({super.key});

  @override
  State<RestaurantsListScreen> createState() => _RestaurantsListScreenState();
}

class _RestaurantsListScreenState extends State<RestaurantsListScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  final TextEditingController _searchController = TextEditingController();

  String _filterStatus = 'all'; // all, active, inactive
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header avec actions
          _buildHeader(),

          // Contenu
          Expanded(
            child: StreamBuilder<List<Restaurant>>(
              stream: _getFilteredStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Erreur: ${snapshot.error}'),
                  );
                }

                final restaurants = snapshot.data ?? [];

                // Filtrer par recherche
                final filteredRestaurants = _searchQuery.isEmpty
                    ? restaurants
                    : restaurants
                        .where((r) =>
                            r.name
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()) ||
                            r.email
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()))
                        .toList();

                if (filteredRestaurants.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildRestaurantsList(filteredRestaurants);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(largePadding),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre + Bouton Ajouter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Restaurants',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textDarkColor,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _navigateToAddRestaurant,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter Restaurant'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),

          const SizedBox(height: largePadding),

          // Barre de recherche + Filtres
          Row(
            children: [
              // Recherche
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par nom ou email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(defaultRadius),
                    ),
                    filled: true,
                    fillColor: backgroundColor,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              const SizedBox(width: defaultPadding),

              // Filtre statut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(defaultRadius),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButton<String>(
                  value: _filterStatus,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tous')),
                    DropdownMenuItem(value: 'active', child: Text('Actifs')),
                    DropdownMenuItem(
                        value: 'inactive', child: Text('Inactifs')),
                  ],
                  onChanged: (value) {
                    setState(() => _filterStatus = value!);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantsList(List<Restaurant> restaurants) {
    if (isMobile(context)) {
      return ListView.builder(
        padding: const EdgeInsets.all(defaultPadding),
        itemCount: restaurants.length,
        itemBuilder: (context, index) =>
            _buildRestaurantCard(restaurants[index]),
      );
    } else {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(largePadding),
        child: _buildDataTable(restaurants),
      );
    }
  }

  Widget _buildRestaurantCard(Restaurant restaurant) {
    return Card(
      margin: const EdgeInsets.only(bottom: defaultPadding),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: primaryColor.withValues(alpha:0.1),
          child: restaurant.imageUrl != null
              ? ClipOval(
                  child: Image.network(
                    restaurant.imageUrl!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.restaurant, color: primaryColor),
                  ),
                )
              : const Icon(Icons.restaurant, color: primaryColor),
        ),
        title: Text(
          restaurant.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${restaurant.email}\n${restaurant.formattedPhone}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusBadge(restaurant),
            IconButton(
              icon: const Icon(Icons.restaurant_menu, color: primaryColor),
              tooltip: 'Gérer le menu',
              onPressed: () => _navigateToMenu(restaurant),
            ),
          ],
        ),
        onTap: () => _navigateToDetails(restaurant),
      ),
    );
  }

  Widget _buildDataTable(List<Restaurant> restaurants) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Nom')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Téléphone')),
            DataColumn(label: Text('Adresse')),
            DataColumn(label: Text('Statut')),
            DataColumn(label: Text('Commandes')),
            DataColumn(label: Text('Note')),
            DataColumn(label: Text('Actions')),
          ],
          rows: restaurants
              .map(
                (restaurant) => DataRow(
                  onSelectChanged: (_) => _navigateToDetails(restaurant),
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: primaryColor.withValues(alpha:0.1),
                            child: restaurant.imageUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      restaurant.imageUrl!,
                                      width: 32,
                                      height: 32,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.restaurant,
                                        size: 16,
                                        color: primaryColor,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.restaurant,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            restaurant.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    DataCell(Text(restaurant.email)),
                    DataCell(Text(restaurant.formattedPhone)),
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          restaurant.address,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(_buildStatusBadge(restaurant)),
                    DataCell(Text(restaurant.totalOrders.toString())),
                    DataCell(
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(restaurant.rating.toStringAsFixed(1)),
                        ],
                      ),
                    ),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility),
                            onPressed: () => _navigateToDetails(restaurant),
                            tooltip: 'Voir détails',
                          ),
                          IconButton(
                            icon: const Icon(Icons.restaurant_menu,
                                color: primaryColor),
                            onPressed: () => _navigateToMenu(restaurant),
                            tooltip: 'Gérer le menu',
                          ),
                          IconButton(
                            icon: Icon(
                              restaurant.isActive
                                  ? Icons.toggle_on
                                  : Icons.toggle_off,
                              color: restaurant.isActive
                                  ? successColor
                                  : Colors.grey,
                            ),
                            onPressed: () => _toggleActive(restaurant),
                            tooltip: restaurant.isActive
                                ? 'Désactiver'
                                : 'Activer',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Restaurant restaurant) {
    Color color;
    String label;

    if (!restaurant.isActive) {
      color = errorColor;
      label = 'Inactif';
    } else if (!restaurant.isOpen) {
      color = Colors.orange;
      label = 'Fermé';
    } else {
      color = successColor;
      label = 'Actif';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucun restaurant trouvé',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premier restaurant',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddRestaurant,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter Restaurant'),
          ),
        ],
      ),
    );
  }

  Stream<List<Restaurant>> _getFilteredStream() {
    switch (_filterStatus) {
      case 'active':
        return _restaurantService.getRestaurantsByStatus(isActive: true);
      case 'inactive':
        return _restaurantService.getRestaurantsByStatus(isActive: false);
      default:
        return _restaurantService.getRestaurants();
    }
  }

  Future<void> _toggleActive(Restaurant restaurant) async {
    try {
      await _restaurantService.toggleActive(restaurant.id, !restaurant.isActive);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              restaurant.isActive
                  ? 'Restaurant désactivé'
                  : 'Restaurant activé',
            ),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  void _navigateToAddRestaurant() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddRestaurantScreen(),
      ),
    );
  }

  void _navigateToDetails(Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantDetailsScreen(restaurant: restaurant),
      ),
    );
  }

  void _navigateToMenu(Restaurant restaurant) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MenuManagementScreen(
          restaurantId: restaurant.id,
          restaurantName: restaurant.name,
        ),
      ),
    );
  }
}
