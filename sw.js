// Veross Scraper AI — Service Worker
// Estratégia: Network First (sempre busca dados frescos do servidor)
// Cache apenas de assets estáticos (ícones, fontes, logo)

const CACHE_NAME = 'veross-scraper-ai-v1';
const STATIC_ASSETS = [
  '/icon-192.png',
  '/icon-512.png',
  '/uploads/logo-scraper-ai-crop.png',
];

// Instala e pré-cacheia assets estáticos
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS).catch(() => {
        // Silencia erros de pré-cache (ex: offline na instalação)
      });
    })
  );
  self.skipWaiting();
});

// Ativa e limpa caches antigos
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  self.clients.claim();
});

// Fetch: Network First — volta ao cache se offline
self.addEventListener('fetch', (event) => {
  // Ignora requisições non-GET e requests para Supabase/n8n
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (
    url.hostname.includes('supabase.co') ||
    url.hostname.includes('webhook.veross') ||
    url.hostname.includes('fonts.googleapis') ||
    url.hostname.includes('fonts.gstatic') ||
    url.hostname.includes('cdn.jsdelivr')
  ) return;

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Cacheia assets estáticos com sucesso
        if (response.ok && STATIC_ASSETS.some(a => url.pathname.endsWith(a.replace('/', '')))) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      })
      .catch(() => {
        // Offline: tenta servir do cache
        return caches.match(event.request);
      })
  );
});
