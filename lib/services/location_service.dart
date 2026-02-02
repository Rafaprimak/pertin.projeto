import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

// Cidades brasileiras populares para busca offline/fallback
const List<Map<String, dynamic>> _brazilianCities = [
  {'name': 'São Paulo, SP, Brasil', 'lat': -23.5505, 'lng': -46.6333},
  {'name': 'Rio de Janeiro, RJ, Brasil', 'lat': -22.9068, 'lng': -43.1729},
  {'name': 'Curitiba, PR, Brasil', 'lat': -25.4284, 'lng': -49.2733},
  {'name': 'Belo Horizonte, MG, Brasil', 'lat': -19.9167, 'lng': -43.9345},
  {'name': 'Porto Alegre, RS, Brasil', 'lat': -30.0346, 'lng': -51.2177},
  {'name': 'Salvador, BA, Brasil', 'lat': -12.9714, 'lng': -38.5014},
  {'name': 'Brasília, DF, Brasil', 'lat': -15.7942, 'lng': -47.8822},
  {'name': 'Fortaleza, CE, Brasil', 'lat': -3.7172, 'lng': -38.5433},
  {'name': 'Recife, PE, Brasil', 'lat': -8.0476, 'lng': -34.8770},
  {'name': 'Manaus, AM, Brasil', 'lat': -3.1190, 'lng': -60.0217},
  {'name': 'Toledo, PR, Brasil', 'lat': -24.7135, 'lng': -53.7430},
  {'name': 'Cascavel, PR, Brasil', 'lat': -24.9578, 'lng': -53.4595},
  {'name': 'Londrina, PR, Brasil', 'lat': -23.3045, 'lng': -51.1696},
  {'name': 'Maringá, PR, Brasil', 'lat': -23.4205, 'lng': -51.9333},
  {'name': 'Foz do Iguaçu, PR, Brasil', 'lat': -25.5163, 'lng': -54.5854},
  {'name': 'Florianópolis, SC, Brasil', 'lat': -27.5954, 'lng': -48.5480},
  {'name': 'Joinville, SC, Brasil', 'lat': -26.3045, 'lng': -48.8487},
  {'name': 'Blumenau, SC, Brasil', 'lat': -26.9194, 'lng': -49.0661},
  {'name': 'Campinas, SP, Brasil', 'lat': -22.9099, 'lng': -47.0626},
  {'name': 'Santos, SP, Brasil', 'lat': -23.9608, 'lng': -46.3336},
  {'name': 'Goiânia, GO, Brasil', 'lat': -16.6869, 'lng': -49.2648},
  {'name': 'Belém, PA, Brasil', 'lat': -1.4558, 'lng': -48.4902},
  {'name': 'Guarulhos, SP, Brasil', 'lat': -23.4543, 'lng': -46.5337},
  {'name': 'Campina Grande, PB, Brasil', 'lat': -7.2306, 'lng': -35.8811},
  {'name': 'São Luís, MA, Brasil', 'lat': -2.5307, 'lng': -44.3068},
  {'name': 'Maceió, AL, Brasil', 'lat': -9.6658, 'lng': -35.7353},
  {'name': 'Natal, RN, Brasil', 'lat': -5.7945, 'lng': -35.2110},
  {'name': 'Teresina, PI, Brasil', 'lat': -5.0920, 'lng': -42.8038},
  {'name': 'João Pessoa, PB, Brasil', 'lat': -7.1195, 'lng': -34.8450},
  {'name': 'Aracaju, SE, Brasil', 'lat': -10.9472, 'lng': -37.0731},
  {'name': 'Cuiabá, MT, Brasil', 'lat': -15.6014, 'lng': -56.0979},
  {'name': 'Campo Grande, MS, Brasil', 'lat': -20.4697, 'lng': -54.6201},
  {'name': 'Vitória, ES, Brasil', 'lat': -20.3155, 'lng': -40.3128},
  {'name': 'Ribeirão Preto, SP, Brasil', 'lat': -21.1775, 'lng': -47.8103},
  {'name': 'Uberlândia, MG, Brasil', 'lat': -18.9186, 'lng': -48.2772},
  {'name': 'Sorocaba, SP, Brasil', 'lat': -23.5015, 'lng': -47.4526},
  {'name': 'Contagem, MG, Brasil', 'lat': -19.9318, 'lng': -44.0539},
  {'name': 'Feira de Santana, BA, Brasil', 'lat': -12.2669, 'lng': -38.9666},
];

class LocationService {
  static final LocationService instance = LocationService._init();
  StreamSubscription<Position>? _positionSubscription;
  
  LocationService._init();

  Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await checkPermission();
    if (!hasPermission) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      if (kIsWeb) {
        // Na web, tenta usar Nominatim API mas com fallback para coordenadas
        try {
          final response = await http.get(
            Uri.parse(
              'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
            ),
            headers: {'User-Agent': 'Pertin App'},
          ).timeout(const Duration(seconds: 5));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            return data['display_name'] ?? 'Localização atual';
          }
        } catch (e) {
          debugPrint('Nominatim falhou, usando fallback: $e');
        }
        // Fallback: encontra cidade mais próxima da lista
        return _findNearestCity(lat, lng);
      } else {
        List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          return '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}'
              .replaceAll(', ,', ',')
              .replaceAll(RegExp(r'^, |, $'), '');
        }
      }
    } catch (e) {
      debugPrint('Erro ao obter endereço: $e');
    }
    return 'Localização atual';
  }

  String _findNearestCity(double lat, double lng) {
    double minDistance = double.infinity;
    String nearestCity = 'Localização atual';
    
    for (final city in _brazilianCities) {
      final distance = Geolocator.distanceBetween(
        lat, lng, city['lat'], city['lng']
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearestCity = 'Próximo a ${city['name']}';
      }
    }
    
    return nearestCity;
  }

  Future<List<Location>> getCoordinatesFromAddress(String address) async {
    final query = address.toLowerCase().trim();
    if (query.length < 2) return [];
    
    // Primeiro tenta busca local (sempre funciona)
    final localResults = _searchLocalCities(query);
    
    if (!kIsWeb) {
      // No mobile, tenta geocoding nativo
      try {
        final results = await locationFromAddress(address);
        if (results.isNotEmpty) return results;
      } catch (e) {
        debugPrint('Geocoding nativo falhou: $e');
      }
    }
    
    // Retorna resultados locais
    return localResults;
  }
  
  List<Location> _searchLocalCities(String query) {
    final results = <Location>[];
    
    for (final city in _brazilianCities) {
      final cityName = (city['name'] as String).toLowerCase();
      if (cityName.contains(query)) {
        results.add(Location(
          latitude: city['lat'],
          longitude: city['lng'],
          timestamp: DateTime.now(),
        ));
      }
    }
    
    return results.take(5).toList();
  }
  
  // Retorna o nome da cidade a partir das coordenadas (para resultados locais)
  String? getCityNameFromCoordinates(double lat, double lng) {
    for (final city in _brazilianCities) {
      final cityLat = city['lat'] as double;
      final cityLng = city['lng'] as double;
      if ((cityLat - lat).abs() < 0.01 && (cityLng - lng).abs() < 0.01) {
        return city['name'] as String;
      }
    }
    return null;
  }

  void startLocationTracking({
    required Function(Position) onPositionUpdate,
    int distanceFilter = 10,
  }) {
    _positionSubscription?.cancel();
    
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).listen(onPositionUpdate);
  }

  void stopLocationTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  bool isNearDestination(
    Position currentPosition,
    double destinationLat,
    double destinationLng, {
    double radiusInMeters = 200,
  }) {
    final distance = calculateDistance(
      currentPosition.latitude,
      currentPosition.longitude,
      destinationLat,
      destinationLng,
    );
    return distance <= radiusInMeters;
  }
}
