# Travaux 4 — Analyse chaîne menu (Admin → Client) + prompt de modif app client

> Contexte de session pour reprise. Dernière mise à jour : 2026-06-15.
> Suite de `travaux3.md` (2026-06-14) et `travauxMenu.md` (2026-06-13).
> **Session d'analyse** (peu/pas de code écrit côté admin) : préparer la modif de l'app
> **client** `nomade_client` pour rendre les options de plat *data-driven*.

## Écosystème (rappel)

| App | Techno | Chemin | Rôle |
|---|---|---|---|
| **Admin** | Flutter web | `C:\Users\PC\Desktop\ReelADMIN\ADMIN3\NOMADE_ADMIN_COMPLETE` (projet courant) | Crée les menus (`menuItems` + `menuCategories`) |
| **Restaurant** | Android Kotlin | `C:\Users\PC\StudioProjects\Velox_Restaurant` | **NE PAS MODIFIER** — affiche tickets de commande |
| **Client** | Flutter (Riverpod) | `C:\Users\PC\StudioProjects\nomade_client` | Passe commande. **À modifier (cette préparation)** |

Firebase : `nomade253-478a9`. Firestore **camelCase** strict.

---

## 0) État au début de session

- **Règles Storage : RÉGLÉES** par l'utilisateur (le point #1 « reste à faire » de `travaux3.md`
  est clos). Préfixes admin (`menu_categories/`, `menu_library/`, `menuItems/`, `restaurants/`) OK.

---

## 1) Analyse — comment les menus sont créés côté Admin

### Deux chemins de création
1. **Import fichier/texte** : `import_menu_screen.dart` → `MenuParser.parse` (`lib/services/menu_parser.dart`)
   → `MenuManagementService.importMenu` (batch 450/commit, `lib/services/menu_management_service.dart`).
   Le parser génère automatiquement les `optionGroups` :
   - **Tailles** (Tacos M/L/XL) → groupe **« Taille »** `single`, **requis**. La plus petite
     taille fixe le prix de base ; les autres = delta (`prix − base`). Ex : M=base, L `+600`, XL `+1200`.
   - **Formule** « menu 900 FDJ » → groupe **« Formule »** `single` non requis : `[Seul +0, Menu +300]`.
   - Section **« Suppléments »** détectée à part (`globalSupplements`), appliquée optionnellement.
2. **Éditeur manuel** : `lib/widgets/option_groups_editor.dart` — nom de groupe **libre**, type
   (Choix unique / Choix multiple), case **Obligatoire**, N choix `{name, price}` (price = supplément).

➡️ **Les noms de groupes ne sont PAS limités à extras/sauces** (Taille, Formule, Viande,
Suppléments, Sauces…). Le client doit être **100 % data-driven**, sans présumer du nom.

### Ce que contient un plat `menuItems/{id}` (`lib/models/menu_item.dart`)
`restaurantId`, `name`, `description`, `price` (base, FDJ), `imageUrl?` (héritée de la
catégorie), `category`, `isAvailable`, `preparationTime`, `createdAt`, `updatedAt`, et surtout :

**`optionGroups` (Array<Map>)** — modèle `lib/models/option_group.dart` :
```
{
  "name": "Taille",                 // libellé du groupe (libre)
  "type": "single" | "multiple",    // single = radio (1 choix), multiple = checkboxes (0..N)
  "required": true | false,         // si true + single → un choix obligatoire
  "choices": [ { "name": "L", "price": 600 } ]  // price = SUPPLÉMENT ajouté à la base (0 = inclus)
}
```
Exemples STR'EAT : Formule `[Seul +0, Menu +300]`, Taille `[M +0, L +600, XL +1200]`,
Suppléments multiple `[Emmental +100, Cheddar +100, Œuf +100]`.

### Catégories
`menuCategories` (collection racine) ne porte **que** `name` + `imageUrl` (+ `order`, `storagePath`).
**Aucune option n'y vit** — tout est copié sur chaque plat. Le client n'a **rien à lire dans
`menuCategories`** pour les options ; un plat hérite uniquement de l'**image** de sa catégorie.

---

## 2) ⚠️ Contrainte de compatibilité CRITIQUE (app resto Kotlin — NE PAS CASSER)

Vérifié dans `Velox_Restaurant/.../data/remote/FirestoreMapper.kt` (fonction `toOrderItem`,
~ligne 97) et `data/model/OrderItem.kt` :
- L'app resto lit le ticket et **ne lit QUE les clés `extras` et `sauces`** d'un order item.
- `extractStringList` est **tolérant** : pour chaque entrée → String tel quel, ou `Map["name"]`.
  Elle ne lit **que le nom** (ignore prix/isSelected) et **aucune autre clé** d'options.

➡️ **Conséquence** : quelle que soit la nouvelle UI client, au moment d'ajouter au panier il
FAUT reverser les choix sélectionnés (nom + prix) dans les tableaux **`extras`/`sauces`** de
l'`OrderItem`. Sinon les options choisies n'apparaissent PAS sur le ticket cuisine.
**Mapping retenu** : tous les choix sélectionnés → `extras` (avec prix), SAUF les groupes dont
le nom contient « sauce » (insensible casse/accents) → `sauces`.

---

## 3) Analyse — état actuel de l'app client (le problème)

- `lib/screens/food/addToOrder/add_to_order_screen.dart`, méthode `_initializeExtrasAndSauces`
  (~lignes 40-58) : extras et sauces **codés en dur**, génériques pour tous les plats/restos
  (Frites/Tomates/… 500 FDJ ; Samouraï/Mayo/… 50 FDJ). Ne viennent PAS de Firestore.
- `lib/models/menu_item.dart` (client) : a `discountPercentage` mais **PAS** `optionGroups`.
- `lib/models/order_item.dart` : `OrderItem` avec `extras: List<ExtraOption>`,
  `sauces: List<SauceOption>`, calculs `extrasTotal`/`unitPrice`/`totalPrice`, `toMap()`.
- `lib/models/extra_option.dart` / `sauce_option.dart` : `{name, price, isSelected}` (identiques).

### Règles d'affichage à appliquer côté client
Pour chaque `optionGroup` (dans l'ordre) : en-tête = `name` (+ badge REQUIS si `required`) ;
`single` → radios (présélectionner le 1er si `required`) ; `multiple` → checkboxes ;
afficher « + {price} FDJ » si `price>0` sinon « Inclus » ; total = base + Σ(suppléments
sélectionnés) × quantité ; valider qu'un groupe `single+required` a un choix.
**Fallback** : si `optionGroups` absent (plats créés par l'app resto) → garder le comportement
hardcodé actuel pour ne rien casser.

---

## 4) Livrable de la session : PROMPT pour l'agent Claude Code du projet `nomade_client`

> Prompt autonome (ne nécessite pas l'accès au projet admin). À copier-coller tel quel à
> l'agent qui travaille sur `nomade_client`.

```markdown
# Tâche : rendre les options de plat data-driven (lire `optionGroups` depuis Firestore)

## Contexte projet
App : `nomade_client` (Flutter, Riverpod), client de livraison NOMADE (Djibouti).
Firebase : `nomade253-478a9`. Firestore en **camelCase strict** (aucun underscore).
Écosystème : une app Admin (Flutter web) crée les menus, une app Restaurant (Android
Kotlin, NE PAS MODIFIER) affiche les tickets de commande, et CE client passe commande.

## Le problème à résoudre
Dans `lib/screens/food/addToOrder/add_to_order_screen.dart`, les extras et les sauces
sont **codés en dur** (méthode `_initializeExtrasAndSauces`, ~lignes 40-58) : génériques,
identiques pour tous les plats et tous les restaurants. Ils ne viennent PAS de Firestore.

Or l'app Admin écrit désormais sur chaque plat un champ **`optionGroups`** décrivant les
vraies options (formules, tailles, suppléments, sauces…). Le client doit afficher CES
options à la place des listes hardcodées.

## Schéma Firestore à lire : `menuItems/{id}.optionGroups` (Array<Map>)
optionGroups: [
  {
    "name": "Taille",                 // libellé du groupe (libre : Taille/Formule/Suppléments/Sauces…)
    "type": "single" | "multiple",    // single = radio (1 choix), multiple = checkboxes (0..N)
    "required": true | false,         // si true + single → un choix est obligatoire
    "choices": [
      { "name": "M",  "price": 0   }, // price = SUPPLÉMENT en FDJ ajouté au prix de base (0 = inclus)
      { "name": "L",  "price": 600 },
      { "name": "XL", "price": 1200 }
    ]
  },
  {
    "name": "Suppléments", "type": "multiple", "required": false,
    "choices": [ {"name":"Emmental","price":100}, {"name":"Cheddar","price":100} ]
  }
]
Règles importantes :
- Les noms de groupes sont **libres** : NE PAS coder en dur "extras"/"sauces". Rendu 100% générique.
- `price` d'un choix = supplément ajouté au `price` de base du plat (pas un prix absolu).
- Le champ peut être **absent** : les plats créés par l'ancienne app resto n'ont pas `optionGroups`.

## ⚠️ Contrainte de compatibilité CRITIQUE (app resto Kotlin — ne pas casser)
L'app restaurant lit le ticket de commande et **ne lit QUE les clés `extras` et `sauces`**
de chaque order item, et **uniquement le `name`** de chaque entrée (elle tolère String ou
Map avec un champ `name`, et ignore prix/isSelected). Elle ignore toute autre clé.

➡️ Donc : quelle que soit la nouvelle UI, au moment d'ajouter au panier, il FAUT reverser
les choix sélectionnés (nom + prix) dans les tableaux **`extras`** et/ou **`sauces`** de
l'`OrderItem`. Sinon les options choisies n'apparaîtront PAS sur le ticket cuisine.
Mapping demandé : mettre tous les choix sélectionnés dans `extras` (avec leur prix), SAUF
les groupes dont le nom contient « sauce » (insensible casse/accents) → ceux-là dans `sauces`.

## Fichiers concernés
- `lib/models/menu_item.dart` — modèle client actuel (a déjà `discountPercentage`, PAS `optionGroups`).
- `lib/models/order_item.dart` — `OrderItem` (champs `extras: List<ExtraOption>`, `sauces: List<SauceOption>`, calculs `extrasTotal`/`unitPrice`/`totalPrice`, `toMap`).
- `lib/models/extra_option.dart` / `lib/models/sauce_option.dart` — `{name, price, isSelected}`.
- `lib/screens/food/addToOrder/add_to_order_screen.dart` — écran à refondre.

## Travail à faire
1. **Créer** `lib/models/option_group.dart` : classes `OptionGroup {name, type, required, choices}`
   et `OptionChoice {name, price}`, enum `OptionType {single, multiple}`, avec
   `fromMap`/`listFromRaw` (tolérant : `type` par défaut multiple, `price` num→int, listes nullables).
2. **Étendre** `lib/models/menu_item.dart` : ajouter `List<OptionGroup> optionGroups` (défaut `[]`),
   le parser dans `fromFirestore` via `OptionGroup.listFromRaw(data['optionGroups'])`, l'ajouter
   à `toMap` et `copyWith`. Ne rien retirer (garder `discountPercentage`, etc.).
3. **Refondre** `add_to_order_screen.dart` :
   - Si `widget.menuItem.optionGroups` NON vide → générer dynamiquement une section par groupe :
     en-tête = `group.name` (+ badge « REQUIS » si `required`) ; `single` → radios (présélectionner
     le 1er choix si `required`) ; `multiple` → checkboxes. Afficher « + {price} FDJ » si `price>0`,
     sinon « Inclus ». Réutiliser le style visuel existant (`_buildSectionHeader`, etc.).
   - Si `optionGroups` vide → **fallback** : conserver EXACTEMENT le comportement hardcodé actuel.
   - Total = `price` + Σ(suppléments des choix sélectionnés), × quantité. Mettre à jour le bouton.
   - Validation avant ajout panier : tout groupe `single + required` doit avoir un choix sélectionné
     (sinon snackbar + bloquer).
4. **Ajout au panier** (`_addItemToCart`) : convertir les choix sélectionnés en `ExtraOption`/
   `SauceOption` (nom + prix, `isSelected: true`) selon la règle de mapping ci-dessus, pour que
   `OrderItem.toMap()` écrive bien `extras`/`sauces` lisibles par l'app resto. Vérifier que
   `basePrice`, `unitPrice`, `totalPrice` restent cohérents.

## Contraintes
- Ne PAS modifier le schéma Firestore ni les noms de champs (camelCase imposé).
- Ne RIEN écrire de nouveau qui casserait la lecture du ticket par l'app resto.
- `flutter analyze` doit rester à 0 erreur. Ne pas toucher aux autres écrans.

## Validation attendue
- Plat AVEC `optionGroups` (ex. Tacos M/L/XL, Cheeseburger Seul/Menu, Suppléments) → options
  réelles affichées, total correct, choix reversés dans extras/sauces.
- Plat SANS `optionGroups` (ancien plat resto) → extras/sauces par défaut, aucun changement.
```

---

## 🔜 RESTE À FAIRE (après cette session)

1. **App client** : transmettre le prompt ci-dessus à l'agent `nomade_client` et exécuter la modif
   (`optionGroups` data-driven + mapping extras/sauces pour compat resto).
2. **Horaires** (toujours en attente, cf. `travaux3.md`) : faire lire `restaurants/{id}.openingHours`
   au client pour afficher ouvert/fermé + bloquer la commande hors horaires (porter `OpeningHours`).
3. **Test bout-en-bout admin** : récupérer catégories + images, importer menu STR'EAT, créer un
   restaurant avec horaires, vérifier `menuItems` (`imageUrl` + `optionGroups`) dans Firestore.
4. (Optionnel) Analyser l'écran **liste du menu** client (item cards, regroupement par catégorie)
   si l'affichage de la liste elle-même doit évoluer.

## Fichiers admin consultés cette session (lecture seule, aucune modif code admin)
`lib/models/option_group.dart`, `lib/models/menu_item.dart`,
`lib/services/menu_management_service.dart`, `lib/services/menu_parser.dart`,
`lib/widgets/option_groups_editor.dart`.
Côté client : `lib/models/menu_item.dart`, `order_item.dart`, `extra_option.dart`,
`add_to_order_screen.dart`. Côté resto (lecture compat) : `FirestoreMapper.kt`, `OrderItem.kt`.
