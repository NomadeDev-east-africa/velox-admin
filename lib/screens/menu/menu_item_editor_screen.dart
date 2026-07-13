import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants.dart';
import '../../models/menu_item.dart';
import '../../models/global_category.dart';
import '../../models/option_group.dart';
import '../../services/menu_management_service.dart';
import '../../widgets/option_groups_editor.dart';
import '../../widgets/library_image_picker.dart';

/// Création / édition d'un plat (menuItem).
///
/// - L'image est par défaut celle de la **catégorie globale** (seul élément
///   hérité ; le prix, les suppléments et la taille restent propres au plat).
/// - On peut la remplacer par une image de la bibliothèque ou une photo uploadée.
class MenuItemEditorScreen extends StatefulWidget {
  final String restaurantId;
  final List<GlobalCategory> categories;
  final MenuItem? item; // null = création

  const MenuItemEditorScreen({
    super.key,
    required this.restaurantId,
    required this.categories,
    this.item,
  });

  @override
  State<MenuItemEditorScreen> createState() => _MenuItemEditorScreenState();
}

class _MenuItemEditorScreenState extends State<MenuItemEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = MenuManagementService();
  final _picker = ImagePicker();

  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _prepController = TextEditingController(text: '20');

  String? _category;
  bool _isAvailable = true;
  List<OptionGroup> _optionGroups = [];

  String? _imageUrl; // image effective (catégorie, bibliothèque ou upload)
  Uint8List? _newImageBytes; // photo à uploader si choisie
  bool _imageOverridden = false; // l'utilisateur a forcé une image
  bool _isSaving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _nameController.text = item.name;
      _descController.text = item.description;
      _priceController.text = item.price.toStringAsFixed(0);
      _prepController.text = item.preparationTime.toString();
      _category = item.category;
      _isAvailable = item.isAvailable;
      _optionGroups = item.optionGroups;
      _imageUrl = item.imageUrl;
      _imageOverridden = item.imageUrl != null;
    } else if (widget.categories.isNotEmpty) {
      _applyCategory(widget.categories.first);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _prepController.dispose();
    super.dispose();
  }

  GlobalCategory? get _selectedCategory {
    final matches = widget.categories.where((c) => c.name == _category);
    return matches.isEmpty ? null : matches.first;
  }

  void _applyCategory(GlobalCategory cat) {
    setState(() {
      _category = cat.name;
      // Seule l'image est héritée de la catégorie (si non forcée par l'utilisateur).
      if (!_imageOverridden) {
        _imageUrl = cat.imageUrl;
        _newImageBytes = null;
      }
    });
  }

  Future<void> _pickFromLibrary() async {
    final url = await pickLibraryImage(context);
    if (url != null) {
      setState(() {
        _imageUrl = url;
        _newImageBytes = null;
        _imageOverridden = true;
      });
    }
  }

  Future<void> _uploadPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _newImageBytes = bytes;
      _imageOverridden = true;
    });
  }

  void _resetToCategoryImage() {
    setState(() {
      _imageOverridden = false;
      _newImageBytes = null;
      _imageUrl = _selectedCategory?.imageUrl;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      _snack('Choisissez une catégorie', errorColor);
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Upload de la photo si une nouvelle a été choisie
      String? finalImageUrl = _imageUrl;
      if (_newImageBytes != null) {
        finalImageUrl = await _service.uploadMenuItemImage(
          restaurantId: widget.restaurantId,
          bytes: _newImageBytes!,
        );
      }
      // Sinon, fallback sur l'image de la catégorie
      finalImageUrl ??= _selectedCategory?.imageUrl;

      final price = double.tryParse(_priceController.text.trim()) ?? 0;
      final prep = int.tryParse(_prepController.text.trim()) ?? 20;

      if (_isEdit) {
        await _service.updateMenuItem(widget.item!.id, {
          'name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'price': price,
          'imageUrl': finalImageUrl,
          'category': _category,
          'isAvailable': _isAvailable,
          'preparationTime': prep,
          'optionGroups': OptionGroup.listToRaw(_optionGroups),
        });
      } else {
        final now = DateTime.now();
        await _service.createMenuItem(MenuItem(
          id: '',
          restaurantId: widget.restaurantId,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          price: price,
          imageUrl: finalImageUrl,
          category: _category!,
          isAvailable: _isAvailable,
          preparationTime: prep,
          optionGroups: _optionGroups,
          createdAt: now,
          updatedAt: now,
        ));
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _snack('Erreur: $e', errorColor);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le plat' : 'Nouveau plat'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(largePadding),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(largePadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildImageSection(),
                      const SizedBox(height: largePadding),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du plat *',
                          prefixIcon: Icon(Icons.fastfood),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Le nom est requis'
                            : null,
                      ),
                      const SizedBox(height: defaultPadding),
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          prefixIcon: Icon(Icons.description),
                        ),
                      ),
                      const SizedBox(height: defaultPadding),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Prix de base *',
                                suffixText: 'FDJ',
                                prefixIcon: Icon(Icons.attach_money),
                              ),
                              validator: (v) {
                                final p = double.tryParse(v?.trim() ?? '');
                                if (p == null || p <= 0) return 'Prix invalide';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            child: TextFormField(
                              controller: _prepController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Préparation',
                                suffixText: 'min',
                                prefixIcon: Icon(Icons.timer),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: defaultPadding),
                      _buildCategoryDropdown(),
                      const SizedBox(height: defaultPadding),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Disponible'),
                        value: _isAvailable,
                        activeThumbColor: successColor,
                        onChanged: (v) => setState(() => _isAvailable = v),
                      ),
                      const Divider(height: largePadding),
                      OptionGroupsEditor(
                        groups: _optionGroups,
                        onChanged: (g) => _optionGroups = g,
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

  Widget _buildImageSection() {
    Widget preview;
    if (_newImageBytes != null) {
      preview = Image.memory(_newImageBytes!, fit: BoxFit.cover);
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      preview = Image.network(
        _imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.fastfood, size: 48, color: Colors.grey),
      );
    } else {
      preview = const Icon(Icons.fastfood, size: 48, color: Colors.grey);
    }

    return Center(
      child: Column(
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(defaultRadius),
              border: Border.all(color: Colors.grey.shade300),
            ),
            clipBehavior: Clip.antiAlias,
            child: preview,
          ),
          const SizedBox(height: 8),
          Text(
            _imageOverridden
                ? 'Image personnalisée'
                : 'Image automatique de la catégorie',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _pickFromLibrary,
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Bibliothèque'),
              ),
              TextButton.icon(
                onPressed: _uploadPhoto,
                icon: const Icon(Icons.upload, size: 18),
                label: const Text('Uploader'),
              ),
              if (_imageOverridden)
                TextButton.icon(
                  onPressed: _resetToCategoryImage,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Image catégorie'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    if (widget.categories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(defaultRadius),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Aucune catégorie. Créez d\'abord des catégories (onglet Catégories).',
                style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    // Dédupliquer par nom : des catégories globales homonymes (ex. deux
    // « Tacos ») créeraient plusieurs DropdownMenuItem de même valeur, ce qui
    // fait planter DropdownButton (« exactly one item with value »).
    final names = <String>[];
    for (final c in widget.categories) {
      if (!names.contains(c.name)) names.add(c.name);
    }
    // La catégorie actuelle du plat peut ne plus exister dans le catalogue
    // (renommée/supprimée) : on l'ajoute pour qu'elle corresponde à une valeur.
    if (_category != null &&
        _category!.isNotEmpty &&
        !names.contains(_category)) {
      names.add(_category!);
    }

    return DropdownButtonFormField<String>(
      initialValue: _category,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Catégorie *',
        prefixIcon: Icon(Icons.category),
      ),
      items: names
          .map((name) => DropdownMenuItem(value: name, child: Text(name)))
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        final matches = widget.categories.where((c) => c.name == v);
        if (matches.isNotEmpty) {
          _applyCategory(matches.first);
        } else {
          setState(() => _category = v);
        }
      },
      validator: (v) => v == null ? 'Choisissez une catégorie' : null,
    );
  }
}
