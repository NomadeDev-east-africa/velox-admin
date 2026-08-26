# Travaux 6 — Codes promo (admin → backend → client) + bannières admin + tarifs VTC

> Contexte de session pour reprise. Dernière mise à jour : 2026-08-26.
> Suite de `travaux5.md` (notifications). Cinq fonctionnalités livrées :
> 1. **Code promo** créé depuis l'admin, appliqué par le client au checkout sur
>    (sous-total nourriture + frais de livraison) — **déployé en prod (functions +
>    règles + admin) le 22/08/2026**.
> 2. **Bannières admin** (texte ou image) pour le carrousel promo de l'accueil app
>    client, remplaçant les bannières codées en dur — **admin fait et déployé**,
>    client Kotlin pas encore fait (prompt prêt).
> 3. **Tarifs VTC admin** (config `config/taxiPricing`, tarif taxi Standard/Confort
>    pilotable depuis l'admin) — **admin fait et déployé le 23/08/2026**, backend +
>    apps clientes déjà prêts à lire ce document (fait avant cette session).
> 4. **Historique de notifications persistant** (`users/{uid}/notifications`) —
>    backend (Cloud Functions + règles + index) **fait et déployé le 26/08/2026**,
>    suite à un prompt reçu de l'agent iOS. Retour iOS écrit, prompt Android
>    Kotlin écrit — client pas encore fait.
> 5. **Fix : annulation admin ne libère pas le livreur** — corrigé et déployé
>    (commit + push) le 26/08/2026.

## Écosystème concerné cette session

| App | Techno | Chemin | Rôle |
|---|---|---|---|
| **Admin** | Flutter web | `NOMADE_ADMIN_COMPLETE` (projet courant) | CRUD codes promo — **fait cette session** |
| **Cloud Functions** | Node 24 (Gen2) | `C:\Users\PC\StudioProjects\nomade_client\functions\index.js` | Validation + application serveur — **fait cette session** |
| **Client** | Android Kotlin | `C:\Users\PC\StudioProjects\Velox_client` | UI checkout + envoi du code — **PAS fait ici**, prompt prêt : `Velox_client\PROMPT_PROMO_CODE_CLIENT.md` (un autre agent Claude Code s'en charge) |

⚠️ Rappel important découvert cette session : le dossier client actif est
**`Velox_client`** (Kotlin/Android natif, `build.gradle.kts`), PAS `nomade_client`
(qui ne contient que les Cloud Functions partagées) ni `Velox_Client-main`/
`Velox_Client-IOS` (autres dossiers présents dans StudioProjects, pas confirmés actifs
par l'utilisateur). Les mémoires précédentes se contredisaient là-dessus — c'est
`Velox_client` qui fait foi désormais.

## Règles métier validées avec l'utilisateur

- Type de réduction : **pourcentage OU montant fixe**, au choix à la création du code.
- Portée : **global** (tous restaurants) OU **restaurant précis**, au choix.
- Règles supportées : **date d'expiration** (optionnelle) + **1 utilisation max par
  client** (toujours appliqué, pas une option togglable).
- Pas retenu (volontairement, YAGNI) : limite d'utilisation totale, montant minimum
  de commande — à ajouter plus tard si demandé.

## Schéma Firestore (nouveau)

`promoCodes/{CODE}` — doc ID = le code lui-même en MAJUSCULES (garantit l'unicité,
lookup direct côté Cloud Function sans requête) :
```
code, discountType ("percentage"|"fixed"), discountValue,
restaurantId (String?, null = global), restaurantName (String?, dénormalisé),
expiresAt (Timestamp?, null = jamais), active (bool), usageCount (int, serveur only),
createdAt, createdBy
```

`promoCodeRedemptions/{CODE}_{userId}` — trace d'utilisation (existence du doc =
déjà utilisé par ce client). Écrit uniquement par la Cloud Function, dans une
transaction (`tx.create`, donc idempotent si le trigger est rejoué).

Règles Firestore mises à jour dans
`C:\Users\PC\Desktop\FINAL 253 NOMADE\client app\production\firestores regles unique\firestore_rules.rules`
(ajout en fin de fichier) — **pas encore copié-collé dans la console Firebase, à
faire manuellement par l'utilisateur** (convention du projet, cf. `[[nomade-admin-projet]]`) :
- `promoCodes` : lecture/écriture réservées à `isAdmin()`.
- `promoCodeRedemptions` : `allow read, write: if false` (Cloud Functions/Admin SDK
  uniquement, contournent les règles).

## Admin (fait, testé via `flutter analyze` — clean)

- `lib/models/promo_code.dart` — modèle `PromoCode` (+ enum `PromoDiscountType`).
- `lib/services/promo_code_service.dart` — CRUD (`createPromoCode` échoue si le code
  existe déjà, `normalizeCode()` = uppercase + trim espaces).
- `lib/screens/promo/promo_codes_screen.dart` — liste (table desktop / cards mobile),
  recherche, toggle actif, suppression — mirroir exact du pattern
  `livreurs_list_screen.dart`.
- `lib/screens/promo/add_edit_promo_code_screen.dart` — formulaire : code (non
  modifiable en édition, c'est le doc ID), type de réduction (`SegmentedButton`),
  valeur, restaurant (dropdown alimenté par `RestaurantService.getRestaurants()`,
  `null` = tous), date d'expiration (`showDatePicker`, effaçable), switch actif.
- `lib/widgets/sidebar.dart` + `lib/screens/dashboard/dashboard_screen.dart` — entrée
  « Codes promo » (page `promoCodes`), routage + titre AppBar.

## Backend Cloud Functions (fait, `node --check` OK — **pas déployé**)

Dans `nomade_client/functions/index.js`, juste avant `exports.onOrderCreated` :

- `evaluatePromoCode(db, {code, userId, restaurantId, subtotal, deliveryFee})` —
  helper interne. Lit `promoCodes/{CODE normalisé}`, vérifie `active`, `expiresAt`
  (réutilise `parsePromoDate` déjà existant pour les promos restaurant), portée
  restaurant, et l'absence de doc dans `promoCodeRedemptions`. Calcule
  `discountAmount` sur `subtotal + deliveryFee`, plafonné à ce montant.
- `exports.validatePromoCode` (onCall, auth requise) — aperçu temps réel pour le
  checkout, **aucune écriture**. Retourne `{valid:false, message}` ou
  `{valid:true, code, discountAmount, discountType, discountValue}`.
- `onOrderCreated` étendu : si `order.promoCode` est présent, réévalue avec
  `evaluatePromoCode` (jamais confiance dans un `promoDiscount` envoyé par le
  client — même défiance que la validation des prix déjà en place). `promoDiscount`
  vient en déduction du `total` (comme la fidélité), calculé sur
  `realSubtotal + deliveryFee` — **avant** déduction fidélité, les deux réductions
  se cumulent. Si le code est appliqué, transaction : `promoCodeRedemptions` créé
  (`tx.create`, idempotent) + `promoCodes/{CODE}.usageCount` incrémenté. Si invalide
  à ce moment (course, code utilisé entre-temps...), remise silencieusement à 0 et
  `total` corrigé — pas d'annulation de commande, même philosophie que le reste de
  `validatePrices`.

## Client (`Velox_client`, Kotlin) — PAS FAIT ici

Prompt complet et actionnable écrit dans
`C:\Users\PC\StudioProjects\Velox_client\PROMPT_PROMO_CODE_CLIENT.md`, avec
références exactes (fichier/ligne) trouvées cette session :
- `Order.kt` (ligne 47 `total`, ligne 57 `toMap()`, ligne 103 `fromFirestore()`) :
  ajouter `promoCode`/`promoDiscount`, mirroir exact du pattern `pointsUsed`/`discount`.
- `OrderService.kt` (ligne 48-73, pattern `notifyRestaurant`/callable déjà en place) :
  ajouter `validatePromoCode(...)`.
- `CartViewModel.kt` (ligne 60 `CartUiState`, ligne 199-250 `createOrder`, pattern
  `pointsUsed`/`discount` lignes 226-249) : état + paramètres à ajouter, mirroir exact.
- `CartScreen.kt` : UI champ code + bouton Appliquer + ligne récap.

## Validation métier — format du code (2026-08-20)

Format retenu avec l'utilisateur : alphanumérique, **6 caractères minimum**, sans
espace ni symbole (ex. `VLX3425`). Un code court purement numérique type `#3425`
a été écarté : trop devinable (10 000 combinaisons, `validatePromoCode` n'a pas de
rate-limiting) et `#` casse dans une URL. Formulaire admin
(`add_edit_promo_code_screen.dart`) mis à jour en conséquence (regex
`^[A-Z0-9]+$`, min 6, hint `VLX3425`).

## Restaurant / Livreur — vérifié, AUCUNE modification requise

Question posée par l'utilisateur (20/08/2026) : la remise promo doit-elle aussi être
répercutée dans `Velox_Restaurant` et `Velox_Livreur` ? Structure des deux projets
auditée :
- `Velox_Restaurant/.../data/model/Order.kt` : `restaurantRevenue` = `subtotal` seul
  (commentaire explicite : jamais `total`) → insensible à toute remise plateforme
  (fidélité ou promo), c'est le comportement voulu.
- `Velox_Livreur/.../data/model/Order.kt` : pas de champ `discount` du tout, affiche
  partout `order.totalFormatted` = `total` brut Firestore.
- Les deux consomment `orders` via `addSnapshotListener` (temps réel), jamais de
  recalcul local `subtotal + deliveryFee`.
→ Le `total` corrigé par `onOrderCreated` (promo déduite) se propage automatiquement
aux deux apps, exactement comme la remise fidélité existante s'y propage déjà
aujourd'hui sans code dédié. **Rien à faire dans ces deux repos.**

## Format du code — décision finale (22/08/2026)

L'utilisateur veut des codes personnalisés type `VLXISMO22` / `VLXPANDA01` /
`VLXDEKA30` — déjà 100% compatibles avec la règle posée le 20/08 (alphanumérique,
6+ caractères, pas de symbole). Aucun changement de code nécessaire, juste confirmé
et testé directement depuis l'admin.

## Suite du 22/08/2026 — anti-abus + total remisé (codes promo)

Demandé par l'utilisateur en complément (parmi 4 idées proposées, 2 retenues :
anti-abus + visibilité admin ; plafond de remise et restriction "1ère commande"
écartés, pas nécessaires pour l'instant) :

- **Anti-abus `validatePromoCode`** (`nomade_client/functions/index.js`) : nouvelle
  collection `promoCodeAttempts/{uid}` (fenêtre glissante 15 min, 15 échecs max —
  seuls les codes INVALIDES comptent, jamais un succès). Rejet immédiat
  (`HttpsError resource-exhausted`) si la limite est atteinte, avant même de lire
  `promoCodes`. Helpers `checkPromoAttemptLimit` / `recordFailedPromoAttempt`.
- **Total remisé par code** : `promoCodes/{CODE}.totalDiscountGiven` (FDJ cumulés),
  incrémenté dans la même transaction que `usageCount` lors de `onOrderCreated`.
  Visible dans la liste admin (colonne desktop + ligne mobile).
- Règles Firestore : `promoCodeAttempts` verrouillé (`allow read, write: if false`,
  Cloud Functions/Admin SDK uniquement), même pattern que `promoCodeRedemptions`.
- **Tout déployé** : `firebase deploy --only functions` (fait par l'utilisateur),
  `firebase deploy --only firestore:rules,storage --project nomade253-478a9` (fait
  par Claude, depuis `FINAL 253 NOMADE\...\firestores regles unique`), admin
  buildé + déployé sur hosting (commit `0dfd669`, push + `flutter build web` +
  `firebase deploy --only hosting`).

## Nouvelle fonctionnalité — Bannières admin (22/08/2026)

Analyse : `FoodHomeScreen.kt` (Velox_client) affichait 3 bannières **codées en
dur** (`promoSlides`, lignes 98-110 + composable `PromoBanner` lignes 307-329),
titre/sous-titre traduits en 5 langues via `strings.xml`, aucun support image,
un seul `onClick` en dur (WhatsApp sur la 3e slide). Décision produit : **un seul
champ texte** par bannière (pas de multi-langue) pour garder l'admin simple —
tranché avec l'utilisateur, régression assumée sur la traduction auto.

Schéma Firestore `banners/{id}` (doc ID auto, triable par glisser-déposer) :
```
type: "text"|"image", order, active,
title, subtitle,                      // si type=text
imageUrl, storagePath,                // si type=image (Storage banners/{ts}.jpg)
actionType: "none"|"whatsapp"|"url"|"restaurant"|"category", actionValue,
createdAt, updatedAt
```

**Admin (fait, `flutter analyze` clean, déployé)** :
- `lib/models/banner_item.dart`, `lib/services/banner_service.dart` (CRUD + upload
  Storage + `reorder()` en batch).
- `lib/screens/banners/banners_screen.dart` — `ReorderableListView` (drag-to-reorder,
  pas un tableau comme les autres écrans : l'ordre est le cœur de cet écran), toggle
  actif, suppression (supprime aussi le fichier Storage).
- `lib/screens/banners/add_edit_banner_screen.dart` — bascule Texte/Image, champs
  conditionnels, sélecteur d'action avec champ conditionnel (numéro WhatsApp / URL /
  dropdown restaurant via `RestaurantService` / dropdown catégorie via
  `MenuManagementService.streamGlobalCategories()`).
- Sidebar + dashboard : entrée « Bannières ».
- Règles : `banners` dans Firestore (`allow read: if isAuth()`, écriture `isAdmin()`
  — pas de secret à cacher, contrairement à `promoCodes`) et `banners/{fileName}`
  dans Storage (même pattern que `restaurants/`, `livreurs/`).

**Client (`Velox_client`, Kotlin) — PAS FAIT ici.** Prompt complet :
`Velox_client\PROMPT_BANNERS_ADMIN.md`, avec références exactes trouvées cette
session :
- `FoodHomeScreen.kt` lignes 98-110 (`promoSlides` à supprimer), 155-159 (carrousel
  à rendre conditionnel + brancher sur les 2 types), 300-329 (`PromoSlide`/
  `PromoBanner` à remplacer par `TextBanner`/`ImageBanner`).
- Nouveau `domain/model/Banner.kt` (mirroir `Restaurant.kt`), `data/remote/
  BannerService.kt` (mirroir exact `RestaurantService.kt`, `callbackFlow` +
  `addSnapshotListener`, **filtre `active` côté Kotlin pas dans la requête** pour
  éviter un index composite Firestore — convention déjà en place dans le projet).
- `FoodViewModels.kt` : ajouter `banners: StateFlow<List<Banner>>` dans
  `RestaurantsViewModel` (mirroir `restaurants`/`popular`, lignes 36-43).
- Dispatch d'action générique branché sur `onOpenRestaurant`/`onOpenCategory`
  **déjà présents** comme paramètres de `FoodHomeScreen` (lignes 87-88) — pas de
  nouvelle navigation à créer.
- `coil.compose.AsyncImage` déjà importé (ligne 69, utilisé par `PopularCard`) —
  pas de nouvelle dépendance pour les bannières image.

## Nouvelle fonctionnalité — Tarifs VTC admin (23/08/2026)

Contexte : `PROMPT_ADMIN_TAXI_PRICING.md` (à la racine du repo) décrivait un écran
admin pour piloter le tarif VTC depuis Firestore (`config/taxiPricing`), en
remplacement du tarif codé en dur côté clients. **Backend (`nomade_client/
functions/index.js`, revalidation à `onTaxiRideCreated`/`onRideUpdated`) et apps
clientes déjà mis à jour avant cette session** — seul l'écran admin manquait.
Vérifié en début de session (`grep` sur `taxiPricing`/`basePrice` dans `lib/`) :
rien n'existait encore, à intégrer tel quel depuis le prompt.

Doc unique Firestore `config/taxiPricing` (pas de sous-collection) :
```
standard: { basePrice, includedKm, pricePerKm },
comfort:  { basePrice, includedKm, pricePerKm }
```
Formule (identique au serveur) : `prix = basePrice + pricePerKm × max(0,
distanceKm − includedKm)`. Doc absent en prod avant le premier "Enregistrer" —
backend et clients ont déjà un repli par défaut, donc rien n'est cassé
entre-temps.

**Admin (fait, `flutter analyze` clean, déployé)** — mirroir du pattern `banners/`
mais document unique (pas de collection, pas de drag-and-drop, pas d'upload
image) :
- `lib/models/taxi_pricing.dart` — `TaxiPricingTier`/`TaxiPricingConfig`
  (`fromFirestore`/`toMap`), défauts `kDefaultStandardTier`/`kDefaultComfortTier`
  synchronisés avec `DEFAULT_TAXI_PRICING` du backend, `priceForDistance()` pour
  l'aperçu live.
- `lib/services/taxi_pricing_service.dart` — `watchPricing()` (stream sur le doc)
  + `savePricing()` (`set` avec `merge: true`, crée le doc s'il n'existe pas).
- `lib/screens/taxi_pricing/taxi_pricing_screen.dart` — 2 cartes (Standard/
  Confort, empilées sur mobile via `isMobile(context)`), 3 champs numériques
  chacune, aperçu live recalculé à chaque frappe ("5 km → … FDJ · 10 km → … FDJ"),
  bouton Enregistrer unique. Style repris de `banners_screen.dart`
  (`constants.dart` : `defaultPadding`, `cardColor`, `primaryColor`,
  `captionStyle`).
- Sidebar (`lib/widgets/sidebar.dart`) + dashboard (`lib/screens/dashboard/
  dashboard_screen.dart`, résolution du widget et du titre AppBar) : entrée
  « Tarifs VTC ».
- Règles Firestore déjà déployées avant cette session (collection `config` :
  lecture `isAuth()`, écriture `isAdmin()`, même politique que `banners`) — rien
  à toucher côté règles/Cloud Functions, conforme au "Ne pas faire" du prompt.
- **Déployé** : `flutter build web --release` puis `firebase deploy --only
  hosting` (projet `nomade253-478a9`) → https://nomade253-478a9.web.app.

## Nouvelle fonctionnalité — Historique de notifications persistant (26/08/2026)

Origine : `PROMPT_NOTIFICATIONS_BACKEND.md` reçu dans **Downloads**, écrit par
l'agent Claude iOS (Flutter, autre repo) qui venait de livrer son écran côté
iOS — l'app iOS et Android partagent le même backend Firebase. Jusqu'ici les
notifications ne partaient qu'en push FCM (perdu si balayé/purgé par l'OS).
Objectif : persister chaque notification pour un historique + badge non-lu,
sans toucher au push existant.

**Backend (`nomade_client/functions/index.js`) — fait, `node --check` OK,
déployé en prod le 26/08/2026** :
- Nouvelle sous-collection `users/{uid}/notifications/{notificationId}`
  (`type`, `title`, `body` complet, `createdAt`, `read`/`readAt` côté serveur,
  `actionType`/`actionValue`, `imageUrl`, `campaignId`).
- Helpers `persistClientNotification()` / `apnsWithCategory()` ajoutés juste
  après `getClientFcmToken` (~ligne 92). Appelés dans la même exécution que
  le push FCM existant, **9 points d'accroche** : `acceptRideTx`,
  `sendNextDriverOffer` (no_driver_available), `onRideUpdated`
  (driver_accepted/arriving/arrived, ride_started, ride_completed,
  ride_cancelled par le chauffeur), `sendOrderReadyNotifications`. Chaque
  envoi FCM concerné reçoit aussi `apns.payload.aps.category`
  (`VELOX_ORDER`/`VELOX_RIDE`) — indispensable côté iOS pour l'affichage
  dépliable en arrière-plan.
- `sendBroadcastNotification` (callable existante, utilisée par
  `broadcast_notification_screen.dart`) étendue : pour l'audience `"clients"`,
  écrit désormais un doc par compte via `BulkWriter`, ID = `campaignId`
  (UUID généré serveur, retourné à l'appelant) → idempotent si la campagne
  est rejouée. `apns.category = VELOX_PROMO` pour cette audience.
- Nouvelle fonction planifiée `purgeOldClientNotifications` (24h, rétention
  90 jours, requête de groupe de collection + suppression par lots de 450).
- Règles Firestore : bloc `users/{userId}/notifications` (lecture
  propriétaire, update limité à `read`/`readAt` via `onlyFields`,
  create/delete interdits) ajouté dans **les deux** fichiers pertinents —
  `functions/scripts/sim/firestore_rules_prod.rules` (celui réellement
  déployé, référencé par `firebase.json` — **pas** la copie
  `FINAL 253 NOMADE\...`, contrairement à ce qu'indiquait la mémoire
  précédente) et la copie `FINAL 253 NOMADE\...` par cohérence.
- `firestore.indexes.json` : `fieldOverrides` sur `notifications`/`createdAt`
  (COLLECTION + COLLECTION_GROUP, ASC/DESC).
- **Déployé** : `firebase deploy --only functions,firestore:rules,firestore:indexes
  --project nomade253-478a9` — succès (~40 functions, dont
  `purgeOldClientNotifications` créée).

⚠️ Découverte en cours de session : le repo `nomade_client` avait déjà des
changements non commités et sans rapport avec cette tâche (rebranding
"Nomade253" → "Velox Corp" dans `index.js`/`firestore.rules`, probablement
une autre session) — non touchés, juste posé le travail par-dessus. Rien n'a
été committé dans ce repo (pas de dépôt git piloté par cette session admin).

**Livrables écrits cette session** :
- `C:\Users\PC\Downloads\RETOUR_NOTIFICATIONS_BACKEND.md` — retour à l'agent
  iOS (schéma exact, index déployés, confirmation règles, un exemple de doc
  par `type`, nom de la callable de campagne). Déposé dans Downloads (pas
  dans `Velox_Client-IOS` sur StudioProjects : dates de fichiers figées au
  15/07, aucune preuve que ce soit le repo réellement actif).
- `Velox_client\PROMPT_NOTIFICATIONS_PAGE_ANDROID.md` — prompt pour l'écran
  équivalent côté Android Kotlin, ancré dans le code réel (exploration du
  repo faite avant écriture) : package `dj.velox.client`, pattern MVVM/Compose
  de `OrderService`/`OrdersViewModel`/`OrderHistoryScreen` à reproduire,
  point d'entrée `ProfileScreen.kt` (~ligne 356), routes dans
  `VeloxNavGraph.kt`. Précise que ce nouvel écran est indépendant du
  mécanisme `DeepLink`/`NotificationRouter` existant (tap sur push système).
  **Pas encore fait.**

## Fix — Annulation admin ne libère pas le livreur (26/08/2026)

Origine : `PROMPT_FIX_CANCEL_LIBERE_LIVREUR.md` (racine du repo admin,
committé). Bug : `orders_screen.dart`, `_confirmCancel` (~ligne 547) ne
faisait qu'un `update` sur `orders/{orderId}.status`, sans jamais libérer
`livreurs/{deliveryDriverId}` (`isAvailable`/`currentOrderId`) — un livreur
avec une commande en cours annulée par l'admin restait bloqué à vie
(`canAcceptOrders` figé à `false` côté app Kotlin, sans erreur visible).

**Fait** : `_confirmCancel` passe désormais par une `Transaction` Firestore —
lecture de `deliveryDriverId`, puis écriture atomique de l'annulation et,
si un livreur est assigné (et que son doc existe encore), remise à
`isAvailable: true`/`currentOrderId: null`. `flutter analyze` clean.

Vérifié aussi `taxi_rides_screen.dart` par analogie (demandé par le prompt) :
**pas de correctif nécessaire**. Contrairement aux livreurs, la disponibilité
d'un chauffeur VTC (`drivers.isAvailable`) n'est jamais liée à un pointeur de
course stocké — elle est recalculée à la volée via `driverHasActiveRide()`
(requête live sur `taxiRides.status`). Annuler la course suffit déjà à le
libérer automatiquement.

Le prompt mentionnait aussi un filet de sécurité serveur déjà ajouté et
déployé par un autre agent : `exports.onOrderCancelledReleaseDriver`
(`nomade_client/functions/index.js`) — **vérifié présent**, non ajouté par
cette session.

**Committé et poussé** : commit `50d7d26` sur `feat/grille-tarifaire`
(`lib/screens/orders/orders_screen.dart` + `PROMPT_FIX_CANCEL_LIBERE_LIVREUR.md`),
`git push` fait.

## 🔜 Reste ouvert

1. ~~Déployer `functions/index.js`~~ — fait (20/08 par l'utilisateur, 22/08 relivré
   avec anti-abus + total remisé, par l'utilisateur ; 26/08 relivré avec
   l'historique de notifications, par Claude).
2. ~~Copier/déployer les règles Firestore + Storage~~ — **fait par Claude via CLI
   le 22/08/2026** (`firebase deploy --only firestore:rules,storage`), plus besoin
   de copier-coller manuellement en console pour ce qui a été fait jusqu'ici.
3. **App cliente `Velox_client`** : à faire par l'autre agent Claude Code — 3
   prompts en attente : `PROMPT_PROMO_CODE_CLIENT.md` (l'utilisateur teste
   actuellement en local), `PROMPT_BANNERS_ADMIN.md` (pas encore commencé),
   `PROMPT_NOTIFICATIONS_PAGE_ANDROID.md` (nouveau, pas encore commencé).
4. Test de bout en bout une fois le client fait, pour les features livrées côté
   backend/admin mais pas encore côté client : codes promo
   (usageCount/totalDiscountGiven/anti-abus/rejet 2e utilisation), bannières
   (création admin → apparition temps réel dans l'app, les 2 types, les 4
   actions), et historique de notifications (badge non-lu, routage au tap).
5. ~~Écran admin Tarifs VTC~~ — **fait et déployé le 23/08/2026.** Reste à vérifier
   en prod : créer/modifier le tarif depuis l'admin puis confirmer côté client que
   le prix affiché/facturé suit bien la nouvelle config (aucune app cliente
   retouchée cette session, la lecture était déjà en place).
6. **Retour iOS** (`RETOUR_NOTIFICATIONS_BACKEND.md` dans Downloads) — à
   vérifier que l'agent/équipe iOS l'a bien reçu et traité (confirmer que le
   fichier a été récupéré, pas de mécanisme de notification automatique côté
   admin).
