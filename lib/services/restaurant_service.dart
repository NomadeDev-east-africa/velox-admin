import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/restaurant.dart';
import '../models/menu_item.dart';

class RestaurantService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _restaurantsCollection =>
      _firestore.collection('restaurants');
  CollectionReference get _menuItemsCollection =>
      _firestore.collection('menuItems');

  // ==================== RESTAURANTS CRUD ====================

  /// Créer un nouveau restaurant avec compte Firebase Auth
  Future<String> createRestaurant({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String address,
    String? description,
    String? imageUrl,
    double latitude = 11.5721,
    double longitude = 43.1456,
  }) async {
    try {
      // 1. Créer le compte Firebase Auth
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final String restaurantId = userCredential.user!.uid;

      // 2. Créer le document restaurant dans Firestore
      // ✅ TOUT EN CAMELCASE
      final restaurantData = {
        'id': restaurantId,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'description': description,
        'imageUrl': imageUrl,                    // ✅ camelCase
        'isOpen': true,                          // ✅ camelCase
        'isActive': true,                        // ✅ camelCase
        'rating': 0.0,
        'totalOrders': 0,                        // ✅ camelCase
        'totalRevenue': 0.0,                     // ✅ camelCase
        'latitude': latitude,
        'longitude': longitude,
        'createdAt': FieldValue.serverTimestamp(), // ✅ camelCase
        'updatedAt': FieldValue.serverTimestamp(), // ✅ camelCase
        'fcmToken': null,                        // ✅ camelCase
        'fcmTokenUpdatedAt': null,               // ✅ camelCase
      };

      await _restaurantsCollection.doc(restaurantId).set(restaurantData);

      return restaurantId;
    } catch (e) {
      throw Exception('Erreur création restaurant: $e');
    }
  }

  /// Récupérer tous les restaurants (Stream temps réel)
  Stream<List<Restaurant>> getRestaurants() {
    return _restaurantsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Restaurant.fromFirestore(doc)).toList());
  }

  /// Récupérer un restaurant par ID
  Future<Restaurant?> getRestaurant(String id) async {
    try {
      final doc = await _restaurantsCollection.doc(id).get();
      if (doc.exists) {
        return Restaurant.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Erreur récupération restaurant: $e');
    }
  }

  /// Mettre à jour un restaurant
  Future<void> updateRestaurant(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      // ✅ S'assurer que 'updatedAt' est en camelCase
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _restaurantsCollection.doc(id).update(data);
    } catch (e) {
      throw Exception('Erreur mise à jour restaurant: $e');
    }
  }

  /// Supprimer un restaurant
  Future<void> deleteRestaurant(String id) async {
    try {
      // Supprimer tous les menu items associés
      final menuItems = await _menuItemsCollection
          .where('restaurantId', isEqualTo: id)
          .get();

      for (var doc in menuItems.docs) {
        await doc.reference.delete();
      }

      // Supprimer le restaurant
      await _restaurantsCollection.doc(id).delete();

      // Note: Le compte Firebase Auth reste actif
      // Pour le supprimer, il faudrait une Cloud Function
    } catch (e) {
      throw Exception('Erreur suppression restaurant: $e');
    }
  }

  /// Activer/Désactiver un restaurant
  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await updateRestaurant(id, {'isActive': isActive});  // ✅ camelCase
    } catch (e) {
      throw Exception('Erreur toggle activation: $e');
    }
  }

  /// Ouvrir/Fermer un restaurant (toggle manuel — utilisé en repli quand
  /// aucun horaire n'est défini).
  Future<void> toggleOpen(String id, bool isOpen) async {
    try {
      await updateRestaurant(id, {'isOpen': isOpen});      // ✅ camelCase
    } catch (e) {
      throw Exception('Erreur toggle ouverture: $e');
    }
  }

  /// Activer/annuler une **fermeture exceptionnelle**.
  ///
  /// Override prioritaire sur les horaires : si `true`, le restaurant est
  /// fermé maintenant même si l'horaire du moment dit ouvert (rupture,
  /// imprévu…). C'est ce champ que l'app client doit combiner avec les
  /// horaires : `ouvert = isOpenNow(horaires) && !exceptionallyClosed`.
  Future<void> setExceptionalClosure(String id, bool closed) async {
    try {
      await updateRestaurant(id, {'exceptionallyClosed': closed});
    } catch (e) {
      throw Exception('Erreur fermeture exceptionnelle: $e');
    }
  }

  /// Filtrer restaurants par statut
  ///
  /// Le filtre `where` et le tri se font sans `orderBy` côté Firestore afin
  /// d'éviter d'avoir à créer un index composite. Le tri par date décroissante
  /// est appliqué côté client.
  Stream<List<Restaurant>> getRestaurantsByStatus({
    bool? isActive,
    bool? isOpen,
  }) {
    Query query = _restaurantsCollection;

    if (isActive != null) {
      query = query.where('isActive', isEqualTo: isActive);    // ✅ camelCase
    }
    if (isOpen != null) {
      query = query.where('isOpen', isEqualTo: isOpen);        // ✅ camelCase
    }

    return query.snapshots().map((snapshot) {
      final list =
          snapshot.docs.map((doc) => Restaurant.fromFirestore(doc)).toList();
      // Tri décroissant par date de création (du plus récent au plus ancien)
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Rechercher restaurants par nom
  Stream<List<Restaurant>> searchRestaurants(String searchTerm) {
    return _restaurantsCollection
        .orderBy('name')
        .startAt([searchTerm])
        .endAt(['$searchTerm\uf8ff'])
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Restaurant.fromFirestore(doc)).toList());
  }

  // ==================== MENU ITEMS CRUD ====================

  /// Créer un menu item
  Future<String> createMenuItem(MenuItem item) async {
    try {
      final docRef = await _menuItemsCollection.add(item.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Erreur création menu item: $e');
    }
  }

  /// Récupérer les menu items d'un restaurant
  ///
  /// Le tri (catégorie puis nom) est fait côté client pour éviter un index
  /// composite Firestore (`restaurantId` + `category` + `name`).
  Stream<List<MenuItem>> getMenuItems(String restaurantId) {
    return _menuItemsCollection
        .where('restaurantId', isEqualTo: restaurantId)
        .snapshots()
        .map((snapshot) {
      final list =
          snapshot.docs.map((doc) => MenuItem.fromFirestore(doc)).toList();
      list.sort((a, b) {
        final byCategory =
            a.category.toLowerCase().compareTo(b.category.toLowerCase());
        if (byCategory != 0) return byCategory;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return list;
    });
  }

  /// Mettre à jour un menu item
  Future<void> updateMenuItem(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _menuItemsCollection.doc(id).update(data);
    } catch (e) {
      throw Exception('Erreur mise à jour menu item: $e');
    }
  }

  /// Supprimer un menu item
  Future<void> deleteMenuItem(String id) async {
    try {
      await _menuItemsCollection.doc(id).delete();
    } catch (e) {
      throw Exception('Erreur suppression menu item: $e');
    }
  }

  /// Toggle disponibilité d'un menu item
  Future<void> toggleMenuItemAvailability(String id, bool isAvailable) async {
    try {
      await updateMenuItem(id, {'isAvailable': isAvailable});
    } catch (e) {
      throw Exception('Erreur toggle disponibilité: $e');
    }
  }

  // ==================== STATISTIQUES ====================

  /// Récupérer le nombre total de restaurants
  Future<int> getTotalRestaurantsCount() async {
    try {
      final snapshot = await _restaurantsCollection.get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Récupérer le nombre de restaurants actifs
  Future<int> getActiveRestaurantsCount() async {
    try {
      final snapshot =
          await _restaurantsCollection.where('isActive', isEqualTo: true).get();  // ✅ camelCase
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Récupérer le nombre de restaurants ouverts
  Future<int> getOpenRestaurantsCount() async {
    try {
      final snapshot =
          await _restaurantsCollection.where('isOpen', isEqualTo: true).get();    // ✅ camelCase
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
}