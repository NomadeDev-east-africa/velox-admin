importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAnB3rGmqc5qnhEDRAmsYklkf8gkrrF0LA",
  authDomain: "nomade253-478a9.firebaseapp.com",
  projectId: "nomade253-478a9",
  storageBucket: "nomade253-478a9.firebasestorage.app",
  messagingSenderId: "91637120258",
  appId: "1:91637120258:web:21b836dcfd7c173b59d61b",
});

// Affiche une notification système quand l'onglet admin est fermé/en arrière-plan.
// Le cas premier-plan (onglet ouvert) est géré côté Dart via FirebaseMessaging.onMessage.
firebase.messaging();
