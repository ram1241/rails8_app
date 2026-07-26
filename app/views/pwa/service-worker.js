// =============================================================================
// PWA SERVICE WORKER — Rails 8 Built-in PWA Support
// =============================================================================
// This file is served by Rails at GET /service-worker (config/routes.rb)
// Registered in app/views/layouts/application.html.erb
//
// Caching Strategy used here: "Cache First, then Network"
//   1. On install: pre-cache the app shell (HTML, CSS, JS)
//   2. On fetch: serve from cache if available, otherwise fetch from network
//   3. On activate: clean up old caches
//
// This makes the app work offline and load instantly on repeat visits.
// =============================================================================

const CACHE_NAME = "rails8-app-v1";

// App shell: resources to pre-cache on service worker install
const PRECACHE_URLS = [
  "/",
  "/projects",
  "/manifest",
  "/icon.png",
  "/icon.svg"
];

// ---------------------------------------------------------------------------
// INSTALL — Pre-cache the app shell
// ---------------------------------------------------------------------------
self.addEventListener("install", (event) => {
  console.log("[ServiceWorker] Install");
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log("[ServiceWorker] Pre-caching app shell");
      return cache.addAll(PRECACHE_URLS);
    }).then(() => self.skipWaiting())
  );
});

// ---------------------------------------------------------------------------
// ACTIVATE — Clean up old caches from previous versions
// ---------------------------------------------------------------------------
self.addEventListener("activate", (event) => {
  console.log("[ServiceWorker] Activate");
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => {
            console.log("[ServiceWorker] Deleting old cache:", name);
            return caches.delete(name);
          })
      );
    }).then(() => self.clients.claim())
  );
});

// ---------------------------------------------------------------------------
// FETCH — Cache-first strategy with network fallback
// ---------------------------------------------------------------------------
self.addEventListener("fetch", (event) => {
  // Skip non-GET requests (POST, PATCH, DELETE — let them go to network)
  if (event.request.method !== "GET") return;

  // Skip Action Cable WebSocket connections
  if (event.request.url.includes("/cable")) return;

  // Skip Mission Control Jobs UI (always needs fresh data)
  if (event.request.url.includes("/jobs")) return;

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        // Serve from cache, but also update cache in background (stale-while-revalidate)
        fetch(event.request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, networkResponse.clone());
            });
          }
        }).catch(() => {}); // Ignore network errors during background update

        return cachedResponse;
      }

      // Not in cache — fetch from network and cache the response
      return fetch(event.request).then((networkResponse) => {
        if (!networkResponse || networkResponse.status !== 200 || networkResponse.type === "opaque") {
          return networkResponse;
        }

        caches.open(CACHE_NAME).then((cache) => {
          cache.put(event.request, networkResponse.clone());
        });

        return networkResponse;
      }).catch(() => {
        // Network failed and not in cache — show offline fallback
        if (event.request.destination === "document") {
          return caches.match("/");
        }
      });
    })
  );
});

// ---------------------------------------------------------------------------
// PUSH NOTIFICATIONS — (uncomment to enable Web Push)
// ---------------------------------------------------------------------------
// self.addEventListener("push", async (event) => {
//   const { title, options } = await event.data.json()
//   event.waitUntil(self.registration.showNotification(title, options))
// })
