# Rapport de session — Corrections & Améliorations
**Projet :** Nomade 253 — Admin Panel  
**Date :** 06 Avril 2026  
**Outils utilisés :** MCP Dart (analyse statique), MCP Firebase (Firestore, Storage)

---

## 1. Analyse initiale

### Dart — Résultats de l'analyse statique
L'analyse via `mcp__dart__analyze_files` a détecté **31 problèmes** :
- 3 warnings (severity 2) — erreurs potentielles
- 28 dépréciations (severity 3) — APIs obsolètes

### Firebase — Collections Firestore
12 collections identifiées : `admins`, `drivers`, `livreurs`, `restaurants`, `orders`,
`taxi_rides`, `menu_items`, `users`, `driver_notifications`, `livreur_notifications`,
`restaurant_notifications`, `user_notifications`

**Anomalies détectées dans les données :**
- Champ `items` des orders stocké comme string `"[[object Object]]"` au lieu d'un vrai Array (bug côté app mobile)
- `currentLocation` de certains documents stocké `"[Object]"` (bug de sérialisation côté app mobile)
- 4 orders bloquées en statut `pending` sans livreur assigné
- 1 order bloquée en `delivering` non terminée
- 2 taxi_rides en `requested` sans chauffeur depuis fin mars

---

## 2. Corrections Dart

### 2.1 Imports inutilisés supprimés
| Fichier | Import supprimé |
|---|---|
| `screens/drivers/drivers_list_screen.dart` | `package:firebase_auth/firebase_auth.dart` |
| `screens/restaurants/add_restaurant_screen.dart` | `package:flutter/foundation.dart` |

### 2.2 Champ mort supprimé
| Fichier | Champ supprimé |
|---|---|
| `screens/map/maps_screen.dart` | `double _currentZoom = 14.0` (jamais utilisé) |

### 2.3 Dépréciations corrigées
| API dépréciée | Remplacement | Fichiers concernés |
|---|---|---|
| `.withOpacity(x)` | `.withValues(alpha: x)` | `constants.dart`, `main.dart`, `admin_login_screen.dart`, `dashboard_home.dart`, `dashboard_screen.dart`, `add_livreur_screen.dart`, `livreurs_list_screen.dart`, `maps_screen.dart`, `add_restaurant_screen.dart`, `restaurants_list_screen.dart`, `restaurant_details_screen.dart` |
| `MaterialStateProperty.all()` | `WidgetStateProperty.all()` | `main.dart` |
| `value:` (DropdownButtonFormField) | `initialValue:` | `screens/drivers/add_driver_screen.dart` |
| `activeColor:` (Switch) | `activeThumbColor:` | `add_driver_screen.dart`, `add_livreur_screen.dart` |

**Résultat final : 0 erreur / 0 warning après corrections.**

---

## 3. Nouveaux écrans créés

### 3.1 Écran Commandes — `screens/orders/orders_screen.dart`
- Liste temps réel des commandes (`orders`) via StreamBuilder
- Filtres par statut : tous / en attente / prête / en livraison / terminée / annulée
- Recherche par nom client, restaurant, adresse
- Vue desktop (DataTable) + vue mobile (Cards)
- Détail complet en dialog
- Action d'annulation d'une commande

### 3.2 Écran Courses Taxi — `screens/taxi/taxi_rides_screen.dart`
- Liste temps réel des courses (`taxi_rides`)
- Filtres par statut : tous / demandée / acceptée / en cours / terminée / annulée
- Recherche par passager, chauffeur, téléphone
- Vue desktop (DataTable) + vue mobile (Cards)
- Détail complet en dialog avec tarifs, distance, durée

### 3.3 Écran Utilisateurs — `screens/users/users_screen.dart`
- Liste temps réel des utilisateurs (`users`)
- Recherche par nom, téléphone, email
- Vue desktop (DataTable) + vue mobile (Cards)
- Détail en dialog

### 3.4 Intégration dans le Dashboard
- `sidebar.dart` : 3 nouveaux items ajoutés (Commandes, Courses Taxi, Utilisateurs)
- `dashboard_screen.dart` : routes et titres ajoutés pour les 3 nouveaux écrans

---

## 4. Bugs d'exécution corrigés

### 4.1 TypeError — Timestamp vs String
**Erreur :**
```
TypeError: Instance of 'Timestamp': type 'Timestamp' is not a subtype of type 'String'
```
**Cause :** Firestore stocke les dates soit comme `Timestamp` natif, soit comme `String` ISO 8601
selon l'app qui a écrit le document. Le code appelait `DateTime.parse()` qui n'accepte que les strings.

**Correction :** Helper `_parseDate()` ajouté dans les 3 nouveaux écrans :
```dart
DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
```
**Fichiers corrigés :** `orders_screen.dart`, `taxi_rides_screen.dart`, `users_screen.dart`

---

### 4.2 RenderFlex overflow — Livreurs (subtitle mobile)
**Erreur :** `A RenderFlex overflowed by 5.3 pixels on the right`  
**Cause :** `Row(Icon + Text(licensePlate))` dans le subtitle du ListTile mobile sans contrainte de largeur.  
**Correction :** Text enveloppé dans `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))`  
**Fichier :** `screens/livreur/livreurs_list_screen.dart`

---

### 4.3 RenderFlex overflow — Livreurs DataTable (statut)
**Erreur :** `A RenderFlex overflowed by 5.3–32 pixels on the right`  
**Cause :** Badge statut avec `Container(padding: horizontal 8) + Row + Text` — trop large
pour la colonne DataTable (contrainte de 74.9px).  
**Correction :** Container badge supprimé, remplacé par un simple `Row(dot 8px + SizedBox(4) + Text(11px))`  
**Fichier :** `screens/livreur/livreurs_list_screen.dart`

---

### 4.4 RenderFlex overflow — Courses Taxi DataTable (statut)
**Erreur :** `A RenderFlex overflowed by 31–32 pixels on the right`  
**Cause :** Même problème que livreurs — badge Container trop large pour la colonne (42.9px).  
**Correction :** Même fix — `Row(dot + Text(11px))` sans Container ni padding  
**Fichier :** `screens/taxi/taxi_rides_screen.dart`

---

### 4.5 Images Firebase Storage — CORS (statusCode: 0)
**Erreur :**
```
HTTP request failed, statusCode: 0,
https://firebasestorage.googleapis.com/...
```
**Cause :** Le `cors.json` Firebase Storage n'incluait pas les origines localhost du serveur
de développement Flutter Web (port dynamique).

**Correction en deux parties :**

**A) Code — gestion gracieuse des erreurs image :**  
`CircleAvatar` avec `backgroundImage: NetworkImage(...)` remplacé par `Image.network` avec `errorBuilder`
dans `livreurs_list_screen.dart` (mobile + desktop). Icône de fallback affichée si l'image échoue.

**B) Configuration CORS Firebase Storage :**  
`cors.json` mis à jour avec `"origin": ["*"]` pour le développement.  
Commande à exécuter pour appliquer :
```bash
gsutil cors set cors.json gs://nomade253-478a9.firebasestorage.app
```

---

## 5. Carte Interactive — Refonte complète

### Avant
- Marqueurs statiques uniquement (points d'intérêt, restaurants hardcodés)
- Aucune donnée temps réel

### Après
- **Suppression** de tous les marqueurs statiques (POI, quartiers, restaurants)
- **Stream temps réel** depuis Firestore : livreurs + chauffeurs `isOnline: true`
- **Marqueur moto orange** pour les livreurs
- **Marqueur voiture bleu** pour les chauffeurs
- **Point de statut** : vert = disponible / orange ou bleu = occupé
- **Compteur** en temps réel dans le header : `X livreur(s) • Y chauffeur(s) en ligne`
- **Tap sur marker** → bottom sheet avec nom, téléphone, plaque, statut, coordonnées GPS
- **Double format `currentLocation`** supporté :
  - `GeoPoint` natif Firestore (livreurs)
  - `Map {latitude, longitude}` (drivers) — voir note ci-dessous
- **Offset angulaire** pour les marqueurs superposés : si N personnes sont au même endroit,
  elles sont réparties sur un cercle de ~20m autour du point réel — chaque marker reste
  cliquable séparément avec ses vraies coordonnées affichées dans le bottom sheet
- **Légende épurée** : Livreur / Chauffeur / Disponible / Occupé

---

## 6. Note importante — App Driver à corriger

> **Problème :** Dans l'app mobile Driver, le champ `currentLocation` est sauvegardé
> comme une `Map` Dart `{latitude: double, longitude: double}` au lieu d'un **GeoPoint Firestore natif**.
>
> **Impact actuel :** L'admin gère ce double format côté lecture. Mais pour pouvoir utiliser
> les **requêtes géospatiales Firestore** à l'avenir (ex: trouver les chauffeurs dans un rayon X),
> il faut impérativement que tous les documents utilisent le GeoPoint natif.
>
> **Correction à faire dans l'app Driver** (service de localisation) :
> ```dart
> // ❌ Actuel — stockage comme Map
> 'currentLocation': {
>   'latitude': position.latitude,
>   'longitude': position.longitude,
> }
>
> // ✅ À corriger — stockage comme GeoPoint Firestore
> import 'package:cloud_firestore/cloud_firestore.dart';
>
> 'currentLocation': GeoPoint(position.latitude, position.longitude)
> ```
>
> Une fois corrigé dans l'app Driver, le `_parseLocation()` de la carte admin
> continuera à fonctionner (il gère les deux formats) — **pas de changement nécessaire
> côté admin**.

---

## Résumé chiffré

| Catégorie | Nombre |
|---|---|
| Fichiers modifiés | 18 |
| Nouveaux fichiers créés | 3 |
| Warnings Dart éliminés | 31 → 0 |
| Bugs d'exécution corrigés | 5 |
| Nouveaux écrans ajoutés | 3 |
| Collections Firestore couvertes par l'admin | 9 / 12 |

---

*Généré le 06 Avril 2026*
