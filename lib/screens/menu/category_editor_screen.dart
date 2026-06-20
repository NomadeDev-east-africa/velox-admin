import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/menu_category.dart';
import '../../models/option_group.dart';
import '../../services/menu_management_service.dart';
import '../../widgets/option_groups_editor.dart';
import '../../widgets/library_image_picker.dart';

/// Création / édition d'une catégorie : nom + image (bibliothèque) +
/// suppléments par défaut hérités par les plats de la catégorie.
class CategoryEditorScreen extends StatefulWidget {
  final String restaurantId;
  final MenuCategory? category; // null = création

  const CategoryEditorScreen({
    super.key,
    required this.restaurantId,
    this.category,
  });

  @override
  State<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<CategoryEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = MenuManagementService();
  final _nameController = TextEditingController();

  String? _imageUrl;
  List<OptionGroup> _defaultGroups = [];
  bool _isSaving = false;

  bool get _isEdit => widget.category != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    if (cat != null) {
      _nameController.text = cat.name;
      _imageUrl = cat.imageUrl;
      _defaultGroups = cat.defaultOptionGroups;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final url = await pickLibraryImage(context);
    if (url != null) setState(() => _imageUrl = url);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      if (_isEdit) {
        await _service.updateCategory(widget.category!.copyWith(
          name: _nameController.text.trim(),
          imageUrl: _imageUrl,
          defaultOptionGroups: _defaultGroups,
        ));
      } else {
        await _service.createCategory(MenuCategory(
          id: '',
          restaurantId: widget.restaurantId,
          name: _nameController.text.trim(),
          imageUrl: _imageUrl,
          defaultOptionGroups: _defaultGroups,
        ));
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier la catégorie' : 'Nouvelle catégorie'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 700),
            padding: const EdgeInsets.all(largePadding),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(largePadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius:
                                    BorderRadius.circular(defaultRadius),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: (_imageUrl != null && _imageUrl!.isNotEmpty)
                                  ? Image.network(
                                      _imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                          Icons.category,
                                          size: 48,
                                          color: Colors.grey),
                                    )
                                  : const Icon(Icons.category,
                                      size: 48, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: Text(_imageUrl == null
                                  ? 'Choisir une image'
                                  : 'Changer l\'image'),
                            ),
                            Text(
                              'Cette image sera appliquée automatiquement aux plats de la catégorie.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: largePadding),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la catégorie *',
                          hintText: 'Ex: Burgers, Tacos, Boissons…',
                          prefixIcon: Icon(Icons.label),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Le nom est requis'
                            : null,
                      ),
                      const Divider(height: largePadding * 1.5),
                      Text(
                        'Suppléments par défaut (hérités par les plats)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ex: tous les Tacos partagent les mêmes suppléments. '
                        'Modifiable plat par plat ensuite.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                      OptionGroupsEditor(
                        groups: _defaultGroups,
                        onChanged: (g) => _defaultGroups = g,
                      ),
                      const SizedBox(height: largePadding),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isSaving
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.check),
                            label: Text(_isEdit ? 'Enregistrer' : 'Créer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
