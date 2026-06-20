# Travaux 3 — Horaires restaurant + Catégories globales + Import menu par fichier

> Contexte de session pour reprise. Dernière mise à jour : 2026-06-14.
> Suite de `travauxMenu.md` (gestion menu créée le 2026-06-13).

## Écosystème (rappel)

| App | Techno | Chemin | Rôle |
|---|---|---|---|
| **Admin** | Flutter web | `C:\Users\PC\Desktop\ReelADMIN\ADMIN3\NOMADE_ADMIN_COMPLETE` (projet courant) | Gestion menu/catégories/horaires |
| **Restaurant** | Android Kotlin | `C:\Users\PC\StudioProjects\Velox_Restaurant` | **NE PAS MODIFIER** |
| **Client** | Flutter | `C:\Users\PC\StudioProjects\nomade_client` | Lit menuItems/restaurants. À modifier ensuite |

Firebase : `nomade253-478a9`. Firestore **camelCase** strict.
Règles Firestore (fichier copié-collé dans la console) :
`C:\Users\PC\Desktop\FINAL 253 NOMADE\client app\production\firestores regles unique\firestore_rules.rules`
Menu source STR'EAT : `C:\Users\PC\Desktop\FINAL 253 NOMADE\Resto app\MENU\menu Streat Food.txt`

Règle admin : `isAdmin()` = doc présent dans `admins/{uid}`. Collections globales =
lecture `isAuth()`, écriture `isAdmin()` (ou propriétaire).

---

## 1) Horaires d'ouverture restaurant ✅

Décisions : ajout **additif** (ignoré par app resto Kotlin + client). Granularité
**par jour de la semaine**. **Week-end = vendredi** (Djibouti) → ordre d'affichage
Samedi → … → Vendredi (vendredi marqué « week-end »).

Schéma `restaurants/{id}.openingHours` (camelCase, clés jours en **anglais**) :
```
openingHours: {
  "monday":   [ {"open":"08:00","close":"14:00"}, {"open":"14:00","close":"22:00"} ],
  "friday":   [],                                  // vide = fermé
  "saturday": [ {"open":"18:00","close":"00:00"} ] // 00:00 = jusqu'à minuit
}
```
Plage `close <= open` = traverse minuit (ex. 22:00→02:00). `isOpenAt(dt)` gère le
débordement de la veille. `isOpen` (toggle manuel) conservé comme interrupteur maître.

Fichiers :
- `lib/models/opening_hours.dart` — NOUVEAU : `OpeningHours`, `TimeRange`,
  `kDayKeys`/`kDayLabelsFr`/`kDayDisplayOrder`, `isOpenAt`/`isOpenNow`.
- `lib/models/restaurant.dart` — champ `openingHours` (+ `hasOpeningHours`,
  `isOpenNowBySchedule`).
- `lib/widgets/opening_hours_editor.dart` — NOUVEAU éditeur par jour (switch
  Ouvert/Fermé, plages multiples, TimePicker 24h, « Appliquer à tous »).
- `lib/screens/restaurants/add_restaurant_screen.dart` — éditeur intégré + écriture.
- `lib/screens/restaurants/restaurant_details_screen.dart` — section affichage +
  badge « Ouvert/Fermé maintenant » + dialog Modifier (sauvegarde via updateRestaurant).

---

## 2) Accès au menu corrigé ✅

Cause racine « je ne vois pas Gérer le menu » : sur desktop la liste est une
`DataTable` dont les lignes n'étaient pas cliquables et l'icône détails était hors
écran à droite. Corrigé dans `lib/screens/restaurants/restaurants_list_screen.dart` :
- `onSelectChanged` sur chaque ligne → ouvre les détails.
- Bouton direct 🍽 « Gérer le menu » (colonne Actions + carte mobile) → `MenuManagementScreen`.

---

## 3) Catégories 100% GLOBALES ✅

Décisions validées : catégories **globales** (plus per-restaurant). Auto-seed depuis
les plats existants. Entrée **sidebar « Catégories »**.
**Un plat hérite UNIQUEMENT de l'image** de sa catégorie (prix / suppléments /
tailles restent propres au menu de chaque restaurant).

Schéma — NOUVELLE collection racine `menuCategories` :
`{ name, imageUrl?, storagePath?, order, createdAt }`. Fallback gris si pas d'image.

Fichiers :
- `lib/models/global_category.dart` — NOUVEAU `GlobalCategory`.
- `lib/services/menu_management_service.dart` — ajouts : `streamGlobalCategories`,
  `getGlobalCategories`, `create/update/deleteGlobalCategory`, `uploadCategoryImage`
  (`menu_categories/…`), `imageForCategoryName`, `ensureGlobalCategories`,
  `seedGlobalCategoriesFromMenuItems`. `importMenu` réécrit → alimente le catalogue global.
- `lib/screens/categories/global_categories_screen.dart` — NOUVELLE page sidebar :
  grille, fallback gris, upload/bibliothèque/retrait image, renommer, supprimer,
  bouton « Récupérer les catégories existantes ».
- `lib/widgets/sidebar.dart` + `lib/screens/dashboard/dashboard_screen.dart` — entrée
  `categories` câblée (titre « Catégories de menu »).
- `lib/screens/menu/menu_item_editor_screen.dart` — utilise `GlobalCategory`,
  n'hérite QUE l'image.
- `lib/screens/menu/menu_management_screen.dart` — onglet Catégories retiré ;
  bouton « Ajouter un menu entier » bien visible ; catégories globales passées à l'éditeur.

---

## 4) Import d'un menu entier par fichier .txt ✅

- `pubspec.yaml` — ajout `file_picker: ^8.1.2` (`flutter pub get` OK).
- `lib/screens/menu/import_menu_screen.dart` — bouton **« Choisir un fichier .txt »**
  (upload + décodage utf8) en plus du collage ; image de chaque catégorie résolue
  **automatiquement** depuis les catégories globales (matching par nom), fallback gris.
- Parser inchangé (`menu_parser.dart`) — lit prix / formules « menu » / tailles M/L/XL /
  suppléments. Validé sur STR'EAT : 5 catégories, 40 plats.

---

## 5) Règles Firestore ✅ (modifié)

Ajout d'**un seul bloc** (rien d'autre touché) dans le fichier de règles, après `menuItems` :
```
match /menuCategories/{categoryId} {
  allow read:  if isAuth();   // client authentifié
  allow write: if isAdmin();  // create/update/delete admin uniquement
}
```
Déjà OK dans les règles existantes : `restaurants` update admin (→ `openingHours`),
`menuItems` create/update/delete admin (→ import & édition plats).
**Action utilisateur** : copier-coller le fichier complet dans la console → Publier.

---

## État build

`flutter analyze` : **0 erreur** (1 `info` préexistant `dart:html` dans
`delivery_tracking_screen.dart`, non lié).

---

## 🔜 RESTE À FAIRE

1. **Règles Storage** (fichier séparé, pas encore modifié) : autoriser écriture admin
   sur préfixes `menu_categories/`, `menu_library/`, `menuItems/`, `restaurants/`.
   → Demander le chemin du fichier règles Storage à l'utilisateur.
2. **Test bout-en-bout** (après publication des règles + `flutter clean`/`pub get`/`run`) :
   - Page Catégories → « Récupérer les catégories existantes » + lier des images.
   - Restaurants → Gérer le menu → Ajouter un menu entier (upload STR'EAT .txt).
   - Créer/éditer un restaurant avec horaires ; vérifier Firestore.
3. **App client** (`nomade_client`) — à faire ensuite :
   - Options data-driven : lire `menuItems.optionGroups` au lieu des extras/sauces
     hardcodés (`add_to_order_screen.dart`), avec fallback.
   - Lire `restaurants.openingHours` pour afficher ouvert/fermé + bloquer hors horaires.

## Orphelins (non supprimés, sans risque — à nettoyer plus tard)
`menu_category.dart`, `category_editor_screen.dart`, `image_library_screen.dart`,
et les méthodes per-restaurant du service (`streamCategories`, `ensureCategory`…).
