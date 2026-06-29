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

## ✅ FAIT 2026-06-25 (app admin) — Suppléments ciblés par catégorie à l'import — compile (`flutter analyze` OK)

**Problème** : à l'import d'un menu complet, la case « Appliquer à tous » collait les
suppléments (fromage, viande…) sur **chaque** plat, y compris les boissons (Coca se
voyait proposer Emmental/Œuf côté client). Décision validée : **cibler par catégorie**.

**Syntaxe fichier texte** : préciser les catégories entre parenthèses après le titre
de la section, ex. `SUPPLÉMENTS (Hamburgers, Tacos)`. Sans parenthèse → comportement
historique (appliqué à toutes les catégories, rétro-compat). Préfixe « pour : » toléré.

### Fichiers modifiés
- `lib/services/menu_parser.dart` — `ParsedMenu` étendu : `supplementCategories`
  (List<String> en minuscules, nettoyées via `_cleanCategoryName`) +
  `supplementCategoriesSpecified` (bool). Le parser extrait la parenthèse de la ligne
  « Suppléments », découpe sur `, ; /`.
- `lib/screens/menu/import_menu_screen.dart` — remplace le booléen `_applySupplementsToAll`
  par `Map<String,bool> _supplementCategories` (nom catégorie → appliquer). Pré-coché
  depuis le fichier (si spécifié) sinon toutes les catégories. Aperçu : `FilterChip` par
  catégorie (éditable). Import : suppléments ajoutés uniquement aux catégories cochées.
  Renommer une catégorie déplace aussi sa sélection de suppléments. Aide format mise à jour.

## ✅ FAIT 2026-06-25 (suite) — Parser : support du format « Davido » — compile (`flutter analyze` OK)

**Problème** : import du menu `MENU DAVIDO.txt` → « Aucun plat détecté ». Le parser
n'acceptait QUE le format STR'EAT : séparateur deux-points `:` **et** devise `FDJ`.
Davido utilise un tiret/demi-cadratin `–` **et** la devise `FJ` → 0 correspondance.

### Fichier modifié — `lib/services/menu_parser.dart`
- `_itemRegex` / `_menuPriceRegex` : séparateur élargi `[:–—-]` (deux-points OU
  tiret/demi-cadratin/cadratin) ; devise `(?:FDJ|FJ|DJF)` ; nombres tolèrent virgule.
- **Nom sur ligne séparée du prix** (cas Davido « Plats Africains » :
  `Yassa poulet ou poisson` puis `(accompagnement riz blanc) – 3500 FJ`) : ajout d'un
  `pendingName` — quand le nom détecté commence par `(`, on reprend la dernière ligne
  texte précédente comme vrai nom. `pendingName` réinitialisé sur en-tête et après
  chaque plat.

### Validation (script jetable `dart run`, supprimé après)
- Davido : **16 catégories, 81 plats** (avant : 0). Noms « Plats Africains » corrects.
- STR'EAT (non-régression) : **5 catégories, 28 plats**, formules « menu », tailles
  Tacos M/L/XL et suppléments toujours OK.

## ✅ FAIT 2026-06-25 (suite) — Import JSON (voie fiable « tous menus ») — compile (`flutter analyze` OK)

**Décision** : un parser texte heuristique ne couvrira jamais tous les formats de
menus. Voie principale fiable = **import d'un JSON normalisé** (produit par une IA :
DeepSeek/Claude). L'IA absorbe le chaos (texte, photo…) → schéma fixe → import
déterministe. Parser texte conservé comme dépannage. Fichiers d'exemple :
`C:\Users\PC\Desktop\FINAL 253 NOMADE\Resto app\MENU\deepseek_json_*.json`.

### Schéma JSON supporté
```json
{
  "categories": ["Burgers", "Tacos", "Boissons"],
  "menu": {
    "Burgers": [ { "nom": "Cheeseburger", "prix_seul": 800, "prix_menu": 1100 } ],
    "Boissons": [ { "nom": "Coca", "prix": 250 } ],
    "Tacos":   [ { "taille": "M", "base": 1100,
                   "supplements": { "Kebab": 400 }, "extra": 100 } ],
    "supplements": [ { "nom": "Cheddar", "prix": 100 } ]
  }
}
```
- Plats `nom/prix_seul/prix_menu` → Formule single si `prix_menu`.
- Boissons `nom/prix` simples.
- Tailles `taille/base` (Tacos) → fusionnées en 1 plat + groupe « Taille » ; `supplements`
  (map) + `extra` → groupe « Suppléments » **propre au plat**.
- `menu.supplements` (array) → suppléments globaux.
- Métadonnées restaurant (nom/email/tél/adresse/status) **ignorées** (import dans un
  resto déjà existant).

### Fichiers
- `lib/services/menu_json_parser.dart` — NOUVEAU : `MenuJsonParser.tryParse(raw)`
  → `ParsedMenu?` (null si pas du JSON exploitable). Réutilise le modèle `ParsedMenu`
  → aperçu/images/chips inchangés.
- `lib/services/menu_parser.dart` — `ParsedItem` étendu : `extraGroups` (groupes
  d'options pré-construits, ajoutés par `buildOptionGroups`).
- `lib/screens/menu/import_menu_screen.dart` :
  - `_parse()` tente `MenuJsonParser.tryParse` d'abord, sinon `MenuParser.parse`.
  - File picker accepte `.json` + `.txt`.
  - **Défaut intelligent suppléments** : quand le fichier ne cible pas de catégories,
    on coche toutes SAUF boissons/desserts/cocktails/glaces/cafés/jus/eau (regex
    `_noSupplementCat`). Règle aussi le « Coca + fromage » pour les menus non ciblés.
  - Anti-doublon : pas de groupe « Suppléments » global ajouté à un plat qui a déjà le
    sien (ex. Tacos).

### Validation (script jetable, supprimé)
4 fichiers DeepSeek parsés OK : catégories/plats/formules ; Tacos fusionnés (Taille +
Suppléments propres) ; Boissons/Desserts sans supplément.

### Documentation & gabarit (2026-06-26)
- `FORMAT_MENU.md` (racine du projet) — NOUVEAU : format canonique JSON + règles,
  format texte de dépannage, et **le prompt IA** réutilisable (DeepSeek/Claude) pour
  générer le JSON depuis n'importe quel menu.
- `.../Resto app/MENU/MENU DAVIDO.json` — NOUVEAU : conversion fidèle du menu Davido
  au schéma JSON (16 catégories, 90 plats ; Sandwichs avec formule Menu +500 ;
  `supplements: []`). Sert de gabarit de référence. Validé : import OK.

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
