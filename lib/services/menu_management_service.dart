import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/menu_item.dart';
import '../models/menu_category.dart';
import '../models/global_category.dart';
import '../models/library_image.dart';
import '../utils/category_naming.dart';

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

  /// Tri unique des catégories globales : `order`, puis nom.
  ///
  /// [streamGlobalCategories] et [getGlobalCategories] partagent ce comparateur
  /// pour qu'un même catalogue s'affiche dans le même ordre partout — l'un
  /// triait auparavant par nom et l'autre par `order`, donnant deux ordres
  /// différents selon l'écran.
  static int _byOrderThenName(GlobalCategory a, GlobalCategory b) {
    final byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) return byOrder;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  Stream<List<GlobalCategory>> streamGlobalCategories() {
    return _globalCategories.snapshots().map((snap) =>
        snap.docs.map((d) => GlobalCategory.fromFirestore(d)).toList()
          ..sort(_byOrderThenName));
  }

  Future<List<GlobalCategory>> getGlobalCategories() async {
    final snap = await _globalCategories.get();
    return snap.docs.map((d) => GlobalCategory.fromFirestore(d)).toList()
      ..sort(_byOrderThenName);
  }

  Future<String> createGlobalCategory(GlobalCategory category) async {
    final data = category.toMap()..['createdAt'] = FieldValue.serverTimestamp();
    final ref = await _globalCategories.add(data);
    return ref.id;
  }

  Future<void> updateGlobalCategory(GlobalCategory category) async {
    await _globalCategories.doc(category.id).update(category.toMap());
  }

  /// Renomme une catégorie globale **et tous les plats qui la portent**.
  ///
  /// Les plats référencent leur catégorie par son nom : renommer le seul
  /// document laisserait `menuItems.category` sur l'ancien nom, donc des plats
  /// rattachés à une catégorie qui n'existe plus (rubrique fantôme dans l'admin,
  /// fallback gris côté client). Les plats sont réécrits **avant** le document,
  /// pour qu'une interruption laisse au pire un état encore cohérent.
  ///
  /// Les images ne sont pas touchées : un renommage ne change pas le visuel.
  ///
  /// Retourne le nombre de plats mis à jour.
  Future<int> renameGlobalCategory(GlobalCategory category, String newName) async {
    final target = newName.trim();
    if (target.isEmpty || target == category.name.trim()) return 0;

    final updated =
        await _rewriteCategoryNameEverywhere(from: category.name, to: target);
    await updateGlobalCategory(category.copyWith(name: target));
    return updated;
  }

  /// Supprime une catégorie globale.
  ///
  /// **L'image n'est pas effacée de Storage** : les plats en gardent une copie
  /// figée dans leur `imageUrl`, supprimer le fichier les ferait tomber en 404
  /// côté client. Quelques Ko conservés valent mieux qu'une image cassée.
  ///
  /// N'empêche pas la suppression d'une catégorie encore utilisée : c'est à
  /// l'appelant de vérifier via [countMenuItemsInCategory] et de proposer
  /// [moveItemsAndDeleteCategory].
  Future<void> deleteGlobalCategory(GlobalCategory category) async {
    await _globalCategories.doc(category.id).delete();
  }

  /// Nombre de plats (tous restaurants) rattachés à la catégorie [name].
  ///
  /// Compte sur [categoryKey], donc « Boissons Chaudes » est bien compté pour
  /// « Boissons chaudes ».
  Future<int> countMenuItemsInCategory(String name) async {
    final key = categoryKey(name);
    if (key.isEmpty) return 0;
    final snap = await _menuItems.get();
    return snap.docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return categoryKey((data['category'] ?? '').toString()) == key;
    }).length;
  }

  /// Déplace tous les plats de [category] vers [targetName], puis supprime la
  /// catégorie. Les plats reçoivent l'image de la catégorie cible si la leur
  /// n'était qu'un héritage (une photo propre au plat est préservée).
  ///
  /// Les plats sont déplacés **avant** la suppression : une interruption laisse
  /// au pire des plats déjà rangés dans une catégorie valide.
  ///
  /// Retourne le nombre de plats déplacés.
  Future<int> moveItemsAndDeleteCategory({
    required GlobalCategory category,
    required String targetName,
  }) async {
    final target = targetName.trim();
    if (target.isEmpty || categoryKey(target) == categoryKey(category.name)) {
      throw ArgumentError('La catégorie cible doit être différente.');
    }
    final targetImage = imageForCategoryName(target, await getGlobalCategories());
    final moved = await _rewriteCategoryNameEverywhere(
      from: category.name,
      to: target,
      image: targetImage,
    );
    await deleteGlobalCategory(category);
    return moved;
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

  /// Image globale associée à un nom de catégorie, ou `null` (→ fallback gris).
  ///
  /// La correspondance passe par [categoryKey] : « Nos Boissons » retrouve donc
  /// l'image de « Boissons ». [categories] évite une relecture Firestore.
  String? imageForCategoryName(String name, List<GlobalCategory> categories) {
    final key = categoryKey(name);
    for (final c in categories) {
      if (categoryKey(c.name) == key) return c.imageUrl;
    }
    return null;
  }

  /// Crée les catégories globales manquantes pour [namesWithImages]
  /// (nom → imageUrl éventuelle). Complète l'image si la catégorie existait
  /// sans image. Retourne le nombre de catégories créées.
  ///
  /// L'existence est testée sur [categoryKey], pas sur le nom brut : importer
  /// « Milks Shakes » alors que « Milkshakes » existe déjà ne crée plus de
  /// doublon. C'est ce test, trop strict auparavant, qui a fait passer le
  /// catalogue à 123 entrées pour ~96 catégories réelles.
  Future<int> ensureGlobalCategories(
      Map<String, String?> namesWithImages) async {
    final existing = await getGlobalCategories();
    final byName = {for (final c in existing) categoryKey(c.name): c};
    var created = 0;
    // `order` doit continuer la suite existante. Se baser sur `existing.length`
    // produisait des collisions dès qu'une catégorie avait été supprimée.
    var order = existing.fold<int>(-1, (max, c) => c.order > max ? c.order : max) + 1;
    for (final entry in namesWithImages.entries) {
      final name = entry.key.trim();
      if (name.isEmpty) continue;
      final key = categoryKey(name);
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
    // 1. Index clé normalisée -> imageUrl, pour les catégories qui ont une image.
    final categories = await getGlobalCategories();
    final imageByName = <String, String>{};
    for (final c in categories) {
      if (c.hasImage) {
        imageByName[categoryKey(c.name)] = c.imageUrl!;
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
      final key = categoryKey((data['category'] ?? '').toString());
      final target = imageByName[key];
      if (target == null) continue; // pas d'image pour cette catégorie

      final current = (data['imageUrl'] ?? '').toString();
      if (current == target) continue; // déjà à jour
      // Une photo propre au plat n'est jamais écrasée par l'image de sa
      // catégorie, même en mode [overwriteExisting].
      if (isOwnDishPhoto(current)) continue;
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

  /// Fusionne les catégories globales désignant la même chose (même
  /// [categoryKey] : « Milkshake », « Milks Shakes », « Nos Milk Shake »…).
  ///
  /// Conserve une seule entrée par famille — de préférence celle qui porte une
  /// image — et supprime les autres.
  ///
  /// **Les plats sont réécrits** : chaque `menuItems.category` pointant vers une
  /// variante absorbée reçoit le nom conservé, et l'image de la catégorie
  /// conservée si la sienne n'était qu'un héritage. Sans cette réécriture, les
  /// plats resteraient sur un nom que plus aucune catégorie ne porte, et
  /// [seedGlobalCategoriesFromMenuItems] recréerait aussitôt les doublons.
  ///
  /// L'ordre est délibéré : les plats d'abord, la suppression ensuite. Une
  /// interruption en cours laisse au pire des plats pointant vers une catégorie
  /// encore existante — jamais vers un nom orphelin.
  ///
  /// Retourne le nombre d'entrées supprimées.
  Future<int> mergeDuplicateGlobalCategories() async {
    final cats = await getGlobalCategories();
    final byKey = <String, List<GlobalCategory>>{};
    for (final c in cats) {
      byKey.putIfAbsent(categoryKey(c.name), () => []).add(c);
    }

    var removed = 0;
    for (final group in byKey.values) {
      if (group.length < 2) continue;
      // Conserver en priorité l'entrée qui possède une image, puis le plus
      // petit `order`.
      group.sort((a, b) {
        final ai = a.hasImage ? 0 : 1;
        final bi = b.hasImage ? 0 : 1;
        if (ai != bi) return ai - bi;
        return a.order.compareTo(b.order);
      });
      final keep = group.first;

      for (final dup in group.skip(1)) {
        await _rewriteCategoryNameEverywhere(
          from: dup.name,
          to: keep.name,
          image: keep.imageUrl,
        );
        // On supprime le document, mais pas son image dans Storage : elle peut
        // encore être référencée par les plats de la catégorie conservée.
        await _globalCategories.doc(dup.id).delete();
        removed++;
      }
    }
    return removed;
  }

  /// Réécrit `category` de **tous** les plats (tous restaurants) rattachés à la
  /// catégorie [from], vers [to]. Applique [image] aux plats sans image ou dont
  /// l'image n'est qu'un héritage de catégorie ; les photos propres au plat sont
  /// préservées. Retourne le nombre de plats mis à jour.
  ///
  /// L'appartenance est testée sur [categoryKey], pas sur l'égalité du nom : un
  /// plat rangé dans « Boissons Chaudes » suit sa catégorie « Boissons chaudes »
  /// alors qu'une requête `isEqualTo` l'aurait laissé derrière, orphelin. D'où le
  /// parcours complet de la collection plutôt qu'une requête indexée.
  Future<int> _rewriteCategoryNameEverywhere({
    required String from,
    required String to,
    String? image,
  }) async {
    final target = to.trim();
    final sourceKey = categoryKey(from);
    if (target.isEmpty || sourceKey.isEmpty) return 0;

    final snap = await _menuItems.get();
    var updated = 0;
    var batch = _firestore.batch();
    var ops = 0;
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['category'] ?? '').toString();
      if (categoryKey(name) != sourceKey) continue;

      final current = (data['imageUrl'] ?? '').toString();
      final takesName = name.trim() != target;
      final needsImage = image != null &&
          image.isNotEmpty &&
          current != image &&
          !isOwnDishPhoto(current);
      if (!takesName && !needsImage) continue; // déjà conforme

      batch.update(doc.reference, {
        'category': target,
        if (needsImage) 'imageUrl': image,
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

  /// Agrège les noms de catégories déjà utilisés dans `menuItems` et crée les
  /// catégories globales manquantes (sans image → fallback gris).
  ///
  /// S'appuie sur [ensureGlobalCategories], donc sur [categoryKey] : un plat
  /// rangé dans « Tacos » alors que la catégorie s'appelle « tacos » ne fait
  /// plus apparaître de seconde entrée. Tant que la comparaison se faisait sur
  /// le nom brut, chaque appel recréait les variantes tout juste fusionnées.
  ///
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
  ///
  /// Les noms de catégories du fichier importé sont réalignés sur ceux du
  /// catalogue via [canonicalCategoryName] : un menu écrivant « Milks Shakes »
  /// range ses plats dans « Milkshakes » si le catalogue le connaît déjà.
  Future<int> importMenu({
    required String restaurantId,
    required List<MenuItem> items,
    Map<String, String?> categoryImages = const {}, // nom catégorie -> imageUrl
  }) async {
    // 1. Alimenter le catalogue global de catégories (images incluses).
    await ensureGlobalCategories(categoryImages);

    // 2. Aligner les plats sur les noms du catalogue. Sans cette étape,
    //    `ensureGlobalCategories` ne crée certes plus de catégorie en double,
    //    mais les plats garderaient l'orthographe du fichier et pointeraient
    //    vers un nom que plus aucune catégorie ne porte.
    final catalogue = (await getGlobalCategories()).map((c) => c.name).toList();

    // 3. Créer les plats par batch (max 500 écritures / batch)
    var written = 0;
    var batch = _firestore.batch();
    var ops = 0;
    for (final item in items) {
      final canon = canonicalCategoryName(item.category, catalogue);
      final resolved =
          canon == item.category ? item : item.copyWith(category: canon);
      final ref = _menuItems.doc();
      batch.set(ref, resolved.toMap());
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
