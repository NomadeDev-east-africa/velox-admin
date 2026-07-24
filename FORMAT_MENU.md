# Format d'import des menus — directives

Ce document décrit **le format à respecter pour importer le menu de n'importe quel
restaurant** dans l'app admin (page *Gérer le menu → Ajouter un menu entier*).

Deux formats sont acceptés :

1. **JSON** (recommandé) — fiable pour **tous** les menus, quelle que soit leur mise
   en forme d'origine. C'est le format canonique.
2. **Texte libre** — pratique pour un import rapide sans IA, mais heuristique (peut se
   tromper sur des mises en forme inhabituelles). À réserver au dépannage.

Dans les deux cas, un **aperçu éditable** s'affiche avant l'import : on peut renommer,
corriger les prix, supprimer des plats et choisir à quelles catégories appliquer les
suppléments. Rien n'est écrit en base tant qu'on n'a pas cliqué *Importer*.

---

## 1. Format JSON (canonique)

### Schéma

```json
{
  "restaurant": "Nom du resto (facultatif, ignoré à l'import)",
  "categories": ["Burgers", "Tacos", "Boissons"],
  "menu": {
    "Burgers": [
      { "nom": "Cheeseburger", "prix_seul": 800, "prix_menu": 1100 }
    ],
    "Boissons": [
      { "nom": "Coca", "prix": 250 }
    ],
    "Tacos": [
      { "taille": "M", "base": 1100, "supplements": { "Kebab": 400 }, "extra": 100 },
      { "taille": "L", "base": 1700, "supplements": { "Kebab": 400 }, "extra": 100 }
    ],
    "supplements": [
      { "nom": "Cheddar", "prix": 100 }
    ]
  }
}
```

### Règles

- **Tous les prix sont des entiers en FDJ** — pas de symbole, pas de décimale, pas
  d'espace (`1500`, pas `1 500 FDJ`).
- **Les prix du JSON sont les prix BRUTS du restaurant.** À l'import, une **grille
  tarifaire** ajoute une marge par tranche de prix (voir ci-dessous), mais
  **uniquement sur les plats principaux**. Ne pré-calcule jamais la marge dans le
  JSON.
- **`categories`** : liste qui fixe l'ordre d'affichage des catégories.
- **`menu`** : un objet dont chaque clé est un **nom de catégorie**, sauf la clé
  spéciale **`supplements`** (voir plus bas).
- **Plat avec formule menu** → `{ "nom", "prix_seul", "prix_menu" }`. Si pas de
  formule, mettre `"prix_menu": null` ou utiliser la forme simple ci-dessous.
- **Plat simple** (boisson, dessert, accompagnement…) → `{ "nom", "prix" }`.
- **Plat à tailles** (Tacos M/L/XL…) → une entrée **par taille** :
  `{ "taille", "base", "supplements"?, "extra"? }`.
  - `base` = prix de cette taille.
  - `supplements` = map `nom → prix` des suppléments **propres à ce plat**.
  - `extra` = prix d'un ingrédient supplémentaire (facultatif).
  - À l'import, les tailles sont **fusionnées en un seul plat** avec un sélecteur
    « Taille ».
- **`menu.supplements`** (tableau `{ "nom", "prix" }`) = suppléments **généraux**
  (fromage, œuf…). À l'import ils sont proposés à toutes les catégories **sauf**
  boissons / desserts / cocktails / glaces / cafés / jus / eau. Laisser `[]` si le
  restaurant n'a pas de suppléments.
- **Ne jamais mettre de suppléments aux boissons, desserts, glaces, cafés ni jus.**
- **Conserver les vrais noms** ; ne pas traduire. Ne jamais inventer un prix : si un
  prix manque, mettre `null`.

### Options explicites d'un plat — champ `options` (facultatif)

Quand un plat a des **choix** que la génération automatique ne devine pas (garniture
de crêpe, boisson incluse dans un menu, type de pâtes, sauces au choix…), on les
déclare via un tableau **`options`** — utilisable sur **n'importe quel** plat (simple,
à formule menu ou à tailles). Chaque entrée devient un groupe d'options du plat :

```json
{
  "nom": "Steak de bœuf",
  "prix": 3000,
  "options": [
    { "nom": "Suppléments", "type": "multiple",
      "choix": [ { "nom": "Sauce roquefort", "prix": 600 }, { "nom": "Sauce poivre", "prix": 600 } ] },
    { "nom": "Garniture", "type": "single", "obligatoire": true,
      "choix": [ { "nom": "Frites", "prix": 0 }, { "nom": "Riz", "prix": 0 } ] }
  ]
}
```

- `type` : `"single"` (choix unique / radio) ou `"multiple"` (cases à cocher). Défaut multiple.
- `obligatoire` : `true`/`false` (défaut false) — force un choix pour un groupe `single`.
- `maxChoices` : plafond de sélections pour un groupe `multiple` (ex. Tacos XL → `2`,
  Tacos XXL → `3`). Absent ou `0` = illimité. Ignoré pour un groupe `single` (= 1).
- `choix` : liste d'objets `{ "nom", "prix" }` (ou de simples chaînes → prix 0).
- `prix` d'un choix = **supplément** ajouté au prix de base (`0` = inclus). Un choix
  d'option **ne reçoit AUCUNE marge** : sauces, extras et suppléments sont vendus au
  prix brut resto (voir la grille tarifaire).
- Ordre d'affichage des groupes : Taille (si tailles) → Formule (si `prix_menu`) → `options`.
- Une **boisson incluse** dans un menu se déclare comme un groupe `single` à `prix 0`
  (ex. `{ "nom": "Boissons", "type": "single", "choix": [ {"nom":"Coca","prix":0}, … ] }`).

### ⚠️ Sauces gratuites vs sauces payantes — RÈGLE CRITIQUE de nommage

Le nom du **groupe** n'est pas cosmétique : l'app client s'en sert pour décider si
les choix sont des **sauces** (offertes/incluses) ou des **suppléments** (payants).
La règle exacte, côté client : *un groupe dont le nom contient le mot « sauce »
(insensible à la casse et aux accents) voit ses choix reversés dans le panier comme
des sauces ; tout autre nom → suppléments.*

Conséquence à respecter **impérativement** :

- **Sauces gratuites** (incluses, `prix: 0`) → groupe nommé **`Sauces`**.
  ```json
  { "nom": "Sauces", "type": "multiple",
    "choix": [ { "nom": "Ketchup", "prix": 0 }, { "nom": "Mayonnaise", "prix": 0 } ] }
  ```
- **Sauces payantes** (`prix > 0`) → ce sont des **suppléments**. Le groupe se nomme
  **`Suppléments`** (jamais « Sauces »), et on garde le mot « Sauce » **dans le nom du
  choix** pour que le ticket cuisine reste lisible :
  ```json
  { "nom": "Suppléments", "type": "multiple",
    "choix": [ { "nom": "Sauce roquefort", "prix": 600 }, { "nom": "Sauce poivre", "prix": 600 } ] }
  ```

> ❌ **À ne jamais faire** : un groupe nommé `Sauces` contenant des choix à prix > 0.
> Le client les traiterait comme des sauces incluses/offertes alors qu'elles sont
> payantes → prix et catégorie faussés. Un choix payant va **toujours** dans un
> groupe `Suppléments`.

### Grille tarifaire (marge appliquée à l'import)

Les prix du JSON sont **bruts** (prix resto). À l'import, une marge FIXE est ajoutée
selon la tranche de prix — logique de **seuil** : la tranche s'étend jusqu'au seuil
suivant, aucun prix ne « tombe dans un trou ».

| Tranche (prix brut) | Marge |
|---|---|
| < 300 | +0 |
| 300 – 799 | +50 |
| 800 – 1399 | +100 |
| 1400 – 1849 | +150 |
| 1850 – 2349 | +200 |
| 2350 – 2849 | +250 |
| 2850 – 3399 | +300 |
| 3400 – 3849 | +350 |
| 3850 – 4399 | +400 |
| 4400 – 4849 | +500 |
| 4850 – 7999 | +600 |
| 8000 – 9999 | +1000 |
| 10000 – 19999 | +1500 |
| 20000 – 29999 | +2000 |
| ≥ 30000 | +2500 |

**La marge ne s'applique qu'aux PLATS PRINCIPAUX** (prix de base, formule menu, prix
par taille). Sont vendus au **prix brut, sans aucune marge** :

- toute la **catégorie boisson** (boissons, jus, cocktails, cafés, thés, eau,
  smoothies… — mais **pas** les desserts ni les glaces, qui sont de la nourriture) ;
- toute **boisson reconnue par son nom** (coca, fanta, sprite, mizo, grenadine,
  perrier…), même si elle est rangée dans une catégorie mal nommée — filet de sécurité ;
- les **frites** vendues seules (nom commençant par « frite ») ;
- **tous les choix d'options** : sauces, extras, suppléments.

> Implémentation : `MenuParser.markupPrice` (la grille) + `MenuParser.applyPricingGrid`
> (la passe qui distingue plat / boisson / frite / option), appelée une seule fois
> dans `import_menu_screen.dart`. La classification boisson/frite est **corrigeable
> dans l'aperçu** avant import.

### Exemple complet réel

Voir **`MENU DAVIDO CORRIGE.json`** (dossier `.../Resto app/MENU/`) : conversion fidèle du
menu *Chez David'O* (16 catégories, 81 plats), à utiliser comme gabarit de référence. Il
illustre notamment la convention ci-dessus : ses sauces payantes (roquefort, poivre… à
600 FDJ) sont dans un groupe **`Suppléments`**, avec des choix nommés « Sauce roquefort »,
« Sauce poivre », etc.

> L'ancien `MENU DAVIDO.json` / `MENU DAVIDO from PDF.json` est **obsolète** : il plaçait
> ces sauces payantes dans un groupe nommé `Sauces` (l'anti-pattern décrit plus haut).
> Ne pas s'en servir comme modèle.

---

## 2. Format texte (dépannage)

Le parser texte reconnaît, ligne par ligne :

- **En-têtes de catégorie** : lignes en **MAJUSCULES** (ex. `HAMBURGERS`,
  `BOISSONS`). Une parenthèse explicative est tolérée (`HAMBURGERS (prix seul)`).
- **Plats avec prix** : `Nom : 600 FDJ` **ou** `Nom – 1800 FJ`.
  - Séparateur accepté : deux-points `:` **ou** tiret `-` / `–` / `—`.
  - Devise acceptée : `FDJ`, `FJ` ou `DJF`.
  - Formule menu : `Cheeseburger : 600 FDJ (menu 900 FDJ)`.
- **Nom et prix sur deux lignes** : si le nom est sur une ligne et le prix sur la
  parenthèse suivante, le parser reprend la ligne précédente comme nom
  (ex. `Yassa poulet ou poisson` / `(accompagnement riz blanc) – 3500 FJ`).
- **Tailles** : `Taille M`, `Taille L`… au-dessus des variantes.
- **Section suppléments** : un titre `SUPPLÉMENTS`. Pour les limiter à certaines
  catégories (et exclure les boissons), les préciser entre parenthèses :
  `SUPPLÉMENTS (Hamburgers, Tacos)`.

> ⚠️ Le format texte reste heuristique. En cas de menu inhabituel, **préférer le JSON**.

---

## 3. Prompt IA (pour générer le JSON depuis n'importe quel menu)

Coller ce prompt dans une IA (DeepSeek, Claude…) suivi du menu (texte brut, copié, ou
décrit depuis une photo). L'IA renvoie le JSON, qu'on colle ensuite dans l'app.

```
Tu es un convertisseur de menus de restaurant. Je te donne un menu (texte brut,
copié, ou décrit). Réponds UNIQUEMENT par un objet JSON valide, sans texte autour,
selon EXACTEMENT ce schéma :

{
  "categories": ["NomCat1", "NomCat2"],
  "menu": {
    "NomCat1": [
      { "nom": "Nom du plat", "prix_seul": 800, "prix_menu": 1100 }
    ],
    "Boissons": [
      { "nom": "Coca", "prix": 250 }
    ],
    "Tacos": [
      { "taille": "M", "base": 1100, "supplements": { "Kebab": 400 }, "extra": 100 }
    ],
    "supplements": [
      { "nom": "Cheddar", "prix": 100 }
    ]
  }
}

Règles :
- Tous les prix sont des entiers en FDJ (pas de symbole, pas de décimale).
- "prix_menu" = prix de la formule menu si elle existe, sinon null.
- Pour les plats simples sans formule (boissons, desserts, accompagnements),
  utilise { "nom": ..., "prix": ... }.
- Pour les plats à tailles (Tacos M/L/XL), une entrée par taille avec "taille",
  "base" (prix de cette taille) et, si applicable, "supplements" (map nom->prix)
  et "extra" (prix d'un ingrédient supplémentaire).
- "supplements" à la racine de "menu" = suppléments généraux (fromage, œuf…)
  qui s'appliquent aux plats salés. NE PAS mettre de suppléments aux boissons,
  desserts, glaces, cafés ni jus.
- Si un plat a des CHOIX (garniture, boisson incluse, type de pâtes, sauces au
  choix…), ajoute-lui un tableau "options" : chaque groupe = { "nom", "type"
  ("single" ou "multiple"), "obligatoire" (bool), "maxChoices" (int, facultatif),
  "choix": [ { "nom", "prix" } ] }. "prix" d'un choix = supplément (0 = inclus).
  Une boisson incluse dans un menu = groupe "single" à prix 0. "maxChoices" borne
  un groupe "multiple" (ex. tacos XL = 2 viandes → "maxChoices": 2). N'invente pas
  de choix : n'en mets que s'ils figurent au menu.
- RÈGLE DES SAUCES (impérative) : le nom du groupe décide du traitement côté client.
  * Sauces GRATUITES (prix 0) → groupe nommé exactement "Sauces".
  * Sauces PAYANTES (prix > 0) → ce sont des suppléments : groupe nommé "Suppléments"
    (JAMAIS "Sauces"), et garde le mot "Sauce" dans le nom du choix
    (ex. "Sauce roquefort", "prix": 600). Ne mets JAMAIS un choix à prix > 0 dans un
    groupe nommé "Sauces".
- Conserve les vrais noms de plats. Ne traduis pas. N'invente aucun prix : si un
  prix manque, mets null.

Voici le menu :
<<< COLLE LE MENU ICI >>>
```

---

## Procédure d'import (résumé)

1. Convertir le menu en JSON via le prompt ci-dessus (ou écrire le JSON à la main).
2. App admin → **Gérer le menu** → **Ajouter un menu entier**.
3. Charger le fichier `.json` **ou** coller le JSON, puis **Analyser**.
4. Vérifier l'aperçu : noms, prix, images de catégorie, cases de suppléments.
5. **Importer**.
