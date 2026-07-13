import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/menu_item.dart';
import '../models/menu_category.dart';
import '../models/global_category.dart';
import '../models/library_image.dart';

/// Service dédié à la gestion des menus depuis l'app admin :
/// - catégories par restaurant (`restaurants/{id}/categories`)
/// - bibliothèque d'images globale (`menuImageLibrary`)
/// - upload d'images vers Firebase Storage
/// - création/import en lot de plats (`menuItems`)
class MenuManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  CollectionReference get _menuItems => _firestore.collection('menuItems');
  CollectionReference get _imageLibrary =>
      _firestore.collection('menuImageLibrary');
  CollectionReference get _globalCategories =>
      _firestore.collection('menuCategories');
  CollectionReference _categories(String restaurantId) =>
      _firestore.collection('restaurants').doc(restaurantId).collection('categories');

  // ==================== CATÉGORIES GLOBALES ====================

  Stream<List<GlobalCategory>> streamGlobalCategories() {
    return _globalCategories.snapshots().map((snap) {
      final list =
          snap.docs.map((d) => GlobalCategory.fromFirestore(d)).toList();
      // Tri alphabétique (insensible à la casse)
      list.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<List<GlobalCategory>> getGlobalCategories() async {
    final snap = await _globalCategories.get();
    final list = snap.docs.map((d) => GlobalCategory.fromFirestore(d)).toList();
    list.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return list;
  }

  Future<String> createGlobalCategory(GlobalCategory category) async {
    final data = category.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _globalCategories.add(data);
    return ref.id;
  }

  Future<void> updateGlobalCategory(GlobalCategory category) async {
    await _globalCategories.doc(category.id).update(category.toMap());
  }

  Future<void> deleteGlobalCategory(GlobalCategory category) async {
    await _globalCategories.doc(category.id).delete();
    if (category.storagePath != null && category.storagePath!.isNotEmpty) {
      try {
        await _storage.ref(category.storagePath!).delete();
      } catch (_) {/* déjà absent */}
    }
  }

  /// Upload une image dédiée de catégorie : `menu_categories/{ts}_{slug}.jpg`.
  /// Renvoie (url, storagePath).
  Future<(String, String)> uploadCategoryImage({
    required String name,
    required Uint8List bytes,
  }) async {
    final path =
        'menu_categories/${DateTime.now().millisecondsSinceEpoch}_${_slug(name)}.jpg';
    final url = await _uploadBytes(path, bytes);
    return (url, path);
  }

  /// Image globale associée à un nom de catégorie (insensible à la casse), ou
  /// `null` (→ fallback gris). [categories] évite une relecture Firestore.
  String? imageForCategoryName(String name, List<GlobalCategory> categories) {
    final key = name.trim().toLowerCase();
    for (final c in categories) {
      if (c.name.trim().toLowerCase() == key) return c.imageUrl;
    }
    return null;
  }

  /// Crée les catégories globales manquantes pour [namesWithImages]
  /// (nom → imageUrl éventuelle). Complète l'image si la catégorie existait
  /// sans image. Retourne le nombre de catégories créées.
  Future<int> ensureGlobalCategories(
      Map<String, String?> namesWithImages) async {
    final existing = await getGlobalCategories();
    final byName = {for (final c in existing) c.name.trim().toLowerCase(): c};
    var created = 0;
    var order = existing.length;
    for (final entry in namesWithImages.entries) {
      final name = entry.key.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      final current = byName[key];
      if (current == null) {
        final cat = GlobalCategory(
          id: '',
          name: name,
          imageUrl: entry.value,
          order: order++,
        );
        final id = await createGlobalCategory(cat);
        byName[key] = cat.copyWith(id: id);
        created++;
      } else if (entry.value != null && !current.hasImage) {
        final updated = current.copyWith(imageUrl: entry.value);
        await updateGlobalCategory(updated);
        byName[key] = updated;
      }
    }
    return created;
  }

  /// Réapplique l'image de chaque catégorie globale aux plats (`menuItems`)
  /// dont la catégorie correspond (comparaison **insensible à la casse et aux
  /// espaces**).
  ///
  /// Contexte : chaque plat stocke une **copie figée** de l'image de sa
  /// catégorie (faite à l'import). Si l'image d'une catégorie est ajoutée ou
  /// modifiée **après** l'import, les plats existants gardent leur ancienne
  /// valeur (souvent `null`) et l'app client n'affiche donc rien. Cette méthode
  /// resynchronise ces images.
  ///
  /// - [overwriteExisting] = false (défaut) : ne remplit que les plats **sans
  ///   image** — opération sûre.
  /// - [overwriteExisting] = true : écrase aussi les plats qui ont déjà une
  ///   image (utile après avoir changé l'image d'une catégorie).
  ///
  /// Retourne le nombre de plats mis à jour.
  Future<int> applyCategoryImagesToMenuItems({
    bool overwriteExisting = false,
  }) async {
    // 1. Index nom (normalisé) -> imageUrl, pour les catégories qui ont une image.
    final categories = await getGlobalCategories();
    final imageByName = <String, String>{};
    for (final c in categories) {
      if (c.hasImage) {
        imageByName[c.name.trim().toLowerCase()] = c.imageUrl!;
      }
    }
    if (imageByName.isEmpty) return 0;

    // 2. Parcourir tous les plats et corriger ceux qui doivent l'être.
    final snap = await _menuItems.get();
    var updated = 0;
    var batch = _firestore.batch();
    var ops = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final key = (data['category'] ?? '').toString().trim().toLowerCase();
      final target = imageByName[key];
      if (target == null) continue; // pas d'image pour cette catégorie

      final current = (data['imageUrl'] ?? '').toString();
      if (current == target) continue; // déjà à jour
      if (!overwriteExisting && current.isNotEmpty) continue; // on préserve

      batch.update(doc.reference, {
        'imageUrl': target,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ops++;
      updated++;
      if (ops >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    return updated;
  }

  /// Fusionne les catégories globales en **double** (même nom, insensible à la
  /// casse et aux espaces, ex. deux « Tacos ») : conserve une seule entrée par
  /// nom — de préférence celle qui a une image — et supprime les autres.
  ///
  /// Les plats ne sont pas affectés (ils référencent la catégorie par son nom,
  /// identique pour tous les doublons). Retourne le nombre d'entrées supprimées.
  Future<int> mergeDuplicateGlobalCategories() async {
    final cats = await getGlobalCategories();
    final byKey = <String, List<GlobalCategory>>{};
    for (final c in cats) {
      byKey.putIfAbsent(c.name.trim().toLowerCase(), () => []).add(c);
    }
    var removed = 0;
    for (final group in byKey.values) {
      if (group.length < 2) continue;
      // Conserver en priorité l'entrée qui possède une image, puis le plus
      // petit `order` ; supprimer les autres.
      group.sort((a, b) {
        final ai = a.hasImage ? 0 : 1;
        final bi = b.hasImage ? 0 : 1;
        if (ai != bi) return ai - bi;
        return a.order.compareTo(b.order);
      });
      for (final dup in group.skip(1)) {
        await _globalCategories.doc(dup.id).delete();
        removed++;
      }
    }
    return removed;
  }

  /// Agrège les noms de catégories déjà utilisés dans `menuItems` et crée les
  /// catégories globales manquantes (sans image → fallback gris).
  /// Retourne le nombre de catégories ajoutées.
  Future<int> seedGlobalCategoriesFromMenuItems() async {
    final snap = await _menuItems.get();
    final names = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cat = (data['category'] ?? '').toString().trim();
      if (cat.isNotEmpty) names.add(cat);
    }
    return ensureGlobalCategories({for (final n in names) n: null});
  }

  // ==================== BIBLIOTHÈQUE D'IMAGES ====================

  Stream<List<LibraryImage>> streamLibraryImages() {
    return _imageLibrary.orderBy('label').snapshots().map((snap) =>
        snap.docs.map((d) => LibraryImage.fromFirestore(d)).toList());
  }

  Future<List<LibraryImage>> getLibraryImages() async {
    final snap = await _imageLibrary.orderBy('label').get();
    return snap.docs.map((d) => LibraryImage.fromFirestore(d)).toList();
  }

  /// Upload une image de bibliothèque puis crée son document Firestore.
  Future<LibraryImage> addLibraryImage({
    required String label,
    required Uint8List bytes,
  }) async {
    final path =
        'menu_library/${DateTime.now().millisecondsSinceEpoch}_${_slug(label)}.jpg';
    final url = await _uploadBytes(path, bytes);

    final docRef = await _imageLibrary.add({
      'label': label.trim(),
      'imageUrl': url,
      'storagePath': path,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return LibraryImage(
      id: docRef.id,
      label: label.trim(),
      imageUrl: url,
      storagePath: path,
    );
  }

  Future<void> deleteLibraryImage(LibraryImage image) async {
    await _imageLibrary.doc(image.id).delete();
    if (image.storagePath != null && image.storagePath!.isNotEmpty) {
      try {
        await _storage.ref(image.storagePath!).delete();
      } catch (_) {
        // fichier déjà absent — on ignore
      }
    }
  }

  // ==================== CATÉGORIES ====================

  Stream<List<MenuCategory>> streamCategories(String restaurantId) {
    return _categories(restaurantId).snapshots().map((snap) {
      final list =
          snap.docs.map((d) => MenuCategory.fromFirestore(d)).toList();
      list.sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Future<List<MenuCategory>> getCategories(String restaurantId) async {
    final snap = await _categories(restaurantId).get();
    final list = snap.docs.map((d) => MenuCategory.fromFirestore(d)).toList();
    list.sort((a, b) {
      final byOrder = a.order.compareTo(b.order);
      return byOrder != 0 ? byOrder : a.name.compareTo(b.name);
    });
    return list;
  }

  Future<String> createCategory(MenuCategory category) async {
    final data = category.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _categories(category.restaurantId).add(data);
    return ref.id;
  }

  Future<void> updateCategory(MenuCategory category) async {
    await _categories(category.restaurantId)
        .doc(category.id)
        .update(category.toMap());
  }

  Future<void> deleteCategory(MenuCategory category) async {
    await _categories(category.restaurantId).doc(category.id).delete();
  }

  /// Renvoie une catégorie existante par nom (insensible à la casse) ou la crée.
  Future<MenuCategory> ensureCategory({
    required String restaurantId,
    required String name,
    String? imageUrl,
    List<MenuCategory>? existing,
  }) async {
    final cats = existing ?? await getCategories(restaurantId);
    final match = cats.where(
      (c) => c.name.trim().toLowerCase() == name.trim().toLowerCase(),
    );
    if (match.isNotEmpty) return match.first;

    final newCat = MenuCategory(
      id: '',
      restaurantId: restaurantId,
      name: name.trim(),
      imageUrl: imageUrl,
      order: cats.length,
    );
    final id = await createCategory(newCat);
    return newCat.copyWith(id: id);
  }

  // ==================== PLATS (menuItems) ====================

  Stream<List<MenuItem>> streamMenuItems(String restaurantId) {
    return _menuItems
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((d) => MenuItem.fromFirestore(d)).toList();
      list.sort((a, b) {
        final byCat = a.category.compareTo(b.category);
        return byCat != 0 ? byCat : a.name.compareTo(b.name);
      });
      return list;
    });
  }

  Future<String> createMenuItem(MenuItem item) async {
    final ref = await _menuItems.add(item.toMap());
    return ref.id;
  }

  Future<void> updateMenuItem(String id, Map<String, dynamic> data) async {
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _menuItems.doc(id).update(data);
  }

  Future<void> deleteMenuItem(String id) async {
    await _menuItems.doc(id).delete();
  }

  /// Renomme une catégorie **dans le menu d'un restaurant** : tous les plats de
  /// ce restaurant dont la catégorie vaut [oldName] (comparaison insensible à la
  /// casse et aux espaces) reçoivent [newName]. Les autres restaurants ne sont
  /// pas touchés.
  ///
  /// Si une catégorie globale porte le [newName] et possède une image, cette
  /// image est aussi appliquée aux plats renommés (leur `imageUrl` étant une
  /// copie figée de l'image de catégorie). Si le nouveau nom n'a pas d'image
  /// globale, les images existantes des plats sont préservées.
  ///
  /// Retourne le nombre de plats mis à jour.
  Future<int> renameCategoryForRestaurant({
    required String restaurantId,
    required String oldName,
    required String newName,
  }) async {
    final target = newName.trim();
    final key = oldName.trim().toLowerCase();
    if (target.isEmpty || key.isEmpty) return 0;

    // Image de la catégorie globale correspondant au nouveau nom (si elle
    // existe) → reprise automatiquement par les plats renommés.
    final globalImage =
        imageForCategoryName(target, await getGlobalCategories());
    final hasGlobalImage = globalImage != null && globalImage.isNotEmpty;

    final snap =
        await _menuItems.where('restaurantId', isEqualTo: restaurantId).get();
    var updated = 0;
    var batch = _firestore.batch();
    var ops = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final cat = (data['category'] ?? '').toString().trim().toLowerCase();
      if (cat != key) continue;
      batch.update(doc.reference, {
        'category': target,
        if (hasGlobalImage) 'imageUrl': globalImage,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ops++;
      updated++;
      if (ops >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    return updated;
  }

  Future<void> toggleAvailability(String id, bool isAvailable) async {
    await updateMenuItem(id, {'isAvailable': isAvailable});
  }

  /// Upload une photo spécifique de plat : `menuItems/{restaurantId}/{ts}.jpg`.
  Future<String> uploadMenuItemImage({
    required String restaurantId,
    required Uint8List bytes,
  }) async {
    final path =
        'menuItems/$restaurantId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return _uploadBytes(path, bytes);
  }

  /// Crée en lot un menu complet (utilisé par l'import).
  ///
  /// [items] : plats déjà résolus (category + imageUrl + prix + optionGroups,
  /// propres au restaurant). [categoryImages] : nom de catégorie → image
  /// éventuelle, utilisé pour alimenter le **catalogue global** de catégories
  /// (création des catégories manquantes, complétion d'image si absente).
  Future<int> importMenu({
    required String restaurantId,
    required List<MenuItem> items,
    Map<String, String?> categoryImages = const {}, // nom catégorie -> imageUrl
  }) async {
    // 1. Alimenter le catalogue global de catégories (images incluses).
    await ensureGlobalCategories(categoryImages);

    // 2. Créer les plats par batch (max 500 écritures / batch)
    var written = 0;
    var batch = _firestore.batch();
    var ops = 0;
    for (final item in items) {
      final ref = _menuItems.doc();
      batch.set(ref, item.toMap());
      ops++;
      written++;
      if (ops >= 450) {
        await batch.commit();
        batch = _firestore.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
    return written;
  }

  // ==================== HELPERS ====================

  Future<String> _uploadBytes(String path, Uint8List bytes) async {
    final ref = _storage.ref(path);
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    final task = await ref.putData(bytes, metadata);
    return task.ref.getDownloadURL();
  }

  String _slug(String input) {
    final s = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return s.isEmpty ? 'image' : s;
  }
}
