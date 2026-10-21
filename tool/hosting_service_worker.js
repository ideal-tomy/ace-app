'use strict';

// 古い Flutter Service Worker が残っている端末向け:
// キャッシュを全削除してから自身を解除し、最新の index.html を再読み込みする。
self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const cacheKeys = await caches.keys();
      await Promise.all(cacheKeys.map((key) => caches.delete(key)));

      try {
        await self.registration.unregister();
      } catch (error) {
        console.warn('Failed to unregister service worker:', error);
      }

      const clients = await self.clients.matchAll({ type: 'window' });
      for (const client of clients) {
        if (client.url && 'navigate' in client) {
          await client.navigate(client.url);
        }
      }
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  if (
    url.pathname.endsWith('/index.html') ||
    url.pathname.endsWith('/main.dart.js') ||
    url.pathname.endsWith('/flutter_bootstrap.js') ||
    url.pathname.endsWith('/flutter.js')
  ) {
    event.respondWith(fetch(event.request));
  }
});
