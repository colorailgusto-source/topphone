importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyD_f2tZ3nEXOsC41XaM3yu0HLykhI_25Sg",
  authDomain: "topphone-540f2.firebaseapp.com",
  projectId: "topphone-540f2",
  storageBucket: "topphone-540f2.firebasestorage.app",
  messagingSenderId: "868593927763",
  appId: "1:868593927763:web:18f84bdffaf2f90d5ea8a6",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notificationTitle = payload.notification?.title || 'TopPhone';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data,
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});
