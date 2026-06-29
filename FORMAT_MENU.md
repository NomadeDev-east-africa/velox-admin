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

### Exemple complet réel

Voir **`MENU DAVIDO.json`** (dossier `.../Resto app/MENU/`) : conversion fidèle du menu
*Chez David'O* (16 catégories, 90 plats), à utiliser comme gabarit de référence.

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
