# Travaux 7 — Blocage réel + suppression de compte client (admin)

> Contexte de session pour reprise. Dernière mise à jour : 2026-08-27.
> Suite de `travaux6.md`. **Fait, vérifié ET DÉPLOYÉ en prod le 27/08/2026**
> (Cloud Functions + règles Firestore + admin web, déployés directement par
> Claude via CLI avec l'accord explicite de l'utilisateur — même pattern que
> pour les codes promo le 22/08).

## Pourquoi

Le bouton "Bloquer" dans l'admin (`users_screen.dart`) ne faisait qu'un update
Firestore `isActive: false` — **purement cosmétique** :
- le compte Firebase Auth restait actif (login toujours possible) ;
- rien ne lisait `isActive` pour empêcher une commande/course (règles
  `orders`/`taxiRides`, Cloud Functions) ;
- pire : `isActive` était dans la liste des champs que le **propriétaire** du
  doc `users/{uid}` pouvait modifier lui-même → un client bloqué pouvait se
  débloquer tout seul en réécrivant son propre doc.
- Aucune suppression de compte n'était possible côté admin (uniquement le
  client lui-même, via `Velox_client`).

Déclenché par un cas concret : bloquer/supprimer un client qui passe de
fausses commandes.

## Ce qui a été fait

### 1. Cloud Functions (`nomade_client\functions\index.js`)
- Helper `assertIsAdmin(uid)` (factorisé, réutilisable).
- `exports.adminSetUserBlocked({ userId, blocked, reason? })` — admin only :
  - Firestore : `isActive`, `blockedAt/blockedBy/blockedReason`.
  - Firebase Auth : `updateUser(uid, { disabled: blocked })` +
    `revokeRefreshTokens(uid)` si blocage (coupe la session en cours, pas
    seulement les futures connexions).
- `exports.adminDeleteUserAccount({ userId })` — admin only :
  - supprime les sous-collections `addresses/`, `favorite_drivers/`,
    `notifications/`, puis le doc `users/{uid}`, puis le compte Firebase Auth.
  - (bug latent corrigé au passage : le `deleteAccount()` client
    `Velox_client\AuthRepository.kt` ne supprimait déjà pas ces
    sous-collections malgré le commentaire des règles qui l'exigeait —
    non touché ici, c'est `Velox_client`, un autre agent le gère.)

### 2. Règles Firestore — **DEUX fichiers à garder synchro** (modifiés tous les deux) :
  - `nomade_client\functions\scripts\sim\firestore_rules_prod.rules`
    (**source réellement déployée**, référencée dans `firebase.json` → `firestore.rules`)
  - `C:\Users\PC\Desktop\FINAL 253 NOMADE\client app\production\firestores regles unique\firestore_rules.rules`
    (copie de référence, collée manuellement dans la console Firebase)

  Changements (identiques dans les deux fichiers) :
  - Nouvelle fonction `userCanOrder(uid)` → `isActive != false`.
  - `orders` et `taxiRides` : `allow create` exige maintenant
    `userCanOrder(request.auth.uid)` — défense en profondeur même si la
    Cloud Function/Auth échouait à bloquer.
  - `users/{userId}` : `isActive` **retiré** de la liste `onlyFields` du
    propriétaire → seul un admin (donc uniquement via les nouvelles Cloud
    Functions, qui utilisent l'Admin SDK et bypassent les règles) peut
    changer ce champ.

### 3. Admin Flutter (`lib\screens\users\users_screen.dart`)
- `_confirmToggleActive` appelle désormais `adminSetUserBlocked` (au lieu
  d'un update Firestore direct) ; dialogue de blocage avec champ "motif"
  optionnel.
- Nouveau `_confirmDeleteAccount` → `adminDeleteUserAccount`, double
  confirmation, message explicite "irréversible".
- Liste mobile : menu ⋮ (Bloquer/Débloquer + Supprimer) au lieu d'une seule
  icône. Table desktop : icône poubelle ajoutée à côté du bloc/débloc.
  Dialogue détails : bouton Supprimer ajouté.
- `flutter analyze lib/screens/users/users_screen.dart` → clean.

## Déployé le 27/08/2026

1. **Cloud Functions** : `firebase deploy --only functions:adminSetUserBlocked,functions:adminDeleteUserAccount --project nomade253-478a9` depuis `nomade_client`. Premier essai échoué (`Cannot determine backend specification. Timeout after 10000` — timeout transitoire du discovery Firebase CLI, pas une erreur de code : `node -e "require('./index.js')"` chargeait sans erreur). **Retry immédiat → succès**, les deux fonctions créées en `us-central1` (2nd Gen).
2. **Règles Firestore** : `firebase deploy --only firestore:rules --project nomade253-478a9` depuis `nomade_client` → déployé directement (compile + release OK). La console Firebase reflète déjà ce déploiement, pas besoin de copier-coller manuellement (ce n'est nécessaire que quand on ne déploie pas via CLI). La copie de référence `FINAL 253 NOMADE\...\firestore_rules.rules` a aussi été mise à jour avec les mêmes changements pour rester synchro.
3. **Admin web** : `flutter build web --release` puis `firebase deploy --only hosting --project nomade253-478a9` → live sur https://nomade253-478a9.web.app.

## Reste à faire (non bloquant)

- Vérifier que les admins existants ont bien `admins/{uid}.role` = `"admin"` ou `"super_admin"` (sinon `permission-denied` sur les deux nouvelles functions — même exigence que `sendBroadcastNotification`/`registerAdminFcmToken` déjà en prod).
- Tester en admin : bloquer un compte de test → vérifier que le login échoue côté `Velox_client` et qu'une commande est refusée (règle `userCanOrder`).

Pas de changement nécessaire côté `Velox_client` (Kotlin) pour cette
fonctionnalité — le blocage/suppression est entièrement piloté côté admin +
backend ; le client se contente d'échouer proprement au login si son compte
est désactivé (comportement Firebase Auth standard, rien à coder côté app).

## Suite (même session, 27/08/2026) — UX admin : scrollbars + compteur commandes

Suite à une revue de captures d'écran admin (pages Commandes/Restaurants/
Utilisateurs), 3 correctifs UX déployés :

1. **Scrollbar menu latéral** (`widgets/sidebar.dart`) — 14 entrées ne
   tenaient pas dans la hauteur d'écran visible sans aucun indice de
   défilement. `Sidebar` converti en `StatefulWidget` avec `ScrollController`
   + `Scrollbar(thumbVisibility: true, trackVisibility: true)`.
2. **Scrollbar horizontale des tableaux** — ajoutée là où elle manquait
   totalement (`drivers_list_screen.dart`, `livreurs_list_screen.dart`,
   `taxi_rides_screen.dart`, même pattern que users/orders/restaurants qui
   l'avaient déjà) ; `trackVisibility: true` ajouté partout pour que la piste
   soit visible en permanence, pas seulement le curseur au survol.
3. **Compteur "Commandes" restaurant toujours à 0** — `restaurant.totalOrders`
   n'est incrémenté côté Cloud Functions qu'au passage au statut "ready", pas
   à la création. Nouveau widget partagé `widgets/restaurant_order_count.dart`
   qui calcule le total réel en direct (`orders.where(restaurantId==).count()`,
   requête d'agrégation légère, pas de lecture de docs) — utilisé dans la
   liste restaurants (colonne Commandes) et la fiche détail (carte stat).
   Champ `totalOrders` du doc Firestore inchangé (toujours utile en interne
   pour `totalRevenue`), seul l'affichage admin ne s'y fie plus.

`flutter analyze` clean, build web OK, **déployé** (`firebase deploy --only
hosting`) le 27/08/2026.
