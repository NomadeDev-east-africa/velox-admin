import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import '../../models/restaurant.dart';
import '../../models/opening_hours.dart';
import '../../services/restaurant_service.dart';
import '../../widgets/opening_hours_editor.dart';
import '../menu/menu_management_screen.dart';

class RestaurantDetailsScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailsScreen({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailsScreen> createState() =>
      _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState extends State<RestaurantDetailsScreen> {
  final RestaurantService _restaurantService = RestaurantService();
  late Restaurant _restaurant;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _restaurant = widget.restaurant;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_restaurant.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Naviguer vers écran d'édition
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Fonction édition à venir'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  padding: const EdgeInsets.all(largePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo + Info principales
                      _buildHeader(),
                      const SizedBox(height: largePadding),

                      // Statistiques
                      _buildStatsCards(),
                      const SizedBox(height: largePadding),

                      // Informations détaillées
                      _buildInfoSection(),
                      const SizedBox(height: largePadding),

                      // Horaires d'ouverture
                      _buildHoursSection(),
                      const SizedBox(height: largePadding),

                      // Actions
                      _buildActionsSection(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Row(
          children: [
            // Photo
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(defaultRadius),
              ),
              child: _restaurant.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(defaultRadius),
                      child: Image.network(
                        _restaurant.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.restaurant,
                          size: 48,
                          color: primaryColor,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.restaurant,
                      size: 48,
                      color: primaryColor,
                    ),
            ),
            const SizedBox(width: largePadding),

            // Infos principales
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _restaurant.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusBadge(),
                  const SizedBox(height: 12),
                  if (_restaurant.description != null)
                    Text(
                      _restaurant.description!,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.shopping_bag,
            label: 'Commandes',
            value: _restaurant.totalOrders.toString(),
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: defaultPadding),
        Expanded(
          child: _buildStatCard(
            icon: Icons.star,
            label: 'Note moyenne',
            value: _restaurant.rating.toStringAsFixed(1),
            color: Colors.amber,
          ),
        ),
        const SizedBox(width: defaultPadding),
        Expanded(
          child: _buildStatCard(
            icon: Icons.attach_money,
            label: 'Revenus totaux',
            value: '${NumberFormat('#,###').format(_restaurant.totalRevenue)} FDJ',
            color: Colors.green,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
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

  Widget _buildInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow(Icons.email, 'Email', _restaurant.email),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.phone, 'Téléphone', _restaurant.formattedPhone),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, 'Adresse', _restaurant.address),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Créé le',
              DateFormat('dd/MM/yyyy à HH:mm').format(_restaurant.createdAt),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.update,
              'Mis à jour le',
              DateFormat('dd/MM/yyyy à HH:mm').format(_restaurant.updatedAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHoursSection() {
    final hours = _restaurant.openingHours;
    final openNow = _restaurant.isOpenNowBySchedule;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Horaires d\'ouverture',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                if (openNow != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (openNow ? successColor : Colors.orange)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: openNow ? successColor : Colors.orange),
                    ),
                    child: Text(
                      openNow ? 'Ouvert maintenant' : 'Fermé maintenant',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: openNow ? successColor : Colors.orange.shade800,
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _editHours,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Modifier'),
                ),
              ],
            ),
            const Divider(height: 24),
            if (!hours.hasAnyHours)
              Text(
                'Aucun horaire défini.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              for (final dayKey in kDayDisplayOrder)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          kDayLabelsFr[dayKey] ?? dayKey,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          hours.rangesFor(dayKey).isEmpty
                              ? 'Fermé'
                              : hours
                                  .rangesFor(dayKey)
                                  .map((r) => r.label)
                                  .join('  •  '),
                          style: TextStyle(
                            color: hours.rangesFor(dayKey).isEmpty
                                ? Colors.grey.shade500
                                : textDarkColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _editHours() async {
    OpeningHours draft = _restaurant.openingHours;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(largePadding),
                child: Row(
                  children: [
                    const Text(
                      'Modifier les horaires',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(largePadding),
                  child: OpeningHoursEditor(
                    value: draft,
                    onChanged: (h) => draft = h,
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(defaultPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Enregistrer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true) return;

    setState(() => _isLoading = true);
    try {
      await _restaurantService.updateRestaurant(
        _restaurant.id,
        {'openingHours': draft.toMap()},
      );
      setState(() {
        _restaurant = _restaurant.copyWith(openingHours: draft);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Horaires mis à jour'),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
        );
      }
    }
  }

  Widget _buildActionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Toggle Actif/Inactif
                ElevatedButton.icon(
                  onPressed: _toggleActive,
                  icon: Icon(
                    _restaurant.isActive ? Icons.toggle_on : Icons.toggle_off,
                  ),
                  label: Text(
                    _restaurant.isActive
                        ? 'Désactiver le restaurant'
                        : 'Activer le restaurant',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _restaurant.isActive ? errorColor : successColor,
                    foregroundColor: Colors.white,
                  ),
                ),

                // Toggle Ouvert/Fermé
                ElevatedButton.icon(
                  onPressed: _restaurant.isActive ? _toggleOpen : null,
                  icon: Icon(
                    _restaurant.isOpen ? Icons.store : Icons.store_mall_directory,
                  ),
                  label: Text(
                    _restaurant.isOpen
                        ? 'Fermer le restaurant'
                        : 'Ouvrir le restaurant',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _restaurant.isOpen ? Colors.orange : Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),

                // Voir le menu
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MenuManagementScreen(
                          restaurantId: _restaurant.id,
                          restaurantName: _restaurant.name,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Gérer le menu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String label;

    if (!_restaurant.isActive) {
      color = errorColor;
      label = 'Inactif';
    } else if (!_restaurant.isOpen) {
      color = Colors.orange;
      label = 'Fermé';
    } else {
      color = successColor;
      label = 'Actif et Ouvert';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

  Future<void> _toggleActive() async {
    setState(() => _isLoading = true);

    try {
      await _restaurantService.toggleActive(
        _restaurant.id,
        !_restaurant.isActive,
      );

      setState(() {
        _restaurant = _restaurant.copyWith(isActive: !_restaurant.isActive);
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _restaurant.isActive
                  ? 'Restaurant activé'
                  : 'Restaurant désactivé',
            ),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  Future<void> _toggleOpen() async {
    setState(() => _isLoading = true);

    try {
      await _restaurantService.toggleOpen(
        _restaurant.id,
        !_restaurant.isOpen,
      );

      setState(() {
        _restaurant = _restaurant.copyWith(isOpen: !_restaurant.isOpen);
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _restaurant.isOpen
                  ? 'Restaurant ouvert'
                  : 'Restaurant fermé',
            ),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le restaurant'),
        content: Text(
          'Voulez-vous vraiment supprimer "${_restaurant.name}" ?\n\n'
          'Cette action est irréversible et supprimera également tous les items du menu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteRestaurant();
    }
  }

  Future<void> _deleteRestaurant() async {
    setState(() => _isLoading = true);

    try {
      await _restaurantService.deleteRestaurant(_restaurant.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant supprimé'),
          backgroundColor: successColor,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
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
}
