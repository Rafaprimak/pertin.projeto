import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

/// Serviço para funcionalidades específicas da Web/PWA
/// Integra com o pertin_web_helper.js
class WebPlatformService {
  static final WebPlatformService instance = WebPlatformService._init();
  
  bool _isWakeLockActive = false;
  bool _notificationsGranted = false;
  bool _isInitialized = false;
  
  WebPlatformService._init();

  /// Inicializa o serviço web
  Future<void> init() async {
    if (!kIsWeb || _isInitialized) return;
    
    try {
      // Pré-carregar som do alarme
      await _preloadAlarmSound();
      
      // Solicitar permissão de notificações
      await requestNotificationPermission();
      
      _isInitialized = true;
      debugPrint('[WebPlatformService] Inicializado com sucesso');
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao inicializar: $e');
    }
  }

  /// Solicita permissão para notificações
  Future<bool> requestNotificationPermission() async {
    if (!kIsWeb) return false;
    
    try {
      final result = _pertinRequestNotificationPermission();
      if (result == null) return false;
      final permission = (result as JSPromise).toDart;
      final permissionStr = await permission;
      _notificationsGranted = permissionStr.toString() == 'granted';
      return _notificationsGranted;
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao solicitar notificações: $e');
      return false;
    }
  }

  /// Ativa Wake Lock para manter a tela ligada
  Future<bool> requestWakeLock() async {
    if (!kIsWeb) return false;
    
    try {
      final result = _pertinRequestWakeLock();
      if (result == null) return false;
      final success = await (result as JSPromise).toDart;
      _isWakeLockActive = (success as JSBoolean?)?.toDart ?? false;
      return _isWakeLockActive;
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao ativar Wake Lock: $e');
      return false;
    }
  }

  /// Libera o Wake Lock
  void releaseWakeLock() {
    if (!kIsWeb) return;
    
    try {
      _pertinReleaseWakeLock();
      _isWakeLockActive = false;
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao liberar Wake Lock: $e');
    }
  }

  /// Mostra uma notificação do browser
  Future<bool> showNotification(String title, String body, {String? tag}) async {
    if (!kIsWeb) return false;
    
    try {
      final result = _pertinShowNotification(
        title.toJS, 
        body.toJS, 
        (tag ?? 'pertin').toJS
      );
      return (result as JSBoolean?)?.toDart ?? false;
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao mostrar notificação: $e');
      return false;
    }
  }

  /// Vibra o dispositivo (se suportado)
  void vibrate([List<int>? pattern]) {
    if (!kIsWeb) return;
    
    try {
      final jsPattern = (pattern ?? [500, 200, 500]).jsify();
      if (jsPattern != null) {
        _pertinVibrate(jsPattern);
      }
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao vibrar: $e');
    }
  }

  /// Para a vibração
  void stopVibration() {
    if (!kIsWeb) return;
    
    try {
      _pertinStopVibration();
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao parar vibração: $e');
    }
  }

  /// Pré-carrega o som do alarme
  Future<bool> _preloadAlarmSound() async {
    if (!kIsWeb) return false;
    
    try {
      final result = _pertinPreloadAlarmSound();
      if (result == null) return false;
      await (result as JSPromise).toDart;
      return true;
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao pré-carregar som: $e');
      return false;
    }
  }

  /// Toca o som de alarme usando Web Audio API
  bool playAlarmSound() {
    if (!kIsWeb) return false;
    
    try {
      final result = _pertinPlayAlarmSound();
      return (result as JSBoolean?)?.toDart ?? false;
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao tocar alarme: $e');
      return false;
    }
  }

  /// Para o som de alarme
  void stopAlarmSound() {
    if (!kIsWeb) return;
    
    try {
      _pertinStopAlarmSound();
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao parar alarme: $e');
    }
  }

  /// Obtém informações da plataforma
  Map<String, dynamic> getPlatformInfo() {
    if (!kIsWeb) {
      return {
        'isIOS': false,
        'isAndroid': false,
        'isMobile': false,
        'isStandalone': false,
        'isPWA': false,
      };
    }
    
    try {
      final result = _pertinGetPlatformInfo();
      if (result == null) return {};
      
      // Converte JSObject para Map usando dartify
      final dartResult = (result as JSObject).dartify();
      if (dartResult is Map) {
        return Map<String, dynamic>.from(dartResult);
      }
      return {};
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao obter info da plataforma: $e');
      return {};
    }
  }

  /// Verifica se a página está visível
  bool isPageVisible() {
    if (!kIsWeb) return true;
    
    try {
      final result = _pertinIsPageVisible();
      return (result as JSBoolean?)?.toDart ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Inicia o keep-alive para manter o app ativo
  void startKeepAlive() {
    if (!kIsWeb) return;
    
    try {
      _pertinStartKeepAlive();
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao iniciar keep-alive: $e');
    }
  }

  /// Para o keep-alive
  void stopKeepAlive() {
    if (!kIsWeb) return;
    
    try {
      _pertinStopKeepAlive();
    } catch (e) {
      debugPrint('[WebPlatformService] Erro ao parar keep-alive: $e');
    }
  }

  /// Verifica se está rodando como PWA instalada
  bool get isPWA {
    final info = getPlatformInfo();
    return info['isPWA'] == true;
  }

  /// Verifica se é iOS
  bool get isIOS {
    final info = getPlatformInfo();
    return info['isIOS'] == true;
  }

  /// Verifica se as notificações estão habilitadas
  bool get hasNotificationPermission => _notificationsGranted;

  /// Verifica se o Wake Lock está ativo
  bool get isWakeLockActive => _isWakeLockActive;
}

// ========================================
// Bindings JavaScript (dart:js_interop)
// ========================================

@JS('pertinRequestNotificationPermission')
external JSAny? _pertinRequestNotificationPermission();

@JS('pertinRequestWakeLock')
external JSAny? _pertinRequestWakeLock();

@JS('pertinReleaseWakeLock')
external void _pertinReleaseWakeLock();

@JS('pertinShowNotification')
external JSAny? _pertinShowNotification(JSString title, JSString body, JSString tag);

@JS('pertinVibrate')
external JSAny? _pertinVibrate(JSAny pattern);

@JS('pertinStopVibration')
external void _pertinStopVibration();

@JS('pertinPreloadAlarmSound')
external JSAny? _pertinPreloadAlarmSound();

@JS('pertinPlayAlarmSound')
external JSAny? _pertinPlayAlarmSound();

@JS('pertinStopAlarmSound')
external void _pertinStopAlarmSound();

@JS('pertinGetPlatformInfo')
external JSAny? _pertinGetPlatformInfo();

@JS('pertinIsPageVisible')
external JSAny? _pertinIsPageVisible();

@JS('pertinStartKeepAlive')
external void _pertinStartKeepAlive();

@JS('pertinStopKeepAlive')
external void _pertinStopKeepAlive();
