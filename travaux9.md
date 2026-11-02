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
