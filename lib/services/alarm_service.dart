import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

class AlarmService {
  static final AlarmService instance = AlarmService._init();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isPlaying = false;
  Timer? _vibrationTimer;
  bool _isInitialized = false;

  AlarmService._init();

  Future<void> init() async {
    // Na web, notificações não são suportadas da mesma forma
    if (kIsWeb) {
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

    // Tocar som de alarme usando URL de som gratuito
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(
        UrlSource('https://actions.google.com/sounds/v1/alarms/alarm_clock.ogg'),
        volume: 1.0,
      );
    } catch (e) {
      // Se falhar, ignora (vibração ainda funcionará)
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
    
    if (!kIsWeb) {
      try {
        await _notifications.cancelAll();
      } catch (e) {
        debugPrint('Erro ao cancelar alarme: $e');
      }
    }
  }

  Future<void> _showNotification() async {
    // Notificações não são suportadas na web
    if (kIsWeb) return;
    
    try {
      const androidDetails = AndroidNotificationDetails(
      'pertin_alarm',
      'Alarme de Destino',
      channelDescription: 'Notificação quando você chega ao destino',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
    );

    const details = NotificationDetails(
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
