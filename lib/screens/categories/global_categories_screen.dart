import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants.dart';
import '../../models/global_category.dart';
import '../../services/menu_management_service.dart';
import '../../widgets/library_image_picker.dart';

/// Page **globale** de gestion des catégories de menu (partagées par tous les
/// restaurants). Chaque catégorie = un nom + une image (fallback gris si vide).
/// Les plats héritent uniquement de l'image de leur catégorie.
class GlobalCategoriesScreen extends StatefulWidget {
  const GlobalCategoriesScreen({super.key});

  @override
  State<GlobalCategoriesScreen> createState() => _GlobalCategoriesScreenState();
}

class _GlobalCategoriesScreenState extends State<GlobalCategoriesScreen> {
  final _service = MenuManagementService();
  final _picker = ImagePicker();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildToolbar(),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<List<GlobalCategory>>(
                stream: _service.streamGlobalCategories(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: primaryColor));
                  }
                  final cats = snap.data ?? const <GlobalCategory>[];
                  if (cats.isEmpty) return _emptyState();
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        largePadding, largePadding, largePadding, 90),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisExtent: 210,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: cats.length,
                    itemBuilder: (_, i) => _categoryCard(cats[i]),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            backgroundColor: primaryColor,
            onPressed: _busy ? null : _addCategory,
            icon: const Icon(Icons.add),
            label: const Text('Catégorie'),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Catégories partagées par tous les restaurants. '
              'Liez une image à chaque catégorie : les plats en hériteront automatiquement.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _seedFromMenuItems,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_for_offline_outlined),
            label: const Text('Récupérer les catégories existantes'),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(GlobalCategory cat) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _editCategory(cat),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cat.hasImage
                      ? Image.network(
                          cat.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _greyFallback(),
                        )
                      : _greyFallback(),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      icon: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white70,
                        child: Icon(Icons.more_vert, size: 18, color: Colors.black87),
                      ),
                      onSelected: (v) {
                        if (v == 'edit') _editCategory(cat);
                        if (v == 'image') _changeImage(cat);
                        if (v == 'delete') _deleteCategory(cat);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Renommer')),
                        PopupMenuItem(value: 'image', child: Text('Changer l\'image')),
                        PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cat.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!cat.hasImage)
                    Tooltip(
                      message: 'Aucune image',
                      child: Icon(Icons.image_not_supported_outlined,
                          size: 18, color: Colors.orange.shade400),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _greyFallback() => Container(
        color: Colors.grey.shade200,
        child: Icon(Icons.category, size: 48, color: Colors.grey.shade400),
      );

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('Aucune catégorie',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Ajoutez une catégorie, ou récupérez celles déjà utilisées dans les menus existants.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ACTIONS ====================

  Future<void> _addCategory() async {
    final name = await _promptName(title: 'Nouvelle catégorie');
    if (name == null || name.trim().isEmpty) return;
    final created = await _service.ensureGlobalCategories({name.trim(): null});
    if (mounted && created == 0) {
      _snack('La catégorie « $name » existe déjà.', Colors.orange);
    }
  }

  Future<void> _editCategory(GlobalCategory cat) async {
    final name = await _promptName(title: 'Renommer', initial: cat.name);
    if (name == null || name.trim().isEmpty || name.trim() == cat.name) return;
    await _service.updateGlobalCategory(cat.copyWith(name: name.trim()));
  }

  Future<void> _changeImage(GlobalCategory cat) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload),
              title: const Text('Uploader une image'),
              onTap: () => Navigator.pop(context, 'upload'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choisir dans la bibliothèque'),
              onTap: () => Navigator.pop(context, 'library'),
            ),
            if (cat.hasImage)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Retirer l\'image'),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'remove') {
      await _service.updateGlobalCategory(
          cat.copyWith(imageUrl: null, storagePath: null));
      return;
    }
    if (choice == 'library') {
      final url = await pickLibraryImage(context);
      if (url != null) {
        await _service.updateGlobalCategory(
            cat.copyWith(imageUrl: url, storagePath: null));
      }
      return;
    }
    // upload
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 75,
    );
    if (file == null) return;
    setState(() => _busy = true);
    try {
      final Uint8List bytes = await file.readAsBytes();
      final (url, path) =
          await _service.uploadCategoryImage(name: cat.name, bytes: bytes);
      await _service.updateGlobalCategory(
          cat.copyWith(imageUrl: url, storagePath: path));
    } catch (e) {
      _snack('Erreur upload: $e', errorColor);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCategory(GlobalCategory cat) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la catégorie'),
        content: Text(
            'Supprimer « ${cat.name} » ?\nLes plats existants ne sont pas supprimés (ils gardent leur image actuelle).'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok == true) await _service.deleteGlobalCategory(cat);
  }

  Future<void> _seedFromMenuItems() async {
    setState(() => _busy = true);
    try {
      final added = await _service.seedGlobalCategoriesFromMenuItems();
      _snack(
        added == 0
            ? 'Aucune nouvelle catégorie à récupérer.'
            : '$added catégorie(s) récupérée(s).',
        successColor,
      );
    } catch (e) {
      _snack('Erreur: $e', errorColor);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptName({required String title, String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Nom de la catégorie',
            hintText: 'Ex: Burgers, Pizzas, Tacos…',
          ),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }
}
