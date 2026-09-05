# Notifications Telegram admin — nouvelle commande / nouvelle course VTC

> Session du 05/09/2026. Fait, vérifié (message test reçu dans le groupe) et
> **déployé en prod**. Suite de `travaux7.md`.

## Pourquoi

Les 3 admins reçoivent déjà une notif push (FCM) à chaque nouvelle commande
resto et nouvelle course VTC (fonction `notifyAdmins`, appelée par
`onOrderCreated` et `onTaxiRideCreated`). Mais le push FCM web ne sonne que
si un onglet admin est ouvert avec un token enregistré — les admins ont
demandé un relais **Telegram** (groupe commun), plus fiable pour être notifié
même sans avoir l'admin ouvert.

## Ce qui a été fait

Tout le code est dans `nomade_client\functions\index.js` (Cloud Functions
partagées) — rien à changer côté admin Flutter ni côté apps Kotlin.

1. **Bot Telegram créé** : `@Velox_admin_bot` (via BotFather).
2. **Groupe Telegram "Velox Admin"** créé, avec le bot + les 3 admins comme
   membres. `chat_id` du groupe : `-5167613042`.
3. **Secrets Firebase** (Secret Manager, pas en clair dans le code) :
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_CHAT_ID` (`-5167613042`)
   configurés via `firebase functions:secrets:set ... --project nomade253-478a9`.
4. **Code** (`functions/index.js`) :
   - `defineSecret` pour les deux secrets (import `firebase-functions/params`).
   - Nouvelle fonction `notifyTelegram(title, body)` — appelle
     `https://api.telegram.org/bot<TOKEN>/sendMessage` (fetch natif, Node 24,
     pas de dépendance ajoutée), best-effort (try/catch interne, ne lève
     jamais).
   - `notifyAdmins(title, body, data)` appelle désormais `notifyTelegram`
     **en plus** de l'envoi FCM existant — un seul point d'entrée pour les
     deux canaux, donc `onOrderCreated` et `onTaxiRideCreated` en bénéficient
     automatiquement sans dupliquer de code.
   - `onOrderCreated` et `onTaxiRideCreated` déclarent maintenant
     `secrets: [TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID]` dans leurs options
     (obligatoire pour que Cloud Functions injecte les secrets au runtime).

## Déployé le 05/09/2026

`firebase deploy --only functions:onOrderCreated,functions:onTaxiRideCreated --project nomade253-478a9`
— déploiement réussi, secrets accessibles par le compte de service runtime.

## Test effectué

Message de test envoyé directement via l'API Telegram (`sendMessage`) avec
le même token/chat_id que ceux configurés en secret — bien reçu dans le
groupe "Velox Admin". Le déclenchement réel via `onOrderCreated` /
`onTaxiRideCreated` n'a pas été testé avec un faux document Firestore
(risque de polluer les données de prod / déclencher un push vers un vrai
restaurant) — se confirmera à la prochaine vraie commande/course.

## Pour retrouver le bot / groupe

- Bot : `@Velox_admin_bot` (créé par le compte Telegram de l'utilisateur).
- Groupe : "Velox Admin", `chat_id = -5167613042`.
- Token stocké uniquement dans Firebase Secret Manager
  (`TELEGRAM_BOT_TOKEN`, projet `nomade253-478a9`) — pas dans ce dépôt, pas
  dans le code en clair.
