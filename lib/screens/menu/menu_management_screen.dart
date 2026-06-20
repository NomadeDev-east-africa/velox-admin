import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/menu_item.dart';
import '../../models/global_category.dart';
import '../../services/menu_management_service.dart';
import 'menu_item_editor_screen.dart';
import 'import_menu_screen.dart';

/// Gestion du menu d'un restaurant : liste des plats (groupés par catégorie),
/// ajout d'un plat, et import d'un menu complet via fichier texte.
///
/// Les **catégories sont globales** (gérées dans la page « Catégories » du
/// menu latéral) ; ici on ne fait qu'y rattacher les plats — chaque plat hérite
/// de l'image de sa catégorie.
class MenuManagementScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const MenuManagementScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final _service = MenuManagementService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu — ${widget.restaurantName}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _openImport,
                icon: const Icon(Icons.note_add, size: 20),
                label: const Text('Ajouter un menu entier'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildItemsTab(),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'addItem',
        backgroundColor: primaryColor,
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Plat'),
      ),
    );
  }

  Widget _buildItemsTab() {
    return StreamBuilder<List<GlobalCategory>>(
      stream: _service.streamGlobalCategories(),
      builder: (context, catSnap) {
        final categories = catSnap.data ?? const <GlobalCategory>[];
        return StreamBuilder<List<MenuItem>>(
          stream: _service.streamMenuItems(widget.restaurantId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: primaryColor));
            }
            final items = snap.data ?? const <MenuItem>[];
            if (items.isEmpty) {
              return _emptyState(
                icon: Icons.fastfood,
                title: 'Aucun plat',
                subtitle:
                    'Ajoutez un plat, ou importez un menu complet depuis un fichier texte.',
                action: ElevatedButton.icon(
                  onPressed: _openImport,
                  icon: const Icon(Icons.note_add),
                  label: const Text('Ajouter un menu entier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              );
            }
            final byCat = <String, List<MenuItem>>{};
            for (final it in items) {
              byCat.putIfAbsent(it.category, () => []).add(it);
            }
            final catNames = byCat.keys.toList()..sort();
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  defaultPadding, defaultPadding, defaultPadding, 90),
              children: [
                for (final cat in catNames) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '$cat  (${byCat[cat]!.length})',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...byCat[cat]!.map((it) => _itemTile(it, categories)),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _itemTile(MenuItem item, List<GlobalCategory> categories) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(smallRadius),
          child: SizedBox(
            width: 52,
            height: 52,
            child: (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ? Image.network(
                    item.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.fastfood)),
                  )
                : Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.fastfood)),
          ),
        ),
        title: Text(item.name),
        subtitle: Text(
          '${item.price.toStringAsFixed(0)} FDJ'
          '${item.optionGroups.isNotEmpty ? ' · ${item.optionGroups.length} option(s)' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: item.isAvailable,
              activeThumbColor: successColor,
              onChanged: (v) => _service.toggleAvailability(item.id, v),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  _editItem(item, categories);
                } else if (v == 'delete') {
                  _deleteItem(item);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _addItem() async {
    final categories = await _service.getGlobalCategories();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemEditorScreen(
          restaurantId: widget.restaurantId,
          categories: categories,
        ),
      ),
    );
  }

  Future<void> _editItem(MenuItem item, List<GlobalCategory> categories) async {
    final cats =
        categories.isNotEmpty ? categories : await _service.getGlobalCategories();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuItemEditorScreen(
          restaurantId: widget.restaurantId,
          categories: cats,
          item: item,
        ),
      ),
    );
  }

  Future<void> _deleteItem(MenuItem item) async {
    final ok = await _confirm('Supprimer « ${item.name} » ?');
    if (ok) await _service.deleteMenuItem(item.id);
  }

  Future<void> _openImport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImportMenuScreen(
          restaurantId: widget.restaurantId,
          restaurantName: widget.restaurantName,
        ),
      ),
    );
  }

  // ==================== HELPERS ====================

  Future<bool> _confirm(String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text(message),
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
    return res ?? false;
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            if (action != null) ...[
              const SizedBox(height: 20),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
