import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants.dart';
import '../../models/banner_item.dart';
import '../../models/global_category.dart';
import '../../models/restaurant.dart';
import '../../services/banner_service.dart';
import '../../services/menu_management_service.dart';
import '../../services/restaurant_service.dart';

/// Formulaire de création/édition d'une bannière du carrousel promo (accueil
/// Food, app client). Passer [existing] pour éditer.
class AddEditBannerScreen extends StatefulWidget {
  final BannerItem? existing;

  const AddEditBannerScreen({super.key, this.existing});

  @override
  State<AddEditBannerScreen> createState() => _AddEditBannerScreenState();
}

class _AddEditBannerScreenState extends State<AddEditBannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bannerService = BannerService();
  final _restaurantService = RestaurantService();
  final _menuManagementService = MenuManagementService();
  final _picker = ImagePicker();

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _actionValueController;

  BannerType _type = BannerType.text;
  BannerActionType _actionType = BannerActionType.none;
  bool _active = true;
  bool _isLoading = false;

  Uint8List? _newImageBytes;
  String? _existingImageUrl;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _subtitleController = TextEditingController(text: existing?.subtitle ?? '');
    _actionValueController = TextEditingController(text: existing?.actionValue ?? '');
    if (existing != null) {
      _type = existing.type;
      _actionType = existing.actionType;
      _active = existing.active;
      _existingImageUrl = existing.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _actionValueController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image trop grande (max 5MB)'),
            backgroundColor: warningColor,
          ),
        );
      }
      return;
    }
    setState(() => _newImageBytes = bytes);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_type == BannerType.image &&
        _newImageBytes == null &&
        _existingImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisis une image'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final actionValue = _actionType == BannerActionType.none
          ? null
          : _actionValueController.text.trim();

      final banner = BannerItem(
        id: widget.existing?.id ?? '',
        type: _type,
        order: widget.existing?.order ?? 0,
        active: _active,
        title: _type == BannerType.text ? _titleController.text.trim() : null,
        subtitle: _type == BannerType.text ? _subtitleController.text.trim() : null,
        imageUrl: _existingImageUrl,
        storagePath: widget.existing?.storagePath,
        actionType: _actionType,
        actionValue: actionValue,
      );

      if (_isEditing) {
        await _bannerService.updateBanner(banner, imageBytes: _newImageBytes);
      } else {
        await _bannerService.createBanner(banner, imageBytes: _newImageBytes);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier la bannière' : 'Nouvelle bannière'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(largePadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Type de bannière', style: subheadingStyle),
                  const SizedBox(height: smallPadding),
                  SegmentedButton<BannerType>(
                    segments: const [
                      ButtonSegment(
                        value: BannerType.text,
                        label: Text('Texte'),
                        icon: Icon(Icons.text_fields),
                      ),
                      ButtonSegment(
                        value: BannerType.image,
                        label: Text('Image'),
                        icon: Icon(Icons.image_outlined),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) {
                      setState(() => _type = selection.first);
                    },
                  ),
                  const SizedBox(height: largePadding),

                  if (_type == BannerType.text) ...[
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Titre'),
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Le titre est requis'
                          : null,
                    ),
                    const SizedBox(height: defaultPadding),
                    TextFormField(
                      controller: _subtitleController,
                      decoration: const InputDecoration(labelText: 'Sous-titre'),
                      maxLines: 2,
                      validator: (value) => (value == null || value.trim().isEmpty)
                          ? 'Le sous-titre est requis'
                          : null,
                    ),
                  ] else ...[
                    Text(
                      'Image large (ratio ~16:6 recommandé, sera recadrée)',
                      style: captionStyle,
                    ),
                    const SizedBox(height: smallPadding),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: veloxSurfaceAlt,
                          borderRadius: BorderRadius.circular(defaultRadius),
                          border: Border.all(color: Colors.white24),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _newImageBytes != null
                            ? Image.memory(_newImageBytes!, fit: BoxFit.cover)
                            : (_existingImageUrl != null
                                ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
                                : const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_photo_alternate_outlined,
                                            size: 32, color: textLightColor),
                                        SizedBox(height: 8),
                                        Text('Choisir une image'),
                                      ],
                                    ),
                                  )),
                      ),
                    ),
                  ],
                  const SizedBox(height: largePadding),

                  const Text('Action au clic', style: subheadingStyle),
                  const SizedBox(height: smallPadding),
                  DropdownButtonFormField<BannerActionType>(
                    initialValue: _actionType,
                    items: const [
                      DropdownMenuItem(
                          value: BannerActionType.none, child: Text('Aucune')),
                      DropdownMenuItem(
                          value: BannerActionType.whatsapp, child: Text('Ouvrir WhatsApp')),
                      DropdownMenuItem(
                          value: BannerActionType.url, child: Text('Ouvrir un lien')),
                      DropdownMenuItem(
                          value: BannerActionType.restaurant, child: Text('Ouvrir un restaurant')),
                      DropdownMenuItem(
                          value: BannerActionType.category, child: Text('Ouvrir une catégorie')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _actionType = value ?? BannerActionType.none;
                        _actionValueController.clear();
                      });
                    },
                  ),
                  const SizedBox(height: defaultPadding),
                  _buildActionValueField(),

                  if (_actionType != BannerActionType.none) const SizedBox(height: largePadding),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Actif'),
                    subtitle: const Text('Une bannière inactive ne s\'affiche plus côté client'),
                    value: _active,
                    activeThumbColor: primaryColor,
                    onChanged: (value) => setState(() => _active = value),
                  ),
                  const SizedBox(height: largePadding),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: veloxBlack),
                            )
                          : Text(_isEditing ? 'Enregistrer' : 'Créer la bannière'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionValueField() {
    switch (_actionType) {
      case BannerActionType.none:
        return const SizedBox.shrink();
      case BannerActionType.whatsapp:
        return TextFormField(
          controller: _actionValueController,
          decoration: const InputDecoration(
            labelText: 'Numéro WhatsApp',
            hintText: 'Ex: 25377453817',
            prefixIcon: Icon(Icons.chat_outlined),
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Numéro requis' : null,
        );
      case BannerActionType.url:
        return TextFormField(
          controller: _actionValueController,
          decoration: const InputDecoration(
            labelText: 'Lien',
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link),
          ),
          validator: (value) =>
              (value == null || value.trim().isEmpty) ? 'Lien requis' : null,
        );
      case BannerActionType.restaurant:
        return StreamBuilder<List<Restaurant>>(
          stream: _restaurantService.getRestaurants(),
          builder: (context, snapshot) {
            final restaurants = snapshot.data ?? [];
            final currentValue = restaurants.any((r) => r.id == _actionValueController.text)
                ? _actionValueController.text
                : null;
            return DropdownButtonFormField<String>(
              initialValue: currentValue,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.storefront_outlined)),
              items: restaurants
                  .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                  .toList(),
              onChanged: (value) => _actionValueController.text = value ?? '',
              validator: (value) =>
                  (_actionValueController.text.trim().isEmpty) ? 'Restaurant requis' : null,
            );
          },
        );
      case BannerActionType.category:
        return StreamBuilder<List<GlobalCategory>>(
          stream: _menuManagementService.streamGlobalCategories(),
          builder: (context, snapshot) {
            final categories = snapshot.data ?? [];
            final currentValue = categories.any((c) => c.name == _actionValueController.text)
                ? _actionValueController.text
                : null;
            return DropdownButtonFormField<String>(
              initialValue: currentValue,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined)),
              items: categories
                  .map((c) => DropdownMenuItem(value: c.name, child: Text(c.name)))
                  .toList(),
              onChanged: (value) => _actionValueController.text = value ?? '',
              validator: (value) =>
                  (_actionValueController.text.trim().isEmpty) ? 'Catégorie requise' : null,
            );
          },
        );
    }
  }
}
