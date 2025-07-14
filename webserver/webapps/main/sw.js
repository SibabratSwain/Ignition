const CACHE_NAME = 'ignition-perspective-v1';
const STATIC_CACHE = 'ignition-static-v1';
const DYNAMIC_CACHE = 'ignition-dynamic-v1';

// Files to cache immediately
const STATIC_FILES = [
  '/web/',
  '/web/manifest.json',
  '/web/icons/icon-192x192.png',
  '/web/icons/icon-512x512.png',
  '/web/css/perspective.css',
  '/web/js/perspective.js'
];

// Install event - cache static files
self.addEventListener('install', event => {
  console.log('Service Worker: Installing...');
  
  event.waitUntil(
    caches.open(STATIC_CACHE)
      .then(cache => {
        console.log('Service Worker: Caching static files');
        return cache.addAll(STATIC_FILES);
      })
      .then(() => {
        console.log('Service Worker: Static files cached');
        return self.skipWaiting();
      })
      .catch(error => {
        console.error('Service Worker: Error caching static files:', error);
      })
  );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  console.log('Service Worker: Activating...');
  
  event.waitUntil(
    caches.keys()
      .then(cacheNames => {
        return Promise.all(
          cacheNames.map(cacheName => {
            if (cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE) {
              console.log('Service Worker: Deleting old cache:', cacheName);
              return caches.delete(cacheName);
            }
          })
        );
      })
      .then(() => {
        console.log('Service Worker: Activated');
        return self.clients.claim();
      })
  );
});

// Fetch event - serve from cache or network
self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Skip non-GET requests
  if (request.method !== 'GET') {
    return;
  }
  
  // Skip external requests
  if (!url.origin.includes(location.origin)) {
    return;
  }
  
  // Handle different types of requests
  if (url.pathname.startsWith('/')) {
    // Perspective app requests
    event.respondWith(handlePerspectiveRequest(request));
  } else if (url.pathname.startsWith('/data/')) {
    // Data API requests - always try network first
    event.respondWith(handleDataRequest(request));
  } else {
    // Other requests - cache first
    event.respondWith(handleStaticRequest(request));
  }
});

// Handle Perspective app requests
async function handlePerspectiveRequest(request) {
  try {
    // Try network first for app requests
    const networkResponse = await fetch(request);

    if (networkResponse.ok) {
      // Cache successful responses
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
      return networkResponse;
    }

    throw new Error('Network response not ok');
  } catch (error) {
    console.log('Service Worker: Network failed, trying cache for:', request.url);

    // Fall back to cache
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    // Return offline page if available
    const offlineResponse = await caches.match('/web/offline.html');
    if (offlineResponse) {
      return offlineResponse;
    }

    // Return a simple offline message
    return new Response(
      '<html><body><h1>Offline</h1><p>Please check your connection and try again.</p></body></html>',
      {
        headers: { 'Content-Type': 'text/html' }
      }
    );
  }
}

// Handle data API requests
async function handleDataRequest(request) {
  try {
    // Always try network first for data
    const response = await fetch(request);
    return response;
  } catch (error) {
    console.log('Service Worker: Data request failed:', request.url);

    // Return cached data if available
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    // Return error response
    return new Response(
      JSON.stringify({ error: 'Network unavailable', offline: true }),
      {
        headers: { 'Content-Type': 'application/json' }
      }
    );
  }
}

// Handle static requests
async function handleStaticRequest(request) {
  try {
    // Try cache first
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }

    // Fall back to network
    const networkResponse = await fetch(request);

    if (networkResponse.ok) {
      // Cache successful responses
      const cache = await caches.open(DYNAMIC_CACHE);
      cache.put(request, networkResponse.clone());
    }

    return networkResponse;
  } catch (error) {
    console.log('Service Worker: Static request failed:', request.url);

    // Return offline response
    return new Response(
      '<html><body><h1>Offline</h1><p>Resource not available offline.</p></body></html>',
      {
        headers: { 'Content-Type': 'text/html' }
      }
    );
  }
}