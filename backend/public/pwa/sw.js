// Service worker do app web Jotalle (escopo /app/): deixa o app abrir sem internet.
const CACHE = 'jotalle-v9';
const ARQUIVOS = ['/app/', '/pwa/app.js', '/pwa/style.css', '/pwa/manifest.webmanifest', '/img/logo.png',
  '/pwa/icon-192.png', '/pwa/apple-touch-icon.png'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ARQUIVOS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});

self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return; // mapas/endereço/API: direto na rede
  if (!ARQUIVOS.includes(u.pathname)) return;
  // cache primeiro, atualizando em segundo plano
  e.respondWith(caches.open(CACHE).then(async c => {
    const hit = await c.match(e.request, { ignoreSearch: true });
    const rede = fetch(e.request).then(r => { if (r.ok) c.put(e.request, r.clone()); return r; }).catch(() => hit);
    return hit || rede;
  }));
});
