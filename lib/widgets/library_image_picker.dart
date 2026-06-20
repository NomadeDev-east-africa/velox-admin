import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/library_image.dart';
import '../services/menu_management_service.dart';

/// Ouvre une grille pour choisir une image dans la bibliothèque globale.
/// Renvoie l'URL choisie (ou null si annulé).
Future<String?> pickLibraryImage(BuildContext context) async {
  return showDialog<String>(
    context: context,
    builder: (_) => const _LibraryPickerDialog(),
  );
}

class _LibraryPickerDialog extends StatelessWidget {
  const _LibraryPickerDialog();

  @override
  Widget build(BuildContext context) {
    final service = MenuManagementService();
    return Dialog(
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 560),
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Choisir une image de la bibliothèque',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: defaultPadding),
            Flexible(
              child: StreamBuilder<List<LibraryImage>>(
                stream: service.streamLibraryImages(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }
                  final images = snap.data!;
                  if (images.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Bibliothèque vide.\nAjoutez des images depuis « Bibliothèque d\'images ».',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, i) {
                      final img = images[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(defaultRadius),
                        onTap: () => Navigator.pop(context, img.imageUrl),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(defaultRadius),
                                child: Image.network(
                                  img.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              img.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
