# Travaux 6 — Codes promo (admin → backend → client)

> Contexte de session pour reprise. Dernière mise à jour : 2026-08-20.
> Suite de `travaux5.md` (notifications). Nouvelle fonctionnalité : **code promo**
> créé depuis l'admin, appliqué par le client au checkout sur
> (sous-total nourriture + frais de livraison).

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

## 🔜 Reste ouvert

1. ~~Déployer `functions/index.js`~~ — **fait par l'utilisateur (20/08/2026)**.
2. ~~Copier les règles Firestore mises à jour dans la console Firebase~~ — **fait
   par l'utilisateur (20/08/2026)**.
3. **App cliente `Velox_client`** : à faire par l'autre agent Claude Code, prompt prêt
   (`Velox_client\PROMPT_PROMO_CODE_CLIENT.md`). L'utilisateur teste actuellement
   (`npm run` côté client) l'application du code au checkout.
4. Test de bout en bout une fois le client fait : créer un code depuis l'admin,
   l'appliquer dans l'app, vérifier `usageCount` + `promoCodeRedemptions` + qu'une
   deuxième tentative du même client est bien rejetée, et que `total` chez
   resto/livreur reflète bien la remise (comportement attendu, pas de code à changer).
