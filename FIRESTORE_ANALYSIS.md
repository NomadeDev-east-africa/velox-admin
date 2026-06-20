# Analyse Firestore — Admin Web Nomade253

**Project Firebase:** `nomade253-478a9`
**Framework:** Flutter Web + Firebase Client SDK
**Date analyse:** 2026-05-16

---

## 1. Dashboard & Fonctionnalités Admin

| # | Fonctionnalité | Écran | Statut impl. |
|---|---|---|---|
| 1 | Voir la liste des utilisateurs (clients) | UsersScreen | ✅ READ only |
| 2 | Voir les détails d'un utilisateur | UsersScreen (dialog) | ✅ READ only |
| 3 | Gérer les chauffeurs taxi (CRUD) | DriversListScreen / AddDriverScreen | ✅ CRUD complet |
| 4 | Gérer les livreurs food (CRUD) | LivreursListScreen / AddLivreurScreen | ✅ CRUD complet |
| 5 | Gérer les restaurants (CRUD + toggles) | RestaurantsListScreen / AddRestaurantScreen | ✅ CRUD + toggle isActive/isOpen |
| 6 | Gérer les menus restaurants | RestaurantDetailsScreen | ✅ CRUD menu_items |
| 7 | Modérer les commandes food | OrdersScreen | ✅ READ + annulation admin |
| 8 | Modérer les courses taxi | TaxiRidesScreen | ✅ READ only (pas d'annulation UI) |
| 9 | Carte temps réel (positions drivers) | MapsScreen | ✅ READ stream |
| 10 | Dashboard statistiques | DashboardHome | ✅ READ agrégé |

> **Fonctionnalités absentes / partielles :** bloquer/débloquer utilisateurs (UI read-only),
> annulation des courses taxi (détails sans bouton cancel), audit trail des actions,
> gestion des zones et frais.

---

## 2. Collections Accédées — Opérations par Collection

### 2.1 Collection `admins`

**Chemin :** `/admins/{uid}`

| Opération | Code | Champs concernés |
|-----------|------|-----------------|
| GET par ID | `collection('admins').doc(uid).get()` | `email`, `role`, `isAdmin`, `name` |
| SET (création auto) | `collection('admins').doc(uid).set({...})` | `email`, `role`, `isAdmin`, `name`, `createdAt`, `lastLogin` |

**Champs du document admin :**
```
email        : String
role         : String  → "admin" | "super_admin" | "moderator" | "viewer"
isAdmin      : bool    → true (doublon volontaire pour compatibilité)
name         : String
createdAt    : Timestamp
lastLogin    : Timestamp
```

> ⚠️ La collection `admins` est **distincte** de `users`. L'identité admin est dans `admins/{uid}`,
> pas dans `users/{uid}`. La fonction `isAdmin()` dans les règles doit cibler `/admins/$(request.auth.uid)`.

---

### 2.2 Collection `users`

**Chemin :** `/users/{uid}`

| Opération | Code | Filtres | Champs lus |
|-----------|------|---------|-----------|
| Stream liste complète | `.collection('users').snapshots()` | Aucun (côté client) | `name`/`displayName`, `phone`/`phoneNumber`, `email`, `photoUrl`/`photoURL`, `createdAt` |
| Recherche | Client-side filter | `name`, `phone`, `email` | idem |

> ⚠️ **Aucune écriture** sur `users` depuis l'admin actuellement. Pas de blocage/déblocage implémenté.
> Les champs ont deux variantes (snake_case legacy + camelCase) :
> `name`/`displayName`, `phone`/`phoneNumber`, `photoUrl`/`photoURL`.

---

### 2.3 Collection `drivers`

**Chemin :** `/drivers/{driverId}`

| Opération | Code | Filtres | Champs concernés |
|-----------|------|---------|-----------------|
| Stream liste complète | `.collection('drivers').snapshots()` | Aucun | Tous |
| CREATE | Via `AddDriverScreen` → `.doc(id).set({...})` | — | Voir modèle ci-dessous |
| DELETE | `.collection('drivers').doc(id).delete()` | — | Document entier |
| UPDATE | `TODO` (bouton Edit présent, pas implémenté) | — | — |

**Champs du modèle Driver (camelCase) :**
```
id, name, email, phone, photoUrl
vehicleType, licensePlate, licenseNumber
vehicleBrand, vehicleModel, vehicleYear, vehicleColor
isActive, isOnline, isAvailable
currentLocation: { latitude, longitude, updatedAt }
totalRides, rating, totalEarnings, totalRatings
createdAt, lastActiveAt, updatedAt
fcmToken, tokenUpdatedAt
```

---

### 2.4 Collection `livreurs`

**Chemin :** `/livreurs/{livreurId}`

| Opération | Code | Champs concernés |
|-----------|------|-----------------|
| Stream liste complète | `.collection('livreurs').snapshots()` | Tous |
| CREATE | Via `AddLivreurScreen` | Voir modèle |
| DELETE | `.doc(id).delete()` | Document entier |

**Champs du modèle Livreur (camelCase) :**
```
id, name, phone, email, photoUrl
licensePlate, vehicleBrand, vehicleModel, vehicleYear, vehicleColor, vehicleType
isActive, isOnline, isAvailable
currentLocation (GeoPoint-like), currentOrderId
totalDeliveries, rating, totalEarnings
createdAt, lastSeen, updatedAt
fcmToken, fcmTokenUpdatedAt
```

---

### 2.5 Collection `restaurants`

**Chemin :** `/restaurants/{restaurantId}`

| Opération | Code | Filtres | Champs concernés |
|-----------|------|---------|-----------------|
| Stream liste complète | `.orderBy('createdAt', descending: true).snapshots()` | — | Tous |
| Stream filtré | `.where('isActive',...).where('isOpen',...)` | isActive, isOpen | — |
| Recherche par nom | `.orderBy('name').startAt([term]).endAt([term+])` | name | — |
| CREATE | `RestaurantService.createRestaurant()` | — | Voir ci-dessous |
| GET by ID | `.doc(id).get()` | — | Tous |
| UPDATE | `.doc(id).update(data)` | — | `isActive`, `isOpen`, `updatedAt` |
| DELETE | `.doc(id).delete()` (+ cascade menu_items) | — | Document entier |
| Toggle isActive | `.update({'isActive': bool})` | — | `isActive`, `updatedAt` |
| Toggle isOpen | `.update({'isOpen': bool})` | — | `isOpen`, `updatedAt` |

**Champs du document restaurant (camelCase) :**
```
id, name, email, phone, address, description, imageUrl
isOpen, isActive
rating, totalOrders, totalRevenue
latitude, longitude
createdAt, updatedAt
fcmToken, fcmTokenUpdatedAt
```

---

### 2.6 Collection `menu_items`

**Chemin :** `/menu_items/{itemId}`

| Opération | Code | Filtres |
|-----------|------|---------|
| Stream par restaurant | `.where('restaurantId', isEqualTo: id).orderBy('category').orderBy('name')` | restaurantId |
| CREATE | `.add(item.toMap())` | — |
| UPDATE | `.doc(id).update(data)` | — |
| DELETE | `.doc(id).delete()` | — |
| Toggle disponibilité | `.update({'isAvailable': bool})` | — |

**Champs (camelCase) :**
```
id, restaurantId, name, description, price
imageUrl, category, isAvailable, preparationTime
createdAt, updatedAt
```

---

### 2.7 Collection `orders`

**Chemin :** `/orders/{orderId}`

| Opération | Code | Filtres |
|-----------|------|---------|
| Stream liste | `.orderBy('createdAt', descending: true).snapshots()` | — |
| Filtre statut | Client-side `.where(status == filterStatus)` | status |
| Recherche | Client-side | customerName, restaurantName, deliveryAddress |
| **ANNULATION ADMIN** | `.doc(id).update({'status': 'cancelled', 'updatedAt': ...})` | — |

**Statuts orders :** `pending` → `ready` → `delivering` → `completed` / `cancelled`

**Champs lus :**
```
status, customerName, restaurantName, deliveryAddress
customerPhone, total, subtotal, deliveryFee
paymentMethod, deliveryDriverName
createdAt, updatedAt
```

> ⚠️ L'`updatedAt` est écrit en `DateTime.now().toIso8601String()` (String ISO),
> **pas en `FieldValue.serverTimestamp()`**. Incohérence avec les autres collections.
> Fichier : `lib/screens/orders/orders_screen.dart` ligne 401.

---

### 2.8 Collection `taxi_rides`

**Chemin :** `/taxi_rides/{rideId}`

| Opération | Code | Filtres |
|-----------|------|---------|
| Stream liste | `.orderBy('requestedAt', descending: true).snapshots()` | — |
| Filtre statut | Client-side | status |
| Recherche | Client-side | userName, driverName, userPhone |
| UPDATE | **Non implémenté** (UI détail sans bouton annulation) | — |

**Statuts taxi_rides :** `requested` → `accepted` → `arriving` → `arrived` → `started` → `completed` / `cancelled`

**Champs lus :**
```
userName, userPhone, userPhotoUrl, userId
driverName, driverPhone, driverId
vehicleType, paymentMethod, paymentStatus
estimatedFare, finalFare, distance, estimatedDuration
status, cancellationReason, cancelledBy
requestedAt, acceptedAt, arrivedAt, startedAt, completedAt, cancelledAt
userRating, driverRating
```

---

### 2.9 Collection `test_connection` (DEBUG)

**Chemin :** `/test_connection/test`

| Opération | Contexte |
|-----------|---------|
| SET + GET + DELETE | Exécuté à **chaque tentative de connexion admin** (code debug) |

> ⚠️ **À supprimer en production.** Cette collection de debug ouvre une faille si les règles
> l'autorisent. Fichier : `lib/screens/auth/admin_login_screen.dart` lignes 92-107.

---

## 3. Rôles et Permissions

### 3.1 Identification de l'admin

```
Collection : admins/{uid}  (PAS users/{uid})
Champ role : "admin" | "super_admin" | "moderator" | "viewer"
Champ isAdmin : bool (doublon de sécurité)
```

**Logique de vérification côté client (`admin_login_screen.dart` L.196) :**
```dart
if (role != 'admin' && !isAdminFlag) {
  // Refusé → signOut
}
```

Le code vérifie `role == 'admin'` **OU** `isAdmin == true`. Un document avec `isAdmin: true`
sans role valide passe quand même.

### 3.2 Niveaux de rôles définis (`constants.dart`)

```dart
class AdminRole {
  static const String superAdmin = 'super_admin';
  static const String admin     = 'admin';
  static const String moderator = 'moderator';
  static const String viewer    = 'viewer';
}
```

> ⚠️ **Ces rôles sont définis mais NON utilisés** dans l'application. Toute la logique de
> restriction est binaire : admin ou non. Il n'existe pas de vérification différenciée
> `superAdmin` vs `moderator` dans les écrans.

### 3.3 Flux d'authentification

```
1. signInWithEmailAndPassword(email, password)
2. Cherche admins/{uid} → admin/{uid} → administrators/{uid} → users/{uid}
3. Vérifie role == 'admin' OU isAdmin == true
4. Si OK → DashboardScreen
5. Si NON → signOut + message d'erreur
```

---

## 4. Vue d'Ensemble des Écrans Admin

| Écran | Collections lues | Collections écrites | Requêtes Firestore |
|-------|-----------------|--------------------|--------------------|
| `AdminLoginScreen` | `admins`, `admin`, `administrators`, `users` | `admins`, `test_connection` | `.doc(uid).get()` |
| `DashboardHome` | `restaurants`, `drivers`, `orders`, `users` | — | Agrégats `.get()` |
| `DriversListScreen` | `drivers` | `drivers` (delete) | `.snapshots()` |
| `AddDriverScreen` | — | `drivers` | `.doc(id).set({...})` |
| `LivreursListScreen` | `livreurs` | `livreurs` (delete) | `.snapshots()` |
| `AddLivreurScreen` | — | `livreurs` | `.doc(id).set({...})` |
| `RestaurantsListScreen` | `restaurants` | `restaurants` (toggles) | `.orderBy('createdAt').snapshots()` |
| `AddRestaurantScreen` | — | `restaurants` + **Firebase Auth** | `.doc(uid).set({...})` |
| `RestaurantDetailsScreen` | `restaurants`, `menu_items` | `restaurants`, `menu_items` | `.where('restaurantId').snapshots()` |
| `OrdersScreen` | `orders` | `orders` (cancel) | `.orderBy('createdAt').snapshots()` |
| `TaxiRidesScreen` | `taxi_rides` | — | `.orderBy('requestedAt').snapshots()` |
| `UsersScreen` | `users` | — | `.snapshots()` |
| `MapsScreen` | `drivers` / `livreurs` | — | Stream positions |

---

## 5. Points Critiques

### 5.1 🚨 BUG CRITIQUE — Création Restaurant

**Fichier :** `lib/services/restaurant_service.dart` ligne 33

```dart
final UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(email, password);
```

`createUserWithEmailAndPassword` sur le **Client SDK** signe immédiatement l'utilisateur créé
(le restaurant) → **l'admin est déconnecté** lors de la création d'un restaurant.
Les règles Firestore détectent ensuite `request.auth.uid` comme étant le restaurant et non l'admin.

**Solution obligatoire → Cloud Function :**
```javascript
// functions/src/index.ts
exports.createRestaurant = functions.https.onCall(async (data, context) => {
  // Vérifier que l'appelant est admin
  const adminDoc = await admin.firestore().collection('admins').doc(context.auth.uid).get();
  if (!adminDoc.exists || adminDoc.data().role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Not admin');
  }
  // 1. Créer le compte Auth sans sign-in (Admin SDK)
  const userRecord = await admin.auth().createUser({ email: data.email, password: data.password });
  // 2. Créer le doc Firestore
  await admin.firestore().collection('restaurants').doc(userRecord.uid).set({...data});
  return { restaurantId: userRecord.uid };
});
```

---

### 5.2 ⚠️ Données sensibles visibles

- **`fcmToken`** est stocké dans `drivers`, `livreurs`, `restaurants` et **lisible** depuis
  l'admin web → risque d'envoi de notifications frauduleuses si le token est exposé.
- Les mots de passe des restaurants transitent par le Client SDK lors de la création.

---

### 5.3 ⚠️ Absence d'audit trail

Aucune action admin n'est tracée dans Firestore.

**Implémentation minimale recommandée :**
```dart
Future<void> _logAdminAction(String action, String targetId) async {
  await FirebaseFirestore.instance.collection('admin_audit').add({
    'adminUid': FirebaseAuth.instance.currentUser!.uid,
    'action': action,       // ex: 'delete_driver', 'cancel_order'
    'targetId': targetId,
    'timestamp': FieldValue.serverTimestamp(),
  });
}
```

---

### 5.4 ⚠️ Filtrage client-side non sécurisé

`users`, `drivers`, `livreurs`, `orders`, `taxi_rides` sont tous chargés **en entier** puis
filtrés côté client. À grande échelle → problème de performance et de coût (lectures inutiles).
Migrer vers des requêtes Firestore avec `.where()` et `.orderBy()` côté serveur.

---

### 5.5 ⚠️ `updatedAt` incohérent dans `orders`

**Fichier :** `lib/screens/orders/orders_screen.dart` ligne 401

```dart
// ❌ Actuel — String ISO, pas un Timestamp Firestore
'updatedAt': DateTime.now().toIso8601String()

// ✅ Corriger en
'updatedAt': FieldValue.serverTimestamp()
```

---

### 5.6 ⚠️ Collection `test_connection` en production

Le code de debug (login screen L.92-107) écrit dans `test_connection` à **chaque login**.
Cette collection doit être bloquée dans les règles et le code supprimé avant la mise en production.

---

## 6. Règles Firestore Proposées

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ── Fonctions utilitaires ──────────────────────────────────

    function isAuthenticated() {
      return request.auth != null;
    }

    // L'admin est identifié dans la collection 'admins', PAS 'users'
    function isAdmin() {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'admin';
    }

    function isSuperAdmin() {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
        get(/databases/$(database)/documents/admins/$(request.auth.uid)).data.role == 'super_admin';
    }

    function isAdminOrSuperAdmin() {
      return isAdmin() || isSuperAdmin();
    }

    // ── Collection : admins ────────────────────────────────────
    match /admins/{uid} {
      allow read: if isAuthenticated() && request.auth.uid == uid;
      allow write: if isAdminOrSuperAdmin();
    }

    // ── Collection : users ─────────────────────────────────────
    match /users/{userId} {
      allow read:   if isAuthenticated() && (request.auth.uid == userId || isAdminOrSuperAdmin());
      allow create: if isAuthenticated() && request.auth.uid == userId;
      allow update: if isAuthenticated() && (request.auth.uid == userId || isAdminOrSuperAdmin());
      allow delete: if isSuperAdmin();
    }

    // ── Collection : drivers ───────────────────────────────────
    match /drivers/{driverId} {
      allow read:   if isAuthenticated() &&
                       (request.auth.uid == driverId || isAdminOrSuperAdmin());
      allow create: if isAdminOrSuperAdmin();
      allow update: if isAuthenticated() &&
                       (request.auth.uid == driverId || isAdminOrSuperAdmin());
      allow delete: if isAdminOrSuperAdmin();
    }

    // ── Collection : livreurs ──────────────────────────────────
    match /livreurs/{livreurId} {
      allow read:   if isAuthenticated() &&
                       (request.auth.uid == livreurId || isAdminOrSuperAdmin());
      allow create: if isAdminOrSuperAdmin();
      allow update: if isAuthenticated() &&
                       (request.auth.uid == livreurId || isAdminOrSuperAdmin());
      allow delete: if isAdminOrSuperAdmin();
    }

    // ── Collection : restaurants ───────────────────────────────
    // CREATE doit passer par Cloud Function (bug createUserWithEmailAndPassword)
    match /restaurants/{restaurantId} {
      allow read:   if isAuthenticated() &&
                       (request.auth.uid == restaurantId || isAdminOrSuperAdmin());
      allow create: if isAdminOrSuperAdmin();
      allow update: if isAuthenticated() &&
                       (request.auth.uid == restaurantId || isAdminOrSuperAdmin());
      allow delete: if isAdminOrSuperAdmin();
    }

    // ── Collection : menu_items ────────────────────────────────
    match /menu_items/{itemId} {
      allow read:   if isAuthenticated();
      allow create: if isAdminOrSuperAdmin() ||
                       (isAuthenticated() &&
                        request.auth.uid == request.resource.data.restaurantId);
      allow update: if isAdminOrSuperAdmin() ||
                       (isAuthenticated() &&
                        request.auth.uid == resource.data.restaurantId);
      allow delete: if isAdminOrSuperAdmin() ||
                       (isAuthenticated() &&
                        request.auth.uid == resource.data.restaurantId);
    }

    // ── Collection : orders ────────────────────────────────────
    match /orders/{orderId} {
      allow read:   if isAuthenticated() && isAdminOrSuperAdmin();
      allow create: if isAuthenticated();
      allow update: if isAdminOrSuperAdmin() ||
                       (isAuthenticated() &&
                        request.auth.uid == resource.data.userId &&
                        resource.data.status == 'pending');
      allow delete: if isSuperAdmin();
    }

    // ── Collection : taxi_rides ────────────────────────────────
    match /taxi_rides/{rideId} {
      allow read:   if isAuthenticated() &&
                       (request.auth.uid == resource.data.userId ||
                        request.auth.uid == resource.data.driverId ||
                        isAdminOrSuperAdmin());
      allow create: if isAuthenticated();
      allow update: if isAuthenticated() &&
                       (request.auth.uid == resource.data.userId ||
                        request.auth.uid == resource.data.driverId ||
                        isAdminOrSuperAdmin());
      allow delete: if isSuperAdmin();
    }

    // ── Collection : admin_audit (à créer) ────────────────────
    match /admin_audit/{logId} {
      allow read:   if isSuperAdmin();
      allow create: if isAdminOrSuperAdmin();
      allow update, delete: if false; // Logs immuables
    }

    // ── Collection : test_connection (BLOQUER EN PROD) ─────────
    match /test_connection/{docId} {
      allow read, write: if false;
    }

    // ── Tout le reste : refusé par défaut ─────────────────────
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## 7. Résumé des Actions Requises

| Priorité | Action | Fichier concerné |
|----------|--------|-----------------|
| 🚨 URGENT | Migrer `createRestaurant` vers Cloud Function | `lib/services/restaurant_service.dart` L.33 |
| 🚨 URGENT | Déployer les règles Firestore ci-dessus | Firebase Console |
| ⚠️ IMPORTANT | Supprimer le code `test_connection` | `lib/screens/auth/admin_login_screen.dart` L.92-107 |
| ⚠️ IMPORTANT | Corriger `updatedAt` → `FieldValue.serverTimestamp()` | `lib/screens/orders/orders_screen.dart` L.401 |
| 📋 RECOMMANDÉ | Implémenter `admin_audit` collection | Nouveau service |
| 📋 RECOMMANDÉ | Ajouter blocage/déblocage users (toggle `isActive`) | `lib/screens/users/users_screen.dart` |
| 📋 RECOMMANDÉ | Implémenter annulation des courses taxi | `lib/screens/taxi/taxi_rides_screen.dart` |
| 📋 RECOMMANDÉ | Différencier les rôles (`moderator` = lecture seule) | `lib/screens/dashboard/dashboard_screen.dart` |
| 📋 RECOMMANDÉ | Migrer les filtres client-side vers requêtes Firestore | Tous les écrans liste |
