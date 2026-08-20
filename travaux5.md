# Travaux 5 — Notifications admin (broadcast + push nouvelles commandes/courses)

> Contexte de session pour reprise. Dernière mise à jour : 2026-08-11.
> Suite de `travauxMenu.md` (point 5 « Notifications broadcast — pas construit », posé le
> 2026-08-02). Session **entièrement livrée et testée en production**, déployée sur
> https://nomade253-478a9.web.app.

## Écosystème (rappel)

| App | Techno | Chemin | Rôle vis-à-vis de cette session |
|---|---|---|---|
| **Admin** | Flutter web | `C:\Users\PC\Desktop\ReelADMIN\ADMIN3\NOMADE_ADMIN_COMPLETE` (projet courant) | Envoie des broadcasts + reçoit des push |
| **Cloud Functions** | Node 24 (Gen2) | `C:\Users\PC\StudioProjects\nomade_client\functions\index.js` | Toute la logique serveur (envoi FCM) |

Firebase : `nomade253-478a9`. Deux fonctionnalités **distinctes** livrées cette session :
1. **Broadcast** : l'admin envoie une notif à une audience (clients/restos/livreurs/chauffeurs).
2. **Push admin** : l'admin **reçoit** une notif à chaque nouvelle commande / course VTC.

---

## 1) Broadcast notifications (admin → audiences)

Audiences retenues (réponse à la question ouverte de `travauxMenu.md`) : les 4 — clients,
restaurants, livreurs, chauffeurs.

- `functions/index.js` — NOUVEAU `exports.sendBroadcastNotification` (`onCall`) : vérifie
  `admins/{uid}.role` ∈ {admin, super_admin} (aucune autre fonction `onCall` du fichier ne
  faisait ce contrôle — nécessaire ici, la fonction peut toucher toute la base). Mapping
  audience → collection (`clients→users`, `restaurants→restaurants`, `livreurs→livreurs`,
  `drivers→drivers`), lots de 500 tokens (`sendEachForMulticast`), nettoyage des tokens
  périmés. Retourne `{ perAudience: {audience:{targeted,sent,failed}}, totalSent, totalFailed }`.
- Admin : NOUVEAU `lib/screens/notifications/broadcast_notification_screen.dart` (formulaire
  titre/message + 4 cases audiences, dialog de confirmation, dialog de résultat) + entrée
  sidebar « Notifications » (`sidebar.dart` / `dashboard_screen.dart`) + dépendance
  `cloud_functions` ajoutée à `pubspec.yaml` (première fois dans l'admin).
- **Déployé et testé** : fonction créée, écran fonctionnel.

## 2) Push admin — nouvelles commandes / courses VTC

L'admin reçoit désormais une **vraie notification push navigateur (FCM Web)**, même onglet
en arrière-plan — pas juste une alerte in-app.

### Serveur (`functions/index.js`)
- NOUVEAU `exports.registerAdminFcmToken` (`onCall`) : écrit `fcmToken` sur `admins/{uid}`
  via l'Admin SDK (le champ n'existait pas ; règle Firestore `admins` = `allow write: if false`
  → écriture uniquement possible côté serveur, pas de modif de règles nécessaire).
- NOUVEAU helper interne `notifyAdmins(title, body, data)` : lit `admins`, filtre les docs
  avec `fcmToken`, `sendEachForMulticast` par lots de 500, nettoie les tokens périmés. Logs
  ajoutés : nombre d'admins ciblés + succès/échecs par envoi (utile pour debug futur).
- `onOrderCreated` et `onTaxiRideCreated` — appellent `notifyAdmins(...)` chacun dans son
  propre `try/catch` (isolé : ne doit jamais impacter validation des prix / notif resto /
  assignation chauffeur).

### Client web (admin)
- `pubspec.yaml` — ajout `firebase_messaging`.
- NOUVEAU `web/firebase-messaging-sw.js` — service worker (notif système si onglet fermé).
- `lib/constants.dart` — `webPushVapidKey` (clé publique VAPID fournie par l'utilisateur,
  Firebase Console → Cloud Messaging → Certificats Web Push).
- NOUVEAU `lib/services/admin_push_notifications_service.dart` — `initialize()` : demande
  permission → `getToken()` (avec retry 3x/délai croissant, cf. bug ci-dessous) → callable
  `registerAdminFcmToken` ; expose `Stream<RemoteMessage>` pour les messages premier-plan.
- `lib/screens/dashboard/dashboard_screen.dart` — init du service après connexion admin,
  affichage des messages premier-plan.

### 🐛 Bug majeur rencontré et résolu : `MissingPluginException` sur `getToken()`
Après premier déploiement, `getToken()` échouait systématiquement (`MissingPluginException`,
`FirebaseMessagingPlatform.instance` restait sur l'implémentation par défaut au lieu de
`FirebaseMessagingWeb`), **y compris en navigation privée** (donc pas une extension
navigateur) et malgré plugin correctement déclaré/compilé. **Cause réelle : cache de build
Flutter obsolète** (`.dart_tool`/`build` pas invalidés après l'ajout de `firebase_messaging`
au `pubspec.yaml`) — cause documentée côté communauté FlutterFire
([flutterfire#11798](https://github.com/firebase/flutterfire/issues/11798)). **Fix : `flutter
clean` avant rebuild.** Confirmé en inspectant la console en direct via Playwright MCP
(connexion réelle à l'admin) : après clean, `FirebaseMessagingWeb` s'initialise correctement.
Retry avec délai croissant (1s/2s/4s) conservé sur `getToken()` en filet de sécurité (race
connue service-worker-pas-encore-actif au tout premier chargement).

➡️ **Leçon retenue pour la suite** : après tout ajout de plugin Flutter Web à ce projet,
toujours `flutter clean` avant le premier build/déploiement — l'incrémental peut cacher un
plugin fantôme silencieusement (aucune erreur de compilation, juste un mauvais delegate au
runtime).

### UI notification (raffinée sur demande utilisateur)
- Bannière **`MaterialBanner`** (pas un `SnackBar`) → s'affiche **en haut** de l'écran,
  reste **20 secondes**, texte agrandi/gras.
- Couleur **vert fluo** (`primaryColor` de la charte Velox), texte/icône noirs pour contraste.
- **Son** : NOUVEAU `lib/services/notification_sound.dart` — joue
  `web/sounds/notification_admin.mp3` (fichier fourni par l'utilisateur, servi tel quel
  depuis `web/` comme `firebase-messaging-sw.js`), avec repli automatique sur un bip généré
  et embarqué en base64 (WAV, aucune dépendance externe) si le fichier custom est absent.

### Validation en production
Testé en conditions réelles (courses VTC créées via l'app, logs Cloud Functions suivis en
direct) : `notifyAdmins` trouve le token, `sendEachForMulticast` confirme le succès, bannière
verte + son reçus côté admin. **Fonctionnalité complète et opérationnelle.**

---

## Fichiers touchés (référence rapide)

- `nomade_client/functions/index.js` : `sendBroadcastNotification`, `registerAdminFcmToken`,
  `notifyAdmins`, hooks dans `onOrderCreated`/`onTaxiRideCreated`.
- Admin — nouveaux : `lib/screens/notifications/broadcast_notification_screen.dart`,
  `lib/services/admin_push_notifications_service.dart`, `lib/services/notification_sound.dart`,
  `web/firebase-messaging-sw.js`, `web/sounds/notification_admin.mp3`.
- Admin — modifiés : `pubspec.yaml` (+`cloud_functions`, +`firebase_messaging`),
  `lib/constants.dart` (+`webPushVapidKey`), `lib/widgets/sidebar.dart`,
  `lib/screens/dashboard/dashboard_screen.dart`.

## 🔜 Reste ouvert (mineur, pas bloquant)

- Cas **onglet totalement fermé** (pas juste arrière-plan) : l'infra service worker est en
  place mais n'a pas été testée explicitement dans ce cas précis (seulement onglet
  ouvert/premier-plan, confirmé fonctionnel).
- `firebase-functions` (package.json) signalé outdated par le CLI lors des déploiements —
  upgrade non fait (changements breaking annoncés), pas urgent.
