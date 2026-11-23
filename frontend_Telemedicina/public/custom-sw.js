// Service Worker para Notificaciones Web Push (CU20 - Telemedicina)
// Maneja eventos nativos `push` y apertura contextual en `notificationclick`.

self.addEventListener('push', (event) => {
  let payload = {};
  if (event.data) {
    try {
      payload = event.data.json();
    } catch {
      payload = { title: 'Nueva notificación', body: event.data.text() };
    }
  }

  const title = payload.title || 'Hospital San Juan de Dios - Telemedicina';
  const options = {
    body: payload.body || 'Tienes una nueva notificación disponible.',
    icon: payload.icon || '/favicon.ico',
    badge: payload.badge || '/favicon.ico',
    data: payload.data || { url: '/notificaciones' },
    tag: payload.tag || 'telemedicina-notificacion',
    renotify: true,
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const rawUrl = (event.notification.data && event.notification.data.url) || '/notificaciones';
  const targetUrl = new URL(rawUrl, self.location.origin).href;

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url === targetUrl && 'focus' in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(targetUrl);
      }
      return undefined;
    })
  );
});
