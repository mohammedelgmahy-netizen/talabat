// يخلي لوحة التحكم قابلة للتثبيت كبرنامج، وبيفتح بسرعة من النسخة المحفوظة. البيانات دايماً لايف من Supabase
const C = 'talabat-v2';
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((k) => Promise.all(k.filter((x) => x.startsWith('talabat-') && x !== C).map((x) => caches.delete(x)))));
  self.clients.claim();
});
self.addEventListener('fetch', (e) => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  // يفتح على طول من النسخة المحفوظة، ويحدثها من النت في الخلفية للمرة الجاية
  e.respondWith(
    caches.open(C).then(async (c) => {
      const hit = await c.match(e.request, { ignoreSearch: e.request.mode === 'navigate' });
      const net = fetch(e.request)
        .then((r) => {
          if (r.ok) c.put(e.request, r.clone());
          return r;
        })
        .catch(() => hit);
      if (hit) {
        e.waitUntil(net);
        return hit;
      }
      return net;
    }),
  );
});
