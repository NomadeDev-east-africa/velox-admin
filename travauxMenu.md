# Travaux — Gestion des menus depuis l'app Admin

> Contexte de session pour reprise. Dernière mise à jour : 2026-06-14.

## Objectif global

Permettre de **créer et gérer les menus des restaurants depuis le site admin**
(au lieu de l'app restaurant uniquement), de façon **rapide et simple** :

- Une **bibliothèque d'images prédéfinies** uploadée à l'avance (burger, pizza,
  tacos…), **globale** et réutilisable par tous les restaurants.
- Une **liste fermée de catégories par restaurant**, chacune avec **sa propre image**.
- **Assemblage automatique** : chaque plat hérite de l'image de sa catégorie.
- Un moyen d'**importer un menu complet d'un coup** (coller le texte → aperçu → import).
- Seuls le nom du plat / du restaurant changent ; l'image est générique par catégorie.

## Les 3 applications concernées

| App | Techno | Chemin | Rôle vis-à-vis du menu |
|---|---|---|---|
| **Admin** | Flutter (web) | `C:\Users\PC\Desktop\ReelADMIN\ADMIN3\NOMADE_ADMIN_COMPLETE` (projet courant) | **Nouvelle** gestion menu (cette session) |
| **Restaurant** | Android natif Kotlin | `C:\Users\PC\StudioProjects\Velox_Restaurant` | Crée les `menuItems` aujourd'hui. **NE PAS MODIFIER** |
| **Client** | Flutter | `C:\Users\PC\StudioProjects\nomade_client` | Lit `menuItems` et affiche. **À modifier ensuite** (suppléments) |

Firebase project : `nomade253-478a9` — bucket Storage `nomade253-478a9.appspot.com`.
Convention Firestore : **camelCase**, aucun underscore.

---

## Schéma Firestore (existant + ajouts)

### `menuItems` (collection racine, doc ID auto) — EXISTANT, étendu
Champs existants : `restaurantId`, `name`, `description`, `price` (FDJ),
`imageUrl` (String?), `category` (String), `isAvailable`, `preparationTime` (min),
`createdAt`, `updatedAt`. Côté client il existe aussi `discountPercentage`.

**AJOUT cette session** : `optionGroups` (Array<Map>) — voir modèle ci-dessous.
L'app resto Kotlin ignore ce champ → aucun impact.

### `restaurants/{id}/categories` (sous-collection) — EXISTANT, étendu
Champs existants (lus par l'app resto) : `name`, `isDefault`, `restaurantId`, `createdAt`.

**AJOUTS cette session** (ignorés par l'app resto) :
`imageUrl` (image de la catégorie), `defaultOptionGroups` (Array<Map>, suppléments
hérités par les plats), `order` (int).

### `menuImageLibrary` (collection racine) — NOUVEAU
Bibliothèque d'images globale : `{ label, imageUrl, storagePath, createdAt }`.
Images stockées dans Storage sous `menu_library/{ts}_{slug}.jpg`.

### Modèle `optionGroups` (unifié)
```
optionGroups: [
  {
    "name": "Formule",            // ex: Formule, Taille, Viande, Suppléments, Sauces
    "type": "single" | "multiple",
    "required": bool,
    "choices": [ { "name": "Menu", "price": 300 } ]  // price = SUPPLÉMENT ajouté à la base
  }
]
```
Encodage des cas STR'EAT :
- Cheeseburger 600 / menu 900 → base 600 + "Formule" single [Seul +0, Menu +300]
- Tacos M/L/XL → base + "Taille" single [M +0, L +600, XL +1200]
- Emmental/Cheddar/Œuf +100 → "Suppléments" multiple

---

## Décisions validées avec l'utilisateur

1. **Modèle `optionGroups`** (price = supplément ajouté à la base) → **OK**
2. **Suppléments par catégorie hérités** (modèle stocké sur la catégorie, copié sur
   chaque plat pour que le client lise uniquement le plat) → **OK**
3. **On démarre par l'app admin**, puis le client → **OK**
4. Tailles (Tacos M/L/XL) = **sélecteur via optionGroup**, pas 3 plats séparés.

---

## Découverte clé (justifie la future modif client)

Dans le client `lib/screens/food/addToOrder/add_to_order_screen.dart`, les
**extras et sauces sont CODÉS EN DUR** (lignes ~41-56), **génériques et identiques
pour tous les plats/restos** :
- Extras : Frites/Tomates/Oignons/Salade/Taille L/XL/XXL = 500 FDJ
- Sauces : Samouraï/Mayo/Ketchup/Barbecue/Harissa/Moutarde = 50 FDJ

Ils ne viennent PAS de `menuItems`. → C'est la vraie raison qui impose une modif
client : rendre les options **data-driven** depuis `menuItems.optionGroups`.

Le client affiche déjà `imageUrl` directement (fallback icône grise dans
`item_card.dart` / `featured_item_card.dart`) → **aucune modif client pour l'image**.

---

## ✅ FAIT cette session (app admin) — tout compile (`flutter analyze` OK)

### Modèles (`lib/models/`)
- `option_group.dart` — `OptionGroup` / `OptionChoice` / enum `OptionType` (+ helpers
  `listFromRaw` / `listToRaw`)
- `menu_category.dart` — `MenuCategory` (id, restaurantId, name, imageUrl, isDefault,
  order, defaultOptionGroups, createdAt)
- `library_image.dart` — `LibraryImage`
- `menu_item.dart` — **étendu** avec `optionGroups` (fromFirestore/toMap/copyWith)

### Services (`lib/services/`)
- `menu_management_service.dart` :
  - Bibliothèque : `streamLibraryImages`, `addLibraryImage`, `deleteLibraryImage`
  - Catégories : `streamCategories`, `getCategories`, `createCategory`,
    `updateCategory`, `deleteCategory`, `ensureCategory`
  - Plats : `streamMenuItems`, `createMenuItem`, `updateMenuItem`, `deleteMenuItem`,
    `toggleAvailability`, `uploadMenuItemImage`
  - `importMenu` — crée catégories manquantes + plats en **batch** (450/commit)
  - Upload Storage via `putData` (bytes / Uint8List, compatible web)
- `menu_parser.dart` — `MenuParser.parse(text)` → `ParsedMenu { categories, globalSupplements }`
  - Détecte en-têtes (majuscules dominantes), plats `Nom : 600 FDJ (menu 900 FDJ)`,
    tailles `Taille M/L/XL` (suffixe le nom), section `Suppléments`.

### Écrans (`lib/screens/menu/`)
- `menu_management_screen.dart` — onglets **Plats** / **Catégories**, FAB d'ajout,
  actions AppBar : import + bibliothèque
- `menu_item_editor_screen.dart` — création/édition plat ; image auto de la catégorie,
  override possible (bibliothèque ou upload) ; éditeur d'options ; dispo ; temps prépa
- `category_editor_screen.dart` — nom + image bibliothèque + suppléments par défaut
- `image_library_screen.dart` — grille, upload + label, suppression
- `import_menu_screen.dart` — coller → **Analyser** → aperçu éditable (renommer cat.,
  assigner image par cat., éditer/supprimer plats, checkbox "appliquer suppléments à
  tous") → **Importer**

### Widgets (`lib/widgets/`)
- `option_groups_editor.dart` — éditeur réutilisable de groupes d'options
- `library_image_picker.dart` — `pickLibraryImage(context)` → grille de la bibliothèque

### Câblage
- `lib/screens/restaurants/restaurant_details_screen.dart` : bouton **« Gérer le menu »**
  navigue désormais vers `MenuManagementScreen` (le TODO/snackbar est supprimé).

### Validation parser sur le vrai menu STR'EAT
Fichier source : `C:\Users\PC\Desktop\FINAL 253 NOMADE\Resto app\MENU\menu Streat Food.txt`
Résultat : **5 catégories, 40 plats** — Hamburgers/Paninis/Bowls/Wraps + Tacos (M/L/XL
distincts) ; formules « menu » détectées ; suppléments propres :
Emmental+100, Cheddar+100, Œuf+100, Kebab+400, Tenders+200.

---

## ✅ FAIT 2026-06-14 (app admin) — Horaires d'ouverture restaurant — compile (`flutter analyze` OK)

Décision validée : **données restaurants/menuItems actuelles = données de TEST** →
nettoyage autorisé (recréer les vrais ensuite). Ajout horaire = **purement additif**,
ignoré par l'app resto Kotlin et le client (comme `optionGroups`).
Granularité retenue : **par jour de la semaine**. **Week-end = vendredi** (Djibouti) →
ordre d'affichage local : Samedi → … → Vendredi (vendredi en dernier, marqué « week-end »).

### Schéma Firestore — `restaurants/{id}.openingHours` (NOUVEAU champ, camelCase)
```
openingHours: {
  "monday":   [ {"open":"08:00","close":"14:00"}, {"open":"14:00","close":"22:00"} ],
  "friday":   [],                                  // liste vide = fermé
  "saturday": [ {"open":"18:00","close":"00:00"} ] // 00:00 = jusqu'à minuit
}
```
Clés jours en **anglais** (stables). Plage `close <= open` = traverse minuit
(ex. 22:00→02:00). `isOpenAt(dt)` gère aussi le débordement de la veille.

### Fichiers
- `lib/models/opening_hours.dart` — NOUVEAU : `OpeningHours`, `TimeRange`,
  `kDayKeys`, `kDayLabelsFr`, `kDayDisplayOrder` (samedi→vendredi), `isOpenAt`/`isOpenNow`.
- `lib/models/restaurant.dart` — étendu : champ `openingHours`
  (fromFirestore/toMap/copyWith) + getters `hasOpeningHours`, `isOpenNowBySchedule`.
- `lib/widgets/opening_hours_editor.dart` — NOUVEAU : éditeur par jour (switch
  Ouvert/Fermé, plages multiples, TimePicker 24h, « Appliquer à tous »).
- `lib/screens/restaurants/add_restaurant_screen.dart` — éditeur intégré + champ
  `openingHours` écrit dans Firestore à la création.
- `lib/screens/restaurants/restaurant_details_screen.dart` — section d'affichage
  des horaires + badge « Ouvert/Fermé maintenant » + dialog **Modifier** (sauvegarde
  via `updateRestaurant`). (Le TODO « édition » reste pour les autres champs.)

`isOpen` (toggle manuel) **conservé** comme interrupteur maître ; `openingHours`
calcule « ouvert maintenant » automatiquement.

### Règles Firebase pour les horaires
Aucune nouvelle règle nécessaire : `openingHours` est un champ de `restaurants/{id}`,
déjà couvert par les droits d'écriture admin existants sur cette collection.

### 🔜 Reste (horaires) — app client
Faire lire `restaurants/{id}.openingHours` au client pour afficher « ouvert / fermé »
et bloquer la commande hors horaires (modèle `OpeningHours` à porter côté client).

## ✅ FAIT 2026-06-14 (suite) — Catégories GLOBALES + accès liste + import fichier

### Accès menu corrigé (`restaurants_list_screen.dart`)
Cause racine « je ne vois pas Gérer le menu » : la `DataTable` desktop n'avait pas
de ligne cliquable et l'icône détails était hors écran. Corrigé :
- `onSelectChanged` sur chaque ligne → ouvre les détails.
- Bouton direct 🍽 « Gérer le menu » (colonne Actions + carte mobile) → `MenuManagementScreen`.

### Décision : catégories 100% GLOBALES (plus per-restaurant)
- Nouvelle collection racine **`menuCategories`** : `{ name, imageUrl?, storagePath?, order, createdAt }`.
- Un plat **hérite UNIQUEMENT de l'image** de sa catégorie. Prix / suppléments /
  tailles restent propres au menu de chaque restaurant.
- Seed initial = agrégation des noms de catégories déjà présents dans `menuItems`.
- Fallback gris quand `imageUrl` absent.

### Fichiers
- `lib/models/global_category.dart` — NOUVEAU modèle `GlobalCategory`.
- `lib/services/menu_management_service.dart` — ajout : `streamGlobalCategories`,
  `getGlobalCategories`, `create/update/deleteGlobalCategory`, `uploadCategoryImage`
  (`menu_categories/…`), `imageForCategoryName`, `ensureGlobalCategories`,
  `seedGlobalCategoriesFromMenuItems`. `importMenu` réécrit → alimente le catalogue global.
- `lib/screens/categories/global_categories_screen.dart` — NOUVELLE page sidebar
  « Catégories » : grille, fallback gris, upload/bibliothèque/retrait image, renommer,
  supprimer, bouton « Récupérer les catégories existantes » (seed).
- `lib/widgets/sidebar.dart` + `lib/screens/dashboard/dashboard_screen.dart` — entrée
  sidebar `categories` câblée.
- `lib/screens/menu/menu_item_editor_screen.dart` — utilise `GlobalCategory`,
  n'hérite QUE l'image (suppléments par défaut supprimés).
- `lib/screens/menu/menu_management_screen.dart` — onglet « Catégories » retiré
  (désormais global) ; bouton « Ajouter un menu entier » bien visible ; passe les
  catégories globales à l'éditeur de plat.
- `lib/screens/menu/import_menu_screen.dart` — **upload fichier .txt** (`file_picker`)
  en plus du collage ; image de catégorie résolue auto depuis les catégories globales.
- `pubspec.yaml` — ajout `file_picker: ^8.1.2` (`flutter pub get` OK).

`flutter analyze` : 0 erreur (1 `info` préexistant `dart:html` non lié).

### Devenu orphelin (non supprimé, sans risque)
`menu_category.dart`, `category_editor_screen.dart`, `image_library_screen.dart`
et les méthodes per-restaurant du service (`streamCategories`, `ensureCategory`…)
ne sont plus utilisés. À nettoyer plus tard si souhaité.

## ⚠️ À VÉRIFIER côté Firebase (pas encore fait)
0. **NOUVEAU** : règles Firestore pour la collection racine **`menuCategories`**
   (lecture publique client + écriture admin) et règles Storage pour le préfixe
   **`menu_categories/`** (écriture admin).
1. **Règles Storage** : autoriser écriture admin sur `menu_library/` et
   `menuItems/{restaurantId}/`.
2. **Règles Firestore** : autoriser l'admin à écrire `menuImageLibrary` et la
   sous-collection `restaurants/{id}/categories`.

## 🔜 RESTE À FAIRE — prochaine session

### App client (`nomade_client`) — rendre les options data-driven
- Modifier `lib/screens/food/addToOrder/add_to_order_screen.dart` : lire
  `widget.menuItem.optionGroups` (depuis Firestore) au lieu des listes hardcodées
  `_extras` / `_sauces`.
- Étendre le modèle client `lib/models/menu_item.dart` avec `optionGroups`
  (le client a déjà `ExtraOption` / `SauceOption` / `OrderItem` avec extras+sauces).
- **Fallback** : si `optionGroups` absent (plats créés par l'app resto Kotlin),
  garder le comportement actuel (extras/sauces par défaut) pour ne rien casser.
- Mapper `OptionGroup`/`OptionChoice` (price = supplément) vers l'UI de sélection
  (single = radio, multiple = checkboxes ; respecter `required`).

### Tests à faire côté admin
- Lancer l'app admin, uploader 2-3 images bibliothèque, créer des catégories,
  importer le menu STR'EAT, vérifier dans Firestore que `menuItems` ont bien
  `imageUrl` (image catégorie) + `optionGroups`.
