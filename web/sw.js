// Service Worker pour Video Maestro PWA
// Version et configuration
const CACHE_VERSION = 'v3.0.0';
const CACHE_NAME = `video-maestro-${CACHE_VERSION}`;
const OFFLINE_URL = '/offline.html';

// Ressources à mettre en cache immédiatement
const PRECACHE_ASSETS = [
  '/',
  '/manifest.json',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
];

// Patterns d'URLs à mettre en cache
const CACHE_PATTERNS = {
  static: /\.(js|css|woff2?|ttf|eot|svg)$/,
  images: /\.(png|jpg|jpeg|gif|webp|ico)$/,
  api: /^https:\/\/video-maestros-production\.up\.railway\.app\/api\//,
};

// Installation du Service Worker
self.addEventListener('install', (event) => {
  console.log('[SW] Installation en cours...');
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Mise en cache des assets critiques');
        return cache.addAll(PRECACHE_ASSETS);
      })
      .then(() => self.skipWaiting())
      .catch((error) => {
        console.error('[SW] Erreur lors de l\'installation:', error);
      })
  );
});

// Activation du Service Worker
self.addEventListener('activate', (event) => {
  console.log('[SW] Activation en cours...');
  
  event.waitUntil(
    caches.keys()
      .then((cacheNames) => {
        return Promise.all(
          cacheNames
            .filter((name) => name.startsWith('video-maestro-') && name !== CACHE_NAME)
            .map((name) => {
              console.log('[SW] Suppression ancien cache:', name);
              return caches.delete(name);
            })
        );
      })
      .then(() => self.clients.claim())
  );
});

// Stratégie de fetch intelligente
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Ignorer les requêtes non-HTTP
  if (!request.url.startsWith('http')) {
    return;
  }

  // Stratégie pour les fichiers statiques (CSS, JS, fonts)
  if (CACHE_PATTERNS.static.test(url.pathname)) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // Stratégie pour les images
  if (CACHE_PATTERNS.images.test(url.pathname)) {
    event.respondWith(cacheFirst(request));
    return;
  }

  // Stratégie pour les API calls (Network First avec cache fallback)
  if (CACHE_PATTERNS.api.test(request.url)) {
    event.respondWith(networkFirstWithTimeout(request, 5000));
    return;
  }

  // Stratégie par défaut (Network First)
  event.respondWith(networkFirst(request));
});

// Cache First: cherche d'abord dans le cache
async function cacheFirst(request) {
  try {
    const cached = await caches.match(request);
    if (cached) {
      return cached;
    }

    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.error('[SW] Cache First error:', error);
    const cached = await caches.match(request);
    if (cached) return cached;
    throw error;
  }
}

// Network First: réseau d'abord, puis cache
async function networkFirst(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.log('[SW] Network failed, trying cache:', request.url);
    const cached = await caches.match(request);
    if (cached) {
      return cached;
    }
    // Retourner une page offline pour les navigations
    if (request.mode === 'navigate') {
      const offlinePage = await caches.match(OFFLINE_URL);
      if (offlinePage) return offlinePage;
    }
    throw error;
  }
}

// Network First avec timeout
async function networkFirstWithTimeout(request, timeout = 5000) {
  try {
    const timeoutPromise = new Promise((_, reject) => {
      setTimeout(() => reject(new Error('Request timeout')), timeout);
    });

    const response = await Promise.race([
      fetch(request),
      timeoutPromise
    ]);

    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.log('[SW] Network timeout or failed, trying cache:', request.url);
    const cached = await caches.match(request);
    if (cached) {
      return cached;
    }
    throw error;
  }
}

// Background Sync pour les requêtes échouées
self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync:', event.tag);
  
  if (event.tag === 'sync-videos') {
    event.waitUntil(syncVideos());
  }
});

async function syncVideos() {
  try {
    console.log('[SW] Synchronisation des vidéos...');
    // Implémenter la logique de sync ici
  } catch (error) {
    console.error('[SW] Erreur sync:', error);
  }
}

// Push Notifications
self.addEventListener('push', (event) => {
  console.log('[SW] Push notification reçue');
  
  const data = event.data ? event.data.json() : {};
  const title = data.title || 'Video Maestro';
  const options = {
    body: data.body || 'Nouvelle notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [200, 100, 200],
    data: data.data || {},
    actions: [
      {
        action: 'open',
        title: 'Ouvrir',
      },
      {
        action: 'close',
        title: 'Fermer',
      }
    ]
  };

  event.waitUntil(
    self.registration.showNotification(title, options)
  );
});

// Gestion des clics sur les notifications
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification click:', event.action);
  
  event.notification.close();

  if (event.action === 'open') {
    event.waitUntil(
      clients.openWindow('/')
    );
  }
});

// Message handler pour communication avec l'app
self.addEventListener('message', (event) => {
  console.log('[SW] Message reçu:', event.data);

  if (event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }

  if (event.data.type === 'CACHE_URLS') {
    event.waitUntil(
      caches.open(CACHE_NAME)
        .then((cache) => cache.addAll(event.data.urls))
    );
  }

  if (event.data.type === 'CLEAR_CACHE') {
    event.waitUntil(
      caches.keys()
        .then((names) => Promise.all(names.map((name) => caches.delete(name))))
    );
  }
});

console.log('[SW] Service Worker chargé - Version:', CACHE_VERSION);
