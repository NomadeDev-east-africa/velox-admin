import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../constants.dart';
import '../../models/menu_item.dart';
import '../../models/global_category.dart';
import '../../models/option_group.dart';
import '../../services/menu_management_service.dart';
import '../../services/menu_parser.dart';
import '../../services/menu_json_parser.dart';
import '../../widgets/library_image_picker.dart';

/// Import d'un menu complet collé en texte → aperçu éditable → création en lot.
class ImportMenuScreen extends StatefulWidget {
  final String restaurantId;
  final String restaurantName;

  const ImportMenuScreen({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  @override
  State<ImportMenuScreen> createState() => _ImportMenuScreenState();
}

class _ImportMenuScreenState extends State<ImportMenuScreen> {
  final _service = MenuManagementService();
  final _textController = TextEditingController();

  ParsedMenu? _parsed;
  final Map<String, String?> _categoryImages = {}; // nom -> imageUrl
  // Catégories auxquelles appliquer les suppléments détectés (nom -> bool).
  // Pré-rempli depuis le fichier ; éditable dans l'aperçu.
  final Map<String, bool> _supplementCategories = {};
  List<GlobalCategory> _globalCats = [];
  bool _isImporting = false;
  String? _fileName;

  @override
  void initState() {
    super.initState();
    _loadGlobalCategories();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _loadGlobalCategories() async {
    try {
      final cats = await _service.getGlobalCategories();
      if (mounted) setState(() => _globalCats = cats);
    } catch (_) {/* ignore : l'import reste possible sans images auto */}
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _snack('Impossible de lire le fichier.', Colors.orange);
      return;
    }
    setState(() {
      _fileName = file.name;
      _textController.text = utf8.decode(bytes, allowMalformed: true);
    });
    _parse();
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  // Catégories qui ne reçoivent jamais de suppléments par défaut (boissons,
  // desserts…) — laissées décochées sauf si le fichier les cible explicitement.
  static final _noSupplementCat = RegExp(
    r'boisson|cocktail|dessert|glace|caf[ée]|jus|soft|\beau\b|th[ée]|infusion',
    caseSensitive: false,
  );

  void _parse() {
    // JSON standard d'abord (déterministe), sinon parser texte heuristique.
    final raw = _textController.text;
    final parsed = MenuJsonParser.tryParse(raw) ?? MenuParser.parse(raw);
    setState(() {
      _parsed = parsed;
      _categoryImages.clear();
      _supplementCategories.clear();
      for (final c in parsed.categories) {
        // Image héritée automatiquement de la catégorie globale (si elle existe).
        _categoryImages[c.name] =
            _service.imageForCategoryName(c.name, _globalCats);
        // Suppléments : si le fichier a précisé des catégories, on ne coche que
        // celles-là ; sinon, défaut intelligent = toutes SAUF les boissons/
        // desserts (évite « Coca + fromage »). Reste éditable via les chips.
        _supplementCategories[c.name] = parsed.supplementCategoriesSpecified
            ? parsed.supplementCategories.contains(c.name.toLowerCase())
            : !_noSupplementCat.hasMatch(c.name);
      }
    });
    if (parsed.itemCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun plat détecté. Vérifiez le format du texte.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _pickCategoryImage(String catName) async {
    final url = await pickLibraryImage(context);
    if (url != null) setState(() => _categoryImages[catName] = url);
  }

  Future<void> _import() async {
    final parsed = _parsed;
    if (parsed == null || parsed.itemCount == 0) return;

    setState(() => _isImporting = true);
    try {
      final supplementsGroup = parsed.globalSupplements.isNotEmpty
          ? OptionGroup(
              name: 'Suppléments',
              type: OptionType.multiple,
              required: false,
              choices: parsed.globalSupplements,
            )
          : null;

      final now = DateTime.now();
      final items = <MenuItem>[];
      for (final cat in parsed.categories) {
        final imageUrl = _categoryImages[cat.name];
        final applySupplements =
            supplementsGroup != null && (_supplementCategories[cat.name] ?? false);
        for (final pi in cat.items) {
          final groups = <OptionGroup>[...pi.buildOptionGroups()];
          // Ne pas dupliquer : si le plat porte déjà ses propres « Suppléments »
          // (ex. Tacos via JSON), on n'ajoute pas le groupe global par-dessus.
          final hasOwnSupplements = groups.any(
              (g) => g.name.toLowerCase().startsWith('suppl'));
          if (applySupplements && !hasOwnSupplements) {
            groups.add(supplementsGroup);
          }
          items.add(MenuItem(
            id: '',
            restaurantId: widget.restaurantId,
            name: pi.name,
            description: '',
            price: pi.basePrice.toDouble(),
            imageUrl: imageUrl,
            category: cat.name,
            isAvailable: true,
            preparationTime: 20,
            optionGroups: groups,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }

      final count = await _service.importMenu(
        restaurantId: widget.restaurantId,
        items: items,
        categoryImages: _categoryImages,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count plat(s) importé(s) avec succès'),
          backgroundColor: successColor,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur import: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Importer un menu — ${widget.restaurantName}')),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(largePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPasteCard(),
                if (_parsed != null) ...[
                  const SizedBox(height: largePadding),
                  _buildPreview(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasteCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Importer le menu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Deux formats acceptés : un fichier/​texte JSON (recommandé — fiable pour '
              'tout menu, généré par une IA) OU du texte libre. Pour le texte : en-têtes '
              'de catégorie en MAJUSCULES, plats « Nom : 600 FDJ (menu 900 FDJ) », tailles, '
              'section « Suppléments » (limitez-les à certaines catégories entre '
              'parenthèses : « Suppléments (Hamburgers, Tacos) »). Les boissons et desserts '
              'sont exclus des suppléments par défaut. L\'image de chaque catégorie est '
              'reprise automatiquement depuis la page Catégories. L\'aperçu reste modifiable.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: defaultPadding),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choisir un fichier (.json ou .txt)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_fileName != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _fileName!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: defaultPadding),
            Text('— ou collez le texte —',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            TextField(
              controller: _textController,
              maxLines: 12,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'HAMBURGERS (prix seul / prix menu +300 FDJ)\n'
                    'Cheeseburger : 600 FDJ (menu 900 FDJ)\n...',
              ),
            ),
            const SizedBox(height: defaultPadding),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _parse,
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Analyser'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final parsed = _parsed!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '2. Aperçu',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text(
                      '${parsed.categories.length} catégorie(s) · ${parsed.itemCount} plat(s)'),
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                ),
              ],
            ),
            const SizedBox(height: defaultPadding),
            for (final cat in parsed.categories) _buildCategoryBlock(cat),
            if (parsed.globalSupplements.isNotEmpty) ...[
              const Divider(height: largePadding),
              Text(
                'Suppléments détectés : '
                '${parsed.globalSupplements.map((s) => '${s.name} +${s.price}').join(', ')}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Appliquer ces suppléments aux catégories :',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in parsed.categories)
                    FilterChip(
                      label: Text(c.name),
                      selected: _supplementCategories[c.name] ?? false,
                      onSelected: (v) => setState(
                          () => _supplementCategories[c.name] = v),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Astuce : précisez les catégories dans le fichier — '
                '« Suppléments (Hamburgers, Tacos) » — pour exclure '
                'automatiquement les boissons.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
            const Divider(height: largePadding),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isImporting ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isImporting ? null : _import,
                  icon: _isImporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isImporting
                      ? 'Import en cours…'
                      : 'Importer ${parsed.itemCount} plat(s)'),
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
    );
  }

  Widget _buildCategoryBlock(ParsedCategory cat) {
    final imageUrl = _categoryImages[cat.name];
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
      child: Column(
        children: [
          // En-tête catégorie : image + nom éditable
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _pickCategoryImage(cat.name),
                  borderRadius: BorderRadius.circular(smallRadius),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(smallRadius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (imageUrl != null && imageUrl.isNotEmpty)
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : const Icon(Icons.add_photo_alternate,
                            color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: cat.name,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      final old = cat.name;
                      cat.name = v;
                      final img = _categoryImages.remove(old);
                      _categoryImages[v] = img;
                      final sup = _supplementCategories.remove(old);
                      setState(() => _supplementCategories[v] = sup ?? false);
                    },
                  ),
                ),
                TextButton(
                  onPressed: () => _pickCategoryImage(cat.name),
                  child: Text(imageUrl == null ? 'Image' : 'Changer'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Plats
          ...cat.items.map((it) => _buildItemRow(cat, it)),
        ],
      ),
    );
  }

  Widget _buildItemRow(ParsedCategory cat, ParsedItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: TextFormField(
              initialValue: item.name,
              decoration: const InputDecoration(isDense: true),
              onChanged: (v) => item.name = v,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: item.basePrice.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                suffixText: 'FDJ',
              ),
              onChanged: (v) => item.setBasePrice(int.tryParse(v) ?? 0),
            ),
          ),
          if (item.hasSizes)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message:
                    'Tailles : ${item.sizes.map((e) => '${e.key} ${e.value}').join(' · ')}',
                child: Chip(
                  label: Text(item.sizes.map((e) => e.key).join('/'),
                      style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                ),
              ),
            ),
          if (item.menuPrice != null)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Tooltip(
                message: 'Formule menu détectée (+${item.menuPrice! - item.basePrice} FDJ)',
                child: const Icon(Icons.restaurant_menu,
                    size: 18, color: accentColor),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => cat.items.remove(item)),
          ),
        ],
      ),
    );
  }
}
