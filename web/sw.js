// Service Worker para Pertin PWA
// Mantém o app funcionando em background e permite notificações

const CACHE_NAME = 'pertin-cache-v2';
const ALARM_SOUND_LOCAL = '/assets/assets/sounds/alarm.ogg';
const ALARM_SOUND_FALLBACK = 'https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg';

// Arquivos para cache offline
const urlsToCache = [
  '/',
  '/index.html',
  '/manifest.json',
  '/flutter_bootstrap.js',
  '/pertin_web_helper.js',
  '/icons/Icon-192.png',
  '/icons/Icon-512.png',
  ALARM_SOUND_LOCAL
];

// Instalação do Service Worker
self.addEventListener('install', (event) => {
  console.log('[SW] Instalando Service Worker...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Cache aberto');
        return cache.addAll(urlsToCache);
      })
      .catch((err) => {
        console.log('[SW] Erro ao cachear:', err);
      })
  );
  self.skipWaiting();
});

// Ativação
self.addEventListener('activate', (event) => {
  console.log('[SW] Service Worker ativado');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[SW] Removendo cache antigo:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  self.clients.claim();
});

// Interceptar requisições
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Retorna do cache ou faz a requisição
        return response || fetch(event.request);
      })
  );
});

// Receber mensagens do app
self.addEventListener('message', (event) => {
  const data = event.data;
  
  if (data.type === 'TRIGGER_ALARM') {
    triggerAlarmNotification(data.destination);
  }
  
  if (data.type === 'CHECK_DISTANCE') {
    // Pode ser usado para verificações periódicas
    console.log('[SW] Verificando distância...');
  }
});

// Mostrar notificação de alarme
async function triggerAlarmNotification(destination) {
  const title = '🚌 VOCÊ CHEGOU!';
  const options = {
    body: destination || 'Você está próximo do seu destino!',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    vibrate: [500, 200, 500, 200, 500],
    tag: 'pertin-alarm',
    requireInteraction: true, // Não some automaticamente
    actions: [
      { action: 'open', title: 'Abrir App' },
      { action: 'stop', title: 'Parar Alarme' }
    ]
  };
  
  try {
    await self.registration.showNotification(title, options);
    console.log('[SW] Notificação de alarme enviada!');
  } catch (err) {
    console.error('[SW] Erro ao mostrar notificação:', err);
  }
}

// Clique na notificação
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notificação clicada:', event.action);
  event.notification.close();
  
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Tenta focar em uma janela existente
        for (const client of clientList) {
          if ('focus' in client) {
            client.focus();
            client.postMessage({ type: 'ALARM_CLICKED', action: event.action });
            return;
          }
        }
        // Se não há janela, abre uma nova
        if (clients.openWindow) {
          return clients.openWindow('/');
        }
      })
  );
});

// Push notifications (para futuro uso com servidor)
self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};
  
  if (data.type === 'alarm') {
    event.waitUntil(triggerAlarmNotification(data.destination));
  }
});

console.log('[SW] Service Worker carregado!');
