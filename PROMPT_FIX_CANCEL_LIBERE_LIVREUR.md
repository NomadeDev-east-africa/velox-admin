# Bug : annulation admin ne libère pas le livreur

Bug trouvé dans le panel admin : le bouton "Annuler la commande" sur l'écran
des commandes food laisse un livreur bloqué à vie, incapable de revoir des
commandes disponibles.

**Fichier** : `lib/screens/orders/orders_screen.dart`, fonction `_confirmCancel`
(~ligne 547-580).

**Code actuel :**
```dart
await _firestore.collection('orders').doc(orderId).update({
  'status': 'cancelled',
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**Problème** : quand la commande annulée a déjà un livreur assigné
(`deliveryDriverId` présent, ex. statut "delivering"), cette écriture ne
touche QUE le document `orders/{orderId}`. Elle ne libère jamais
`livreurs/{deliveryDriverId}` (`isAvailable` / `currentOrderId`), contrairement
au flux normal côté app livreur (Velox_Livreur, `OrderRepositoryImpl.kt`,
fonction `cancelDelivery()`) qui fait ça en transaction atomique. Résultat :
`livreurs/{id}.currentOrderId` reste rempli indéfiniment, et
`Livreur.canAcceptOrders` (app Kotlin) reste bloqué à `false` pour toujours —
le livreur ne revoit plus jamais de commandes disponibles, sans aucun
message d'erreur.

**Corrige `_confirmCancel`** pour que l'annulation soit atomique (`WriteBatch`
ou transaction Firestore) :

1. Lire la commande pour récupérer `deliveryDriverId` AVANT l'update (ou
   utiliser une transaction pour éviter la race).
2. Dans le même batch/transaction :
   - `orders/{orderId}` : `status = 'cancelled'`, `updatedAt = serverTimestamp()`
     (comportement actuel, inchangé)
   - SI `deliveryDriverId` est présent : `livreurs/{deliveryDriverId}` :
     `isAvailable = true`, `currentOrderId = null`,
     `updatedAt = serverTimestamp()`

Vérifie aussi `taxi_rides_screen.dart` : si un bouton d'annulation similaire
existe pour les courses VTC avec un `driverId` déjà assigné, applique le même
correctif par analogie (libérer le chauffeur dans sa collection driver).

**Contexte additionnel** : un filet de sécurité serveur (Cloud Function
`onOrderCancelledReleaseDriver`, déclenchée sur `orders/{orderId}` onUpdate
quand `status` passe à `"cancelled"`) a déjà été ajouté et **déployé** côté
`nomade_client/functions/index.js` pour rattraper ce cas automatiquement.
Corrige quand même le panel admin — le fix Cloud Function est un filet de
sécurité asynchrone (délai de propagation), pas un remplacement pour un
comportement correct au clic.
