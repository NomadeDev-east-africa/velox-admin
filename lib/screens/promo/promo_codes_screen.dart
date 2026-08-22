import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/promo_code.dart';
import '../../services/promo_code_service.dart';
import 'add_edit_promo_code_screen.dart';

class PromoCodesScreen extends StatefulWidget {
  const PromoCodesScreen({super.key});

  @override
  State<PromoCodesScreen> createState() => _PromoCodesScreenState();
}

class _PromoCodesScreenState extends State<PromoCodesScreen> {
  final _promoCodeService = PromoCodeService();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(defaultPadding),
          color: cardColor,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un code promo...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: backgroundColor,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),
              const SizedBox(width: defaultPadding),
              ElevatedButton.icon(
                onPressed: _navigateToAdd,
                icon: const Icon(Icons.add),
                label: Text(isMobile(context) ? 'Ajouter' : 'Nouveau code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<PromoCode>>(
            stream: _promoCodeService.getPromoCodes(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              var promoCodes = snapshot.data!;
              if (_searchQuery.isNotEmpty) {
                promoCodes = promoCodes
                    .where((p) =>
                        p.code.toLowerCase().contains(_searchQuery) ||
                        (p.restaurantName ?? '')
                            .toLowerCase()
                            .contains(_searchQuery))
                    .toList();
              }

              if (promoCodes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sell_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Aucun code promo créé'
                            : 'Aucun résultat',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return isMobile(context)
                  ? _buildMobileList(promoCodes)
                  : _buildDesktopTable(promoCodes);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<PromoCode> promoCodes) {
    return ListView.builder(
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: promoCodes.length,
      itemBuilder: (context, index) {
        final promo = promoCodes[index];
        return Card(
          margin: const EdgeInsets.only(bottom: defaultPadding),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor.withValues(alpha: 0.15),
              child: const Icon(Icons.sell_outlined, color: primaryColor),
            ),
            title: Text(promo.code,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${promo.discountLabel} • ${promo.isGlobal ? 'Tous restaurants' : promo.restaurantName ?? 'Restaurant'}'),
                Row(
                  children: [
                    _statusBadge(promo),
                    const SizedBox(width: 8),
                    Text(
                        '${promo.usageCount} utilisation(s) • ${Formatters.formatCurrency(promo.totalDiscountGiven.toDouble())} remisés',
                        style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Modifier'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(promo.active ? Icons.block : Icons.check_circle,
                        size: 18,
                        color: promo.active ? errorColor : successColor),
                    const SizedBox(width: 8),
                    Text(promo.active ? 'Désactiver' : 'Activer'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, size: 18, color: errorColor),
                    SizedBox(width: 8),
                    Text('Supprimer', style: TextStyle(color: errorColor)),
                  ]),
                ),
              ],
              onSelected: (value) => _handleAction(value, promo),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<PromoCode> promoCodes) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 24,
            columns: const [
              DataColumn(label: Text('Actions')),
              DataColumn(label: Text('Statut')),
              DataColumn(label: Text('Code')),
              DataColumn(label: Text('Réduction')),
              DataColumn(label: Text('Portée')),
              DataColumn(label: Text('Expiration')),
              DataColumn(label: Text('Utilisations')),
              DataColumn(label: Text('Total remisé')),
            ],
            rows: promoCodes.map((promo) {
              return DataRow(cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit,
                            size: 20, color: primaryColor),
                        onPressed: () => _navigateToEdit(promo),
                        tooltip: 'Modifier',
                      ),
                      IconButton(
                        icon: Icon(
                            promo.active ? Icons.block : Icons.check_circle,
                            size: 20,
                            color: promo.active ? errorColor : successColor),
                        onPressed: () => _confirmToggleActive(promo),
                        tooltip: promo.active ? 'Désactiver' : 'Activer',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            size: 20, color: errorColor),
                        onPressed: () => _confirmDelete(promo),
                        tooltip: 'Supprimer',
                      ),
                    ],
                  ),
                ),
                DataCell(_statusBadge(promo)),
                DataCell(Text(promo.code,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(promo.discountLabel)),
                DataCell(Text(
                    promo.isGlobal ? 'Tous restaurants' : (promo.restaurantName ?? 'Restaurant')),
                ),
                DataCell(Text(promo.expiresAt != null
                    ? Formatters.formatDate(promo.expiresAt!)
                    : 'Sans expiration')),
                DataCell(Text('${promo.usageCount}')),
                DataCell(Text(
                    Formatters.formatCurrency(promo.totalDiscountGiven.toDouble()))),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(PromoCode promo) {
    if (promo.isExpired) {
      return _badge('Expiré', textLightColor);
    }
    if (!promo.active) {
      return _badge('Inactif', errorColor);
    }
    return _badge('Actif', successColor);
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _handleAction(dynamic value, PromoCode promo) {
    switch (value) {
      case 'edit':
        _navigateToEdit(promo);
        break;
      case 'toggle':
        _confirmToggleActive(promo);
        break;
      case 'delete':
        _confirmDelete(promo);
        break;
    }
  }

  void _navigateToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditPromoCodeScreen()),
    ).then((success) {
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code promo créé'),
            backgroundColor: successColor,
          ),
        );
      }
    });
  }

  void _navigateToEdit(PromoCode promo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditPromoCodeScreen(existing: promo),
      ),
    ).then((success) {
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Code promo modifié'),
            backgroundColor: successColor,
          ),
        );
      }
    });
  }

  Future<void> _confirmToggleActive(PromoCode promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(promo.active ? 'Désactiver le code' : 'Activer le code'),
        content: Text(promo.active
            ? 'Le code ${promo.code} ne pourra plus être utilisé. Continuer ?'
            : 'Réactiver le code ${promo.code} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: promo.active ? errorColor : successColor),
            child: Text(promo.active ? 'Désactiver' : 'Activer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _promoCodeService.toggleActive(promo.code, !promo.active);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(PromoCode promo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le code promo'),
        content: Text(
            'Voulez-vous vraiment supprimer ${promo.code} ?\n\nCette action est irréversible.'),
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
      try {
        await _promoCodeService.deletePromoCode(promo.code);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Code promo supprimé'),
              backgroundColor: successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
          );
        }
      }
    }
  }
}
