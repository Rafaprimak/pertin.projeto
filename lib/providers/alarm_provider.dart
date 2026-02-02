import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, ChangeNotifier;
import 'package:geolocator/geolocator.dart';
import 'package:pertin/models/trip.dart';
import 'package:pertin/services/alarm_service.dart';
import 'package:pertin/services/location_service.dart';
import 'package:pertin/services/web_platform_service.dart' if (dart.library.io) 'package:pertin/services/web_platform_service_stub.dart';

class AlarmProvider extends ChangeNotifier {
  bool _isTracking = false;
  bool _isAlarmActive = false;
  Position? _currentPosition;
  Trip? _targetTrip;
  double _distanceToDestination = 0;
  double _alertRadius = 200; // metros

  bool get isTracking => _isTracking;
  bool get isAlarmActive => _isAlarmActive;
  Position? get currentPosition => _currentPosition;
  Trip? get targetTrip => _targetTrip;
  double get distanceToDestination => _distanceToDestination;
  double get alertRadius => _alertRadius;

  void setAlertRadius(double radius) {
    _alertRadius = radius;
    notifyListeners();
  }

  Future<void> startTracking(Trip trip) async {
    _targetTrip = trip;
    _isTracking = true;
    notifyListeners();

    // Na web, ativa o Wake Lock para manter a tela ligada
    if (kIsWeb) {
      await WebPlatformService.instance.requestWakeLock();
      WebPlatformService.instance.startKeepAlive();
    }

    LocationService.instance.startLocationTracking(
      onPositionUpdate: _onPositionUpdate,
      distanceFilter: 10,
    );
  }

  void _onPositionUpdate(Position position) {
    _currentPosition = position;

    if (_targetTrip != null) {
      _distanceToDestination = LocationService.instance.calculateDistance(
        position.latitude,
        position.longitude,
        _targetTrip!.destinationLat,
        _targetTrip!.destinationLng,
      );

      // Verifica se chegou ao destino
      if (_distanceToDestination <= _alertRadius && !_isAlarmActive) {
        _triggerAlarm();
      }
    }

    notifyListeners();
  }

  Future<void> _triggerAlarm() async {
    _isAlarmActive = true;
    await AlarmService.instance.playAlarm();
    notifyListeners();
  }

  Future<void> stopAlarm() async {
    _isAlarmActive = false;
    await AlarmService.instance.stopAlarm();
    notifyListeners();
  }

  void stopTracking() {
    _isTracking = false;
    _targetTrip = null;
    _distanceToDestination = 0;
    LocationService.instance.stopLocationTracking();
    
    // Na web, libera o Wake Lock
    if (kIsWeb) {
      WebPlatformService.instance.releaseWakeLock();
      WebPlatformService.instance.stopKeepAlive();
    }
    
    notifyListeners();
  }

  String get formattedDistance {
    if (_distanceToDestination >= 1000) {
      return '${(_distanceToDestination / 1000).toStringAsFixed(1)} km';
    }
    return '${_distanceToDestination.toStringAsFixed(0)} m';
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
