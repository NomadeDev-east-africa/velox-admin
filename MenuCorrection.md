# MenuCorrection — Résumé de la session « menus »

> Récapitulatif complet du travail effectué sur l'import de menus (admin NOMADE)
> et sur les JSON de menus des restaurants.
> Projet : `C:\Users\PC\Desktop\ReelADMIN\ADMIN3\NOMADE_ADMIN_COMPLETE`

---

## 1. Modifications de code (dans ce dépôt)

| Fichier | Changement |
|---|---|
| `lib/services/menu_management_service.dart` | Ajout de `deleteAllMenuItems(restaurantId)` — supprime **tous** les plats d'un restaurant par batch (450 écritures max / commit). Ne touche pas aux catégories globales ni aux autres restaurants. Retourne le nombre de plats supprimés. |
| `lib/screens/menu/menu_management_screen.dart` | Nouveau bouton **« Supprimer menu entier »** dans l'AppBar (à côté de « Ajouter un menu entier »), rouge, avec `_deleteWholeMenu()` et dialogue de confirmation fort (action irréversible). |
| `lib/models/option_group.dart` | Nouveau champ **`maxChoices`** (int, défaut `0` = illimité) sur `OptionGroup`. Écrit dans Firestore **uniquement si > 0** → strictement additif, ne pollue pas les documents existants. Pertinent seulement pour un groupe `multiple` (un groupe `single` vaut toujours 1 choix). Pris en compte dans `toMap` / `fromMap` / `copyWith`. |
| `lib/services/menu_json_parser.dart` | Nouveau champ **`options`** dans le JSON d'import : permet de déclarer des groupes d'options explicites sur **n'importe quel plat** (simple ou avec tailles). Nouveau helper `_parseOptions()` qui accepte `nom`/`name`, `type` (`single`\|`unique` sinon `multiple`), `obligatoire`/`required`/`requis`, `maxChoices`/`max`/`nombre`, `choix`/`choices` (objets `{nom, prix}` ou simples chaînes). |
| `lib/widgets/option_groups_editor.dart` | Champ **« Max : »** dans l'éditeur d'options, affiché uniquement pour un groupe `multiple` (placeholder `∞`). Ajouté à `_GroupDraft` (lecture `fromGroup`, écriture `toGroup`). |
| `FORMAT_MENU.md` | Nouvelle section « Options explicites d'un plat — champ `options` (facultatif) » : type, obligatoire, `maxChoices`, `choix`, sémantique des prix (supplément additif sur la base), ordre des groupes (Taille → Formule → options), et le motif « boisson incluse = groupe `single` à prix 0 ». Règle correspondante ajoutée au prompt de conversion IA. |

`flutter analyze` : **0 issue** après chaque modification.

---

## 2. Rappels du pipeline d'import

```
fichier / texte
  → MenuJsonParser.tryParse(raw) ?? MenuParser.parse(raw)
  → ParsedMenu
  → aperçu éditable (option_groups_editor)
  → MenuManagementService.importMenu
  → Firestore : menuItems + menuCategories
```

- **`markupPrice`** : `(prix_brut * 1.1 / 100).round() * 100` — **+10 % arrondi à la centaine**, appliqué à **tous** les prix à l'import.
  → **Les fichiers JSON contiennent donc les prix BRUTS du restaurant.**
- **`standardizeCategoryName`** : retire les `(...)`, retire les `:–-` de fin, retire « Nos/Notre » en tête, puis **capitalise et pluralise chaque mot**.
  Conséquence : attention aux noms de catégories — voir §4.
- **Groupes auto-générés** : `Taille` (entrées avec tailles ; la plus petite fixe la base, les autres sont des deltas), `Formule` (depuis `prix_menu`), `Suppléments` (depuis `supplements`).
- **Compat app resto (Kotlin)** : elle ne lit que les clés `extras` et `sauces` d'un item de commande, et seulement le `name` de chaque entrée. Toute évolution de schéma doit rester **additive**.

---

## 3. Règle `maxChoices` — réservée à L'As du Tacos

À la demande explicite du client, `maxChoices` n'est utilisé **que** dans `menu L'As du Tacos.json`
(Tacos XL → 2 viandes, XXL → 3 viandes), pour ne pas perturber les autres menus.
Vérifié : **0 occurrence** de `maxChoices` dans tous les autres JSON.

> ⚠️ **À faire côté client** : l'app `nomade_client` doit encore **faire respecter** `maxChoices`
> dans son UI de commande (le champ existe et part bien en Firestore, mais rien ne le contraint).

---

## 4. Pièges rencontrés sur les noms de catégories

Le pluraliseur applique la règle à **chaque mot** — d'où :

| Nom écrit | Résultat après standardisation | Correction retenue |
|---|---|---|
| `Paninis, sandwichs & wraps` | `Paninis,s Sandwichs & Wraps` | `Sandwichs & wraps` |
| `Fish burger` | `Fishs Burgers` | `Burgers poisson` |
| `Burgers viande & chicken` | `Burgers Viandes & Chickens` | `Burgers viande` |
| `Entrées du midi` | `Entrées Du Midis` | `Salades & soupes` |
| `Plats du jour` | `Plats Du Jours` | `Grillades & filets` |

**Règle pratique** : éviter la ponctuation en fin de mot et les mots invariables non reconnus.

---

## 5. Menus livrés (hors dépôt)

Emplacement : `C:\Users\PC\Desktop\FINAL 253 NOMADE\Resto app\MENU\`

| Restaurant | Fichier | Contenu |
|---|---|---|
| **Chez David'O** | `MENU DAVIDO from PDF.json` | 16 catégories / 81 plats. Sauces en supplément sur Viandes / Poissons / Sandwichs, groupe « Type de pâtes », Formule + Boissons sur burgers & sandwichs, Garniture sur les crêpes, options extraites des noms (« grillé **ou** pané », « grillées **ou** sautées », « bœuf **ou** poulet »). Extrait du PDF 20 Mo via `pymupdf` (appariement nom/prix par coordonnées y). |
| **L'As du Tacos** | `menu L'As du Tacos.json` | 5 catégories / 14 plats. Tacos L / XL / XXL en **3 plats séparés**. **Seul fichier utilisant `maxChoices`** (XL = 2, XXL = 3). |
| **Snow Cream** | `menu Snowcream.json` | 10 catégories / 59 plats. Pas de `maxChoices`. |
| **Healthy Zone** | `menu image/Healthy_Zone_menu.json` | 10 catégories / 40 plats. **Reconstruit intégralement** : le fichier précédent avait déjà les +10 % intégrés (Salade VH Petite à 800 au lieu de 750) et des arrondis à 50 incohérents (Poulet Petite 950 au lieu de 900). Repris sur les prix bruts de l'image. |
| **TFC Restaurant** | `menu image/TFC_Restaurant_menu.json` | 26 catégories / 308 plats. Extrait d'un Excel multi-feuilles via `openpyxl`. |

### Infos TFC transmises par le restaurant
- Nouveau numéro : **+253 77 61 12 84**
- Horaires : tous les jours **7h – 23h**, petit déjeuner **7h – 10h**
- Cuisine : petit déjeuner (foie, reins…), éthiopien, indien, sénégalais, tacos…
- **Pas de formule en menu** — toutes les boissons sont listées dans le menu
- **Sauce au choix uniquement pour tacos et shawarma** : moutarde, ketchup, mayonnaise, algérienne, samouraï
- Choix des crudités autorisé pour les burgers

### Dernières corrections Snow Cream
- **Tacos** : groupe `Sauce` **obligatoire** (`single`) — Mixte / Algérienne / Samouraï.
- **Brochettes** : l'item unique est remplacé par **3 plats « sautées »**, chacun avec un groupe `Sauce` obligatoire Nature (0) / Crème (+200) :
  - Brochettes de **viande** sautées — **1100** (changement de prix)
  - Brochettes de **poisson** sautées — 900
  - Brochettes de **poulet** sautées — 900

---

## 6. Méthode de vérification (reproductible)

1. Écrire un `verify_menu.dart` temporaire à la racine du projet.
2. `dart run verify_menu.dart` — il exerce le **vrai** `MenuJsonParser` (Dart pur, pas de dépendance Flutter).
3. Inspecter les groupes parsés et la sortie de `OptionGroup.listToRaw(...)` — c'est **exactement** ce qui part en Firestore.
4. Supprimer le fichier temporaire.

Exemple de sortie obtenue pour Snow Cream (prix affichés = après +10 %) :

```
## Tacos & Frites
  - Tacos  1000 (menu 1200)
      → Formule[single]{Seul/Menu+200}
      + Choix de viande[single,req]{Viande hachée/Poulet}
      + Sauce[single,req]{Mixte/Algérienne/Samouraï}
## Brochettes & Steaks
  - Brochettes de viande sautées  1200 → Sauce[single,req]{Nature/Crème+200}
  - Brochettes de poisson sautées 1000 → Sauce[single,req]{Nature/Crème+200}
  - Brochettes de poulet sautées  1000 → Sauce[single,req]{Nature/Crème+200}
```

---

## 7. Reste à faire

- [ ] **Committer** les modifications de ce dépôt (6 fichiers ci-dessus) avant la mise en ligne Hostinger.
- [ ] `nomade_client` : faire **respecter `maxChoices`** dans l'UI de commande.
- [ ] (Optionnel) Nettoyer les fautes de frappe des noms TFC repris tels quels de l'Excel
      (« Meet Shawarma », « Mashroom », « Vegitable »…).
