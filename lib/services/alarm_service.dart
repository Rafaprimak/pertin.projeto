import 'dart:typed_data';
import 'dart:ui' show Color;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

// Import condicional para web
import 'web_platform_service.dart' if (dart.library.io) 'web_platform_service_stub.dart';

class AlarmService {
  static final AlarmService instance = AlarmService._init();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isPlaying = false;
  Timer? _vibrationTimer;
  bool _isInitialized = false;

  AlarmService._init();

  Future<void> init() async {
    // Inicializar serviço web se estiver na web
    if (kIsWeb) {
      await WebPlatformService.instance.init();
      _isInitialized = true;
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (details) {},
      );
      _isInitialized = true;
    } catch (e) {
      debugPrint('Erro ao inicializar notificações: $e');
      _isInitialized = true; // Continua mesmo com erro
    }
  }

  Future<void> playAlarm() async {
    if (_isPlaying) return;
    _isPlaying = true;

    if (kIsWeb) {
      // Usar Web Audio API para melhor compatibilidade (funciona offline)
      try {
        WebPlatformService.instance.playAlarmSound();
        WebPlatformService.instance.vibrate([500, 200, 500, 200, 500, 200, 500]);
        await WebPlatformService.instance.showNotification(
          '🚌 VOCÊ CHEGOU!',
          'Toque para abrir o app e desligar o alarme',
          tag: 'pertin-alarm',
        );
      } catch (e) {
        debugPrint('Erro no alarme web: $e');
      }
      
      // Fallback: também tenta usar audioplayers com asset local
      try {
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        await _audioPlayer.play(
          AssetSource('sounds/alarm.ogg'),
          volume: 1.0,
        );
      } catch (e) {
        debugPrint('Erro no audioplayers: $e');
      }
      return;
    }

    // Código para mobile (Android/iOS) - usa asset local (funciona offline)
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(
        AssetSource('sounds/alarm.ogg'),
        volume: 1.0,
      );
    } catch (e) {
      // Se falhar, ignora (vibração ainda funcionará)
      debugPrint('Erro ao tocar alarme: $e');
    }

    // Vibrar continuamente
    _startContinuousVibration();

    // Mostrar notificação
    await _showNotification();
  }

  void _startContinuousVibration() async {
    // Vibração não é suportada na web
    if (kIsWeb) return;
    
    try {
      // Vibration só funciona em mobile
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
        if (!_isPlaying) {
          timer.cancel();
        }
      });
    } catch (e) {
      debugPrint('Erro na vibração: $e');
    }
  }

  Future<void> stopAlarm() async {
    _isPlaying = false;
    _vibrationTimer?.cancel();
    await _audioPlayer.stop();
    
    if (kIsWeb) {
      WebPlatformService.instance.stopAlarmSound();
      WebPlatformService.instance.stopVibration();
      return;
    }
    
    try {
      await _notifications.cancelAll();
    } catch (e) {
      debugPrint('Erro ao cancelar alarme: $e');
    }
  }

  Future<void> _showNotification() async {
    // Notificações não são suportadas na web (já tratado acima)
    if (kIsWeb) return;
    
    try {
      // Configuração Android com máxima prioridade para acordar o dispositivo
      final androidDetails = AndroidNotificationDetails(
        'pertin_alarm',
        'Alarme de Destino',
        channelDescription: 'Notificação quando você chega ao destino',
        importance: Importance.max,
        priority: Priority.high,
        // IMPORTANTE: fullScreenIntent abre o app sobre a tela de bloqueio
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        // Categoria de alarme para maior prioridade
        category: AndroidNotificationCategory.alarm,
        // Visibilidade pública para aparecer na tela de bloqueio
        visibility: NotificationVisibility.public,
        // Configurações de som e vibração
        playSound: false, // Som é tocado pelo AudioPlayer
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500, 200, 500]),
        // LED e outras configurações
        enableLights: true,
        ledColor: const Color(0xFF87CEEB), // Baby blue
        ledOnMs: 500,
        ledOffMs: 500,
        // Ticker para aparecer na barra de status
        ticker: 'Você chegou ao destino!',
      );

      // Configuração iOS para acordar o dispositivo
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        id: 1,
        title: '🚌 Você chegou!',
        body: 'Toque para desligar o alarme',
        notificationDetails: details,
      );
    } catch (e) {
      debugPrint('Erro ao mostrar notificação: $e');
    }
  }

  bool get isPlaying => _isPlaying;

  void dispose() {
    _vibrationTimer?.cancel();
    _audioPlayer.dispose();
  }
}
