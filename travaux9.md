# travaux9 — 2026-11-02 — Périodes, Comptabilité, carte CARTO

Plaintes admins : « les commandes disparaissent petit à petit », « impossible
de faire les calculs », « localisation des taxis pas au bon endroit ».

## 1. Commandes qui « disparaissent » (corrigé)
Cause : fenêtres glissantes `.limit(200)` (Commandes, Courses taxi) et
`.limit(500)` (Statistiques). Aucune suppression côté Firestore (vérifié : les
commandes du 05/09/2026 sont présentes).
- `lib/widgets/period_filter.dart` : `Period` (+ `apply()` = where >= / < +
  orderBy sur le même champ, pas d'index composite) et `PeriodFilterBar`.
- Appliqué à `orders_screen` (défaut 7 jours), `taxi_rides_screen` (7 jours),
  `statistics_screen` (ce mois, CA désormais exact sur la période).

## 2. Écran Comptabilité (nouveau, menu « Comptabilité »)
`lib/screens/accounting/accounting_screen.dart` + `lib/models/order_accounting.dart`.
Circuit confirmé par l'utilisateur (02/11/2026) :
- le client paie TOUJOURS le livreur (espèces, D-Money ou Waafi sur son téléphone) ;
- le livreur paie au restaurant le prix menu complet (`subtotal`) ;
- les points fidélité sont toujours déduits des 500 FDJ de livraison du livreur ;
- livreur et NOMADE n'échangent pas d'argent ;
- en fin de mois, le gérant fait le tour des restaurants pour encaisser la
  commission NOMADE (incluse dans tous les prix menu).
Écran : commissions dues par restaurant, avec reste à encaisser et date du
dernier encaissement ; « Fiche » imprimable pour la tournée (commandes,
commission par commande, total, signatures) ; « Encaissée » → collection
`restaurantCommissionPayments` (create admin, ni update ni delete) ; partie
livreurs informative ; export CSV `;` + BOM.
Commission **estimée** en inversant la grille (`MenuParser.marginIncludedIn`,
inverse exact testé de 1 à 40 000). Tests : `test/order_accounting_test.dart`.
Non géré : les impayés des périodes précédentes ne s'additionnent pas
automatiquement (il faut choisir la période concernée).

## 3. Carte
- Tuiles CARTO Voyager avec clé (`Urls.cartoVoyagerTile` dans constants.dart),
  attribution CARTO + OSM.
- Vraie cause du « mauvais endroit » : des comptes restent `isOnline: true`
  des jours après la fermeture de l'app (ex. updatedAt 28/10) → position
  figée affichée comme actuelle. Désormais : sans position depuis 10 min =
  « Sans signal », masqué par défaut (puce « Positions figées » pour les voir
  en gris), heure de dernière position dans la fiche.

## Déploiement — FAIT le 02/11/2026 (règles via CLI depuis le fichier unique + hosting, commit f3db5ff)
- Admin web : `flutter build web` OK.
- Règles : **source unique = `FINAL 253 NOMADE/client app/production/firestores regles unique/firestore_rules.rules`**
  (confirmé par l'utilisateur le 02/11/2026 ; `nomade_client/functions/scripts/sim/firestore_rules_prod.rules`
  n'est PAS utilisé, ma modif dessus a été annulée). Bloc `restaurantCommissionPayments`
  ajouté, compilation validée par le serveur (`firebase deploy --dry-run`).
  À copier-coller dans la console Firestore > Règles.

---

# Session du 19/11/2026 — Carte (précision GPS), doublons catégories, commandes privées

## 4. Carte : livreurs / VTC mal localisés
Diagnostic (code des apps + données Firestore) : le problème vient surtout des apps.
- **Immobile = invisible** : les apps n'envoient une position que si la personne a
  bougé (livreur : 10 m, `GPS_DISTANCE_FILTER_METERS` ; chauffeur en attente : 30 m,
  `IDLE_MIN_DISTANCE_M`). Un livreur qui attend sur place n'envoie plus rien → au bout
  de 10 min l'admin le classe « Sans signal » et le masque.
- **Positions imprécises** envoyées telles quelles (ex. ±115 m, `locationAccuracy`).
- **Livreur** : `updatedAt` sert d'heure de position mais est aussi modifié par la
  dispo et le token FCM.
- Driver `Warsama` (drivers/1sbH…) `isOnline: true` alors que dernier signal le 26/10 ;
  aucune tâche ne remet les comptes hors ligne. Même téléphone que le livreur SOUGUEH ALI,
  plaque 809D98 sur 3 comptes.

Fait côté admin (`lib/screens/map/maps_screen.dart`) : cercle de précision autour de
chaque position (rouge si > 50 m) + ligne « Précision : ±X m » dans la fiche.

Prompts déposés (non appliqués, à donner aux agents des apps) :
- `Velox_Livreur\PROMPT_POSITION_CARTE_ADMIN.md`
- `Velox_driver\PROMPT_POSITION_CARTE_ADMIN.md`
Contenu : position au moins 1×/min même immobile ; ne pas envoyer une position
> 50 m sauf si rien depuis 2 min ; livreur : écrire `lastHeartbeat` (heure serveur)
uniquement avec la position.
⚠️ Piège : les règles `onlyFields` sur `livreurs`/`drivers` refusent TOUTE la mise à
jour si elle contient un champ non listé. D'où `lastHeartbeat` (déjà autorisé et déjà lu
par l'admin) au lieu d'un nouveau champ. Chauffeur : aucun nouveau champ,
`currentLocation.updatedAt` suffit.

Non fait (refusé par l'utilisateur pour l'instant) : Cloud Function planifiée qui remet
hors ligne les comptes sans position depuis 15 min.

## 5. Doublons de catégories
- Supprimés dans Firestore (`menuCategories`) : `W404B1RZYpaSBpVlPkPe`
  (« Accompagnements », 07/09) et `ew2AgeS3SxJbQZ1dhURt` (« Sea Foods », 31/08) ;
  les plus anciens conservés. Sans risque : les plats référencent la catégorie par son nom.
- Prévention (`menu_management_service.dart`, `global_categories_screen.dart`) :
  - création atomique `createGlobalCategoryIfAbsent` : id du document = `categoryKey`
    + transaction → deux imports / admins / double clic simultanés n'en créent qu'une
    (cause probable des doublons, la normalisation existait depuis le 17/07).
    `createGlobalCategory` (id aléatoire) supprimé ; `ensureGlobalCategories` l'utilise.
  - renommage vers un nom déjà pris refusé (`DuplicateCategoryException`) → l'admin
    propose « déplacer les plats et supprimer ».
  - bouton « + Catégorie » bloqué pendant l'enregistrement, message si le nom existe
    sous une autre forme.
  - bandeau orange si des doublons existent, avec bouton « Fusionner ».

## 6. Commandes privées (WhatsApp, téléphone)
Nouvelle section sidebar « Commandes privées » (page `privateOrders`).
- Collection **`privateOrders`** (admin seul), séparée de `orders` : aucune Cloud
  Function, notification ni statistique déclenchée.
- Champs : `orderDate`, `source` (whatsapp/phone/other), `clientName`, `clientPhone`,
  `deliveryAddress`, `restaurantId`, `restaurantName`, `items[] {name, quantity, unitPrice}`,
  `deliveryFee`, `subtotal`, `total` (dénormalisés), `livreurId`, `livreurName`,
  `paymentMethod` (cash/dmoney/waafi), `status` (pending/delivered/cancelled), `notes`,
  `createdByEmail`, `createdAt`, `updatedAt`.
- Fichiers : `lib/models/private_order.dart`, `lib/screens/private_orders/private_orders_screen.dart`
  (liste par période, recherche, filtre statut, totaux hors annulées, détail, modifier,
  supprimer, export CSV), `private_order_editor.dart` (formulaire ; plats du menu du
  restaurant proposés avec leur prix ; total calculé). Tests : `test/private_order_test.dart`.
- Non fait : commissions des commandes privées dans l'écran Comptabilité (question posée).

## Déploiement — FAIT le 19/11/2026 (commit bbf5f78, non poussé)
- `flutter analyze` : seuls les avertissements `dart:html` ; 47 tests OK.
- Règles : bloc `privateOrders` ajouté au fichier unique, publié via
  `firebase deploy --only firestore:rules` depuis une copie (firebase.json temporaire),
  après `--dry-run` OK.
- Admin web : `flutter build web --release` + `firebase deploy --only hosting`.
