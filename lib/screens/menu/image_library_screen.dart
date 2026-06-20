import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../constants.dart';
import '../../models/library_image.dart';
import '../../services/menu_management_service.dart';

/// Gestion de la bibliothèque d'images globale (prédéfinie, partagée par tous
/// les restaurants) : upload + label, suppression.
class ImageLibraryScreen extends StatefulWidget {
  const ImageLibraryScreen({super.key});

  @override
  State<ImageLibraryScreen> createState() => _ImageLibraryScreenState();
}

class _ImageLibraryScreenState extends State<ImageLibraryScreen> {
  final _service = MenuManagementService();
  final _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bibliothèque d\'images')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        onPressed: _addImage,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('Ajouter'),
      ),
      body: StreamBuilder<List<LibraryImage>>(
        stream: _service.streamLibraryImages(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: primaryColor));
          }
          final images = snap.data ?? const <LibraryImage>[];
          if (images.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.collections,
                        size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('Bibliothèque vide',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Ajoutez des images génériques (burger, pizza, tacos…) '
                      'réutilisables pour toutes les catégories.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(defaultPadding),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.82,
            ),
            itemCount: images.length,
            itemBuilder: (context, i) => _imageCard(images[i]),
          );
        },
      ),
    );
  }

  Widget _imageCard(LibraryImage img) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  img.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      iconSize: 16,
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () => _deleteImage(img),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              img.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 75,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;

    final label = await _askLabel(file.name);
    if (label == null || label.trim().isEmpty) return;

    _showLoading();
    try {
      await _service.addLibraryImage(label: label.trim(), bytes: bytes);
      if (mounted) Navigator.pop(context); // ferme le loading
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
        );
      }
    }
  }

  Future<String?> _askLabel(String suggestion) {
    final controller = TextEditingController(
      text: suggestion.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nom de l\'image'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Label',
            hintText: 'Ex: Burger, Pizza, Tacos…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: primaryColor),
      ),
    );
  }

  Future<void> _deleteImage(LibraryImage img) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'image'),
        content: Text('Supprimer « ${img.label} » de la bibliothèque ?'),
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
    if (ok == true) await _service.deleteLibraryImage(img);
  }
}
