// Pertin Web Helper - Funções JavaScript para melhorar a experiência web
// Este arquivo adiciona funcionalidades que não estão disponíveis nativamente no Flutter Web

(function() {
  'use strict';

  // ========================================
  // REGISTRO DO SERVICE WORKER
  // ========================================
  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('/sw.js')
        .then((registration) => {
          console.log('[Pertin] Service Worker registrado:', registration.scope);
        })
        .catch((err) => {
          console.log('[Pertin] Falha ao registrar Service Worker:', err);
        });
    });
  }

  // ========================================
  // WAKE LOCK API - Mantém a tela ligada
  // ========================================
  let wakeLock = null;

  window.pertinRequestWakeLock = async function() {
    try {
      if ('wakeLock' in navigator) {
        wakeLock = await navigator.wakeLock.request('screen');
        console.log('[Pertin] Wake Lock ativado!');
        
        wakeLock.addEventListener('release', () => {
          console.log('[Pertin] Wake Lock liberado');
        });
        
        return true;
      }
    } catch (err) {
      console.log('[Pertin] Wake Lock não disponível:', err);
    }
    return false;
  };

  window.pertinReleaseWakeLock = function() {
    if (wakeLock) {
      wakeLock.release();
      wakeLock = null;
    }
  };

  // Reativar Wake Lock quando a aba fica visível novamente
  document.addEventListener('visibilitychange', async () => {
    if (wakeLock !== null && document.visibilityState === 'visible') {
      await window.pertinRequestWakeLock();
    }
  });

  // ========================================
  // NOTIFICATION API - Notificações do Browser
  // ========================================
  window.pertinRequestNotificationPermission = async function() {
    if (!('Notification' in window)) {
      console.log('[Pertin] Notificações não suportadas');
      return 'unsupported';
    }

    if (Notification.permission === 'granted') {
      return 'granted';
    }

    if (Notification.permission !== 'denied') {
      const permission = await Notification.requestPermission();
      return permission;
    }

    return Notification.permission;
  };

  window.pertinShowNotification = function(title, body, tag) {
    if (Notification.permission === 'granted') {
      // Usar Service Worker se disponível
      if ('serviceWorker' in navigator && navigator.serviceWorker.controller) {
        navigator.serviceWorker.controller.postMessage({
          type: 'TRIGGER_ALARM',
          destination: body
        });
        return true;
      }
      
      // Fallback para Notification API direta
      const notification = new Notification(title, {
        body: body,
        icon: '/icons/Icon-192.png',
        badge: '/icons/Icon-192.png',
        tag: tag || 'pertin-notification',
        requireInteraction: true,
        vibrate: [500, 200, 500, 200, 500]
      });

      notification.onclick = function() {
        window.focus();
        notification.close();
      };

      return true;
    }
    return false;
  };

  // ========================================
  // VIBRATION API
  // ========================================
  window.pertinVibrate = function(pattern) {
    if ('vibrate' in navigator) {
      navigator.vibrate(pattern || [500, 200, 500, 200, 500]);
      return true;
    }
    return false;
  };

  window.pertinStopVibration = function() {
    if ('vibrate' in navigator) {
      navigator.vibrate(0);
    }
  };

  // ========================================
  // AUDIO CONTEXT - Som mesmo em background
  // ========================================
  let audioContext = null;
  let alarmAudioBuffer = null;
  let alarmSource = null;

  window.pertinPreloadAlarmSound = async function() {
    try {
      audioContext = new (window.AudioContext || window.webkitAudioContext)();
      
      // Tenta carregar o som local primeiro (funciona offline)
      let response;
      try {
        response = await fetch('/assets/assets/sounds/alarm.ogg');
        if (!response.ok) throw new Error('Som local não encontrado');
      } catch (e) {
        // Fallback para URL externa se o local falhar
        console.log('[Pertin] Som local não encontrado, tentando URL externa...');
        response = await fetch('https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg');
      }
      
      const arrayBuffer = await response.arrayBuffer();
      alarmAudioBuffer = await audioContext.decodeAudioData(arrayBuffer);
      console.log('[Pertin] Som do alarme pré-carregado');
      return true;
    } catch (err) {
      console.log('[Pertin] Erro ao pré-carregar som:', err);
      return false;
    }
  };

  window.pertinPlayAlarmSound = function() {
    if (audioContext && alarmAudioBuffer) {
      // Resumir contexto se suspenso (necessário após interação do usuário)
      if (audioContext.state === 'suspended') {
        audioContext.resume();
      }

      alarmSource = audioContext.createBufferSource();
      alarmSource.buffer = alarmAudioBuffer;
      alarmSource.loop = true;
      alarmSource.connect(audioContext.destination);
      alarmSource.start(0);
      console.log('[Pertin] Alarme tocando!');
      return true;
    }
    return false;
  };

  window.pertinStopAlarmSound = function() {
    if (alarmSource) {
      try {
        alarmSource.stop();
        alarmSource = null;
      } catch (err) {
        console.log('[Pertin] Erro ao parar som:', err);
      }
    }
  };

  // ========================================
  // DETECÇÃO DE PLATAFORMA
  // ========================================
  window.pertinGetPlatformInfo = function() {
    const userAgent = navigator.userAgent || navigator.vendor || window.opera;
    
    const isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;
    const isAndroid = /android/i.test(userAgent);
    const isStandalone = window.matchMedia('(display-mode: standalone)').matches || 
                         window.navigator.standalone === true;
    const isMobile = isIOS || isAndroid;
    
    return {
      isIOS: isIOS,
      isAndroid: isAndroid,
      isMobile: isMobile,
      isStandalone: isStandalone, // Se foi instalado como PWA
      isPWA: isStandalone,
      userAgent: userAgent
    };
  };

  // ========================================
  // VERIFICAÇÃO DE VISIBILIDADE
  // ========================================
  window.pertinIsPageVisible = function() {
    return document.visibilityState === 'visible';
  };

  window.pertinOnVisibilityChange = function(callback) {
    document.addEventListener('visibilitychange', () => {
      callback(document.visibilityState === 'visible');
    });
  };

  // ========================================
  // KEEP ALIVE - Mantém conexão ativa
  // ========================================
  let keepAliveInterval = null;

  window.pertinStartKeepAlive = function() {
    if (keepAliveInterval) return;
    
    keepAliveInterval = setInterval(() => {
      // Faz uma pequena operação para manter o JS ativo
      const now = Date.now();
      if (window.pertinKeepAliveCallback) {
        window.pertinKeepAliveCallback(now);
      }
    }, 5000); // A cada 5 segundos
    
    console.log('[Pertin] Keep-alive iniciado');
  };

  window.pertinStopKeepAlive = function() {
    if (keepAliveInterval) {
      clearInterval(keepAliveInterval);
      keepAliveInterval = null;
      console.log('[Pertin] Keep-alive parado');
    }
  };

  // ========================================
  // FULLSCREEN API
  // ========================================
  window.pertinEnterFullscreen = function() {
    const elem = document.documentElement;
    if (elem.requestFullscreen) {
      elem.requestFullscreen();
    } else if (elem.webkitRequestFullscreen) {
      elem.webkitRequestFullscreen();
    }
  };

  window.pertinExitFullscreen = function() {
    if (document.exitFullscreen) {
      document.exitFullscreen();
    } else if (document.webkitExitFullscreen) {
      document.webkitExitFullscreen();
    }
  };

  console.log('[Pertin] Web Helper carregado!');
})();
