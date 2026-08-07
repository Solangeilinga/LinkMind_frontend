// firebase-messaging-sw.js
// Service worker requis par Firebase Cloud Messaging pour le web.
// Sans ce fichier (à la racine du site déployé), FirebaseMessaging.getToken()
// échoue sur navigateur, et aucune notification n'est reçue quand l'onglet
// est en arrière-plan ou fermé.
//
// Ces valeurs sont les mêmes que web.apiKey/appId/... de lib/firebase_options.dart
// — ce sont des identifiants publics côté client, pas des secrets (comme la clé
// API d'un site web classique) : les exposer ici est normal et attendu.

importScripts('https://www.gstatic.com/firebasejs/10.13.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB3h-OutEla4kU3SFwi1KTM79XVXrC1R5M',
  appId: '1:20517091319:web:8dc5006a6240766556a0f2',
  messagingSenderId: '20517091319',
  projectId: 'linkmind-917b4',
  authDomain: 'linkmind-917b4.firebaseapp.com',
  storageBucket: 'linkmind-917b4.firebasestorage.app',
});

const messaging = firebase.messaging();

// Notification affichée quand l'app/onglet est en arrière-plan ou fermé.
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || 'BASYAM';
  const options = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };
  self.registration.showNotification(title, options);
});

// Ouvre/focus l'app quand l'utilisateur clique sur la notification.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) return client.focus();
      }
      if (clients.openWindow) return clients.openWindow('/');
    }),
  );
});