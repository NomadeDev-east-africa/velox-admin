import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import '../../models/order_tracking.dart';
import '../../models/restaurant.dart';
import '../../models/opening_hours.dart';
import '../../services/restaurant_service.dart';
import '../../services/app_logger.dart';
import '../../widgets/opening_hours_editor.dart';
import '../../widgets/restaurant_order_count.dart';
import '../menu/menu_management_screen.dart';
import 'edit_restaurant_screen.dart';

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

  /// Filtre de la section "Historique des commandes" ci-dessous.
  String _historyPeriod = 'all';
  int _historyMonth = DateTime.now().month;
  int _historyYear = DateTime.now().year;

  static const _monthNames = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];

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
            tooltip: 'Modifier le restaurant',
            onPressed: _navigateToEdit,
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

                      // Historique des commandes (suivi de compte)
                      _buildOrdersHistorySection(),
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
                color: primaryColor.withValues(alpha: 0.1),
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
            value: '',
            valueWidget: RestaurantOrderCount(
              restaurantId: _restaurant.id,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
            value:
                '${NumberFormat('#,###').format(_restaurant.totalRevenue)} FDJ',
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
    Widget? valueWidget,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            valueWidget ??
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

  bool _inHistoryPeriod(DateTime? dt) {
    if (dt == null) return false;
    switch (_historyPeriod) {
      case 'day':
        final now = DateTime.now();
        return dt.year == now.year &&
            dt.month == now.month &&
            dt.day == now.day;
      case 'month':
        return dt.year == _historyYear && dt.month == _historyMonth;
      case 'year':
        return dt.year == _historyYear;
      default:
        return true;
    }
  }

  /// Historique réel des commandes de ce restaurant (suivi de compte) —
  /// distinct des compteurs `totalOrders`/`totalRevenue` du document
  /// Restaurant ci-dessus (maintenus ailleurs, potentiellement obsolètes) :
  /// ici on lit directement `orders` et on recalcule.
  ///
  /// Pas d'`orderBy` combiné au `where restaurantId` pour éviter d'exiger un
  /// index composite Firestore (non déployé dans ce repo) — tri fait côté
  /// client, même pattern que `RestaurantService.getMenuItems`.
  Widget _buildOrdersHistorySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique des commandes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('restaurantId', isEqualTo: _restaurant.id)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Erreur: ${snapshot.error}',
                      style: const TextStyle(color: errorColor));
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                        child: CircularProgressIndicator(color: primaryColor)),
                  );
                }

                final allOrders = snapshot.data!.docs
                    .map((d) => OrderTracking.fromMap(
                        d.id, d.data() as Map<String, dynamic>))
                    .toList();

                // Années réellement disponibles dans l'historique de ce
                // restaurant, pour ne proposer que des choix pertinents.
                final availableYears = allOrders
                    .map((o) => o.createdAt?.year)
                    .whereType<int>()
                    .toSet()
                    .toList()
                  ..sort((a, b) => b.compareTo(a));
                if (availableYears.isEmpty) {
                  availableYears.add(DateTime.now().year);
                }
                if (!availableYears.contains(_historyYear)) {
                  _historyYear = availableYears.first;
                }

                var orders = allOrders
                    .where((o) => _inHistoryPeriod(o.createdAt))
                    .toList()
                  ..sort((a, b) {
                    if (a.createdAt == null || b.createdAt == null) return 0;
                    return b.createdAt!.compareTo(a.createdAt!);
                  });

                final delivered =
                    orders.where((o) => o.phase == OrderPhase.delivered);
                final total = delivered.fold<num>(0, (sum, o) => sum + o.total);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _periodChip('Jour', 'day'),
                        _periodChip('Mois', 'month'),
                        _periodChip('Année', 'year'),
                        _periodChip('Tout', 'all'),
                        if (_historyPeriod == 'month') _monthDropdown(),
                        if (_historyPeriod == 'month' ||
                            _historyPeriod == 'year')
                          _yearDropdown(availableYears),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    Wrap(
                      spacing: defaultPadding,
                      runSpacing: 8,
                      children: [
                        _miniStat('Commandes', '${orders.length}'),
                        _miniStat('Livrées', '${delivered.length}'),
                        _miniStat('Total (livrées)',
                            '${NumberFormat('#,###').format(total)} FDJ'),
                      ],
                    ),
                    const Divider(height: 24),
                    if (orders.isEmpty)
                      Text('Aucune commande sur cette période.',
                          style: TextStyle(color: Colors.grey.shade600))
                    else
                      Column(
                        children: orders.take(200).map((o) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    o.createdAt != null
                                        ? DateFormat('dd/MM/yy HH:mm')
                                            .format(o.createdAt!)
                                        : '—',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                ),
                                Expanded(
                                  child: Text(o.customerName,
                                      overflow: TextOverflow.ellipsis),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: o.phaseColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: o.phaseColor),
                                  ),
                                  child: Text(
                                    o.phaseLabel,
                                    style: TextStyle(
                                        fontSize: 11, color: o.phaseColor),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    '${o.total} FDJ',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    if (orders.length > 200)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('+ ${orders.length - 200} autres',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String label, String value) {
    final selected = _historyPeriod == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _historyPeriod = value),
      selectedColor: primaryColor.withValues(alpha: 0.2),
      checkmarkColor: primaryColor,
      labelStyle: TextStyle(
        color: selected ? primaryColor : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _monthDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(defaultRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<int>(
        value: _historyMonth,
        underline: const SizedBox(),
        items: List.generate(12, (i) => i + 1)
            .map((m) =>
                DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _historyMonth = v);
        },
      ),
    );
  }

  Widget _yearDropdown(List<int> availableYears) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(defaultRadius),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButton<int>(
        value: _historyYear,
        underline: const SizedBox(),
        items: availableYears
            .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
            .toList(),
        onChanged: (v) {
          if (v != null) setState(() => _historyYear = v);
        },
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
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

                // Fermeture exceptionnelle (override prioritaire sur les horaires)
                ElevatedButton.icon(
                  onPressed:
                      _restaurant.isActive ? _toggleExceptionalClosure : null,
                  icon: Icon(
                    _restaurant.exceptionallyClosed
                        ? Icons.lock_open
                        : Icons.block,
                  ),
                  label: Text(
                    _restaurant.exceptionallyClosed
                        ? 'Annuler la fermeture exceptionnelle'
                        : 'Fermeture exceptionnelle',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _restaurant.exceptionallyClosed
                        ? successColor
                        : Colors.orange,
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
    } else if (_restaurant.exceptionallyClosed) {
      color = Colors.orange;
      label = 'Fermé (exceptionnel)';
    } else if (_restaurant.isOpenNowEffective) {
      color = successColor;
      label = 'Ouvert';
    } else {
      color = Colors.orange;
      label = 'Fermé';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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

  Future<void> _toggleExceptionalClosure() async {
    setState(() => _isLoading = true);

    try {
      final newValue = !_restaurant.exceptionallyClosed;
      await _restaurantService.setExceptionalClosure(_restaurant.id, newValue);

      setState(() {
        _restaurant = _restaurant.copyWith(exceptionallyClosed: newValue);
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue
                  ? 'Fermeture exceptionnelle activée'
                  : 'Fermeture exceptionnelle annulée',
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

  Future<void> _navigateToEdit() async {
    AppLogger.i('Navigation vers édition restaurant ${_restaurant.id}',
        tag: 'RESTO_DETAILS');
    final updated = await Navigator.push<Restaurant>(
      context,
      MaterialPageRoute(
        builder: (_) => EditRestaurantScreen(restaurant: _restaurant),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _restaurant = updated);
      AppLogger.i('Détails restaurant rafraîchis après édition',
          tag: 'RESTO_DETAILS');
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
