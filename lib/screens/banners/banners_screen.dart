import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/banner_item.dart';
import '../../services/banner_service.dart';
import 'add_edit_banner_screen.dart';

class BannersScreen extends StatefulWidget {
  const BannersScreen({super.key});

  @override
  State<BannersScreen> createState() => _BannersScreenState();
}

class _BannersScreenState extends State<BannersScreen> {
  final _bannerService = BannerService();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(defaultPadding),
          color: cardColor,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Bannières du carrousel promo affiché sur l\'accueil de l\'app client. '
                  'Glisse-dépose pour changer l\'ordre.',
                  style: captionStyle,
                ),
              ),
              const SizedBox(width: defaultPadding),
              ElevatedButton.icon(
                onPressed: _navigateToAdd,
                icon: const Icon(Icons.add),
                label: Text(isMobile(context) ? 'Ajouter' : 'Nouvelle bannière'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<BannerItem>>(
            stream: _bannerService.getBanners(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              final banners = snapshot.data!;
              if (banners.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.view_carousel_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('Aucune bannière créée', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                );
              }

              return ReorderableListView.builder(
                padding: const EdgeInsets.all(defaultPadding),
                itemCount: banners.length,
                onReorder: (oldIndex, newIndex) {
                  final reordered = List<BannerItem>.from(banners);
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, item);
                  _bannerService.reorder(reordered.map((b) => b.id).toList());
                },
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return Card(
                    key: ValueKey(banner.id),
                    margin: const EdgeInsets.only(bottom: defaultPadding),
                    child: ListTile(
                      leading: banner.type == BannerType.image
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: banner.imageUrl != null
                                  ? Image.network(banner.imageUrl!,
                                      width: 56, height: 40, fit: BoxFit.cover)
                                  : Container(width: 56, height: 40, color: veloxSurfaceAlt),
                            )
                          : Container(
                              width: 56,
                              height: 40,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.text_fields, color: primaryColor, size: 20),
                            ),
                      title: Text(
                        banner.type == BannerType.text
                            ? (banner.title ?? 'Sans titre')
                            : 'Bannière image',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (banner.type == BannerType.text && banner.subtitle != null)
                            Text(banner.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              _badge(banner.active ? 'Actif' : 'Inactif',
                                  banner.active ? successColor : errorColor),
                              if (banner.actionType != BannerActionType.none) ...[
                                const SizedBox(width: 8),
                                _badge(_actionLabel(banner.actionType), infoColor),
                              ],
                            ],
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: primaryColor),
                            onPressed: () => _navigateToEdit(banner),
                            tooltip: 'Modifier',
                          ),
                          IconButton(
                            icon: Icon(banner.active ? Icons.block : Icons.check_circle,
                                size: 20, color: banner.active ? errorColor : successColor),
                            onPressed: () => _bannerService.toggleActive(banner.id, !banner.active),
                            tooltip: banner.active ? 'Désactiver' : 'Activer',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: errorColor),
                            onPressed: () => _confirmDelete(banner),
                            tooltip: 'Supprimer',
                          ),
                          const Icon(Icons.drag_handle, color: textLightColor),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _actionLabel(BannerActionType type) {
    switch (type) {
      case BannerActionType.whatsapp:
        return 'WhatsApp';
      case BannerActionType.url:
        return 'Lien';
      case BannerActionType.restaurant:
        return 'Restaurant';
      case BannerActionType.category:
        return 'Catégorie';
      case BannerActionType.none:
        return '';
    }
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  void _navigateToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddEditBannerScreen()),
    );
  }

  void _navigateToEdit(BannerItem banner) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddEditBannerScreen(existing: banner)),
    );
  }

  Future<void> _confirmDelete(BannerItem banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la bannière'),
        content: const Text('Cette action est irréversible. Continuer ?'),
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
        await _bannerService.deleteBanner(banner);
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
