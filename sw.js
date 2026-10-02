/* Nogari Bakehouse · Web Push V20 */
self.addEventListener('install', function(event){
  self.skipWaiting();
});

self.addEventListener('activate', function(event){
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function(event){
  var data = {};
  try { data = event.data ? event.data.json() : {}; }
  catch(e){ data = { body: event.data ? event.data.text() : 'Novo pedido na Nogari.' }; }

  var title = data.title || 'Nogari · Novo pedido';
  var options = {
    body: data.body || 'Há um novo pedido aguardando preparo.',
    icon: './nogari-icon-192.png',
    badge: './nogari-icon-192.png',
    tag: data.tag || 'nogari-novo-pedido',
    renotify: true,
    data: { url: data.url || '?nogari_admin=pedidos-novos' }
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function(event){
  event.notification.close();
  var raw = event.notification && event.notification.data ? event.notification.data.url : '';
  raw = String(raw || '?nogari_admin=pedidos-novos').replace(/^\/+/, '');
  var target = new URL(raw, self.registration.scope).href;
  event.waitUntil(
    self.clients.matchAll({ type:'window', includeUncontrolled:true }).then(function(clientList){
      for(var i=0;i<clientList.length;i++){
        var client = clientList[i];
        if('navigate' in client && 'focus' in client){
          return client.navigate(target).then(function(){ return client.focus(); });
        }
      }
      if(self.clients.openWindow) return self.clients.openWindow(target);
    })
  );
});
