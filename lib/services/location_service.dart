import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

// Cache de cidades do IBGE para busca rápida
List<Map<String, dynamic>>? _ibgeCitiesCache;
DateTime? _ibgeCacheTime;

// Estados brasileiros com siglas
const Map<String, String> _estadosBrasil = {
  'Acre': 'AC', 'Alagoas': 'AL', 'Amapá': 'AP', 'Amazonas': 'AM',
  'Bahia': 'BA', 'Ceará': 'CE', 'Distrito Federal': 'DF', 'Espírito Santo': 'ES',
  'Goiás': 'GO', 'Maranhão': 'MA', 'Mato Grosso': 'MT', 'Mato Grosso do Sul': 'MS',
  'Minas Gerais': 'MG', 'Pará': 'PA', 'Paraíba': 'PB', 'Paraná': 'PR',
  'Pernambuco': 'PE', 'Piauí': 'PI', 'Rio de Janeiro': 'RJ', 'Rio Grande do Norte': 'RN',
  'Rio Grande do Sul': 'RS', 'Rondônia': 'RO', 'Roraima': 'RR', 'Santa Catarina': 'SC',
  'São Paulo': 'SP', 'Sergipe': 'SE', 'Tocantins': 'TO',
};

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
        // Na web, tenta usar Photon API (mais rápido que Nominatim)
        try {
          final response = await http.get(
            Uri.parse(
              'https://photon.komoot.io/reverse?lat=$lat&lon=$lng&lang=pt',
            ),
          ).timeout(const Duration(seconds: 4));
          
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['features'] != null && (data['features'] as List).isNotEmpty) {
              final props = data['features'][0]['properties'];
              final parts = <String>[];
              if (props['street'] != null) parts.add(props['street']);
              if (props['district'] != null) parts.add(props['district']);
              if (props['city'] != null) parts.add(props['city']);
              if (props['state'] != null) {
                final sigla = _estadosBrasil[props['state']] ?? props['state'];
                parts.add(sigla);
              }
              if (parts.isNotEmpty) return parts.join(', ');
            }
          }
        } catch (e) {
          debugPrint('Photon reverse falhou: $e');
        }
        return 'Localização atual';
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

  Future<List<Location>> getCoordinatesFromAddress(String address) async {
    final query = address.trim();
    if (query.length < 2) return [];
    
    // Tenta múltiplas APIs em sequência para maior robustez
    try {
      // 1. Photon API (Komoot) - muito rápido e bom para Brasil
      final photonResults = await _searchPhoton(query);
      if (photonResults.isNotEmpty) return photonResults;
    } catch (e) {
      debugPrint('Photon search falhou: $e');
    }
    
    try {
      // 2. Nominatim como fallback
      final results = await _searchNominatim(query);
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('Nominatim search falhou: $e');
    }
    
    if (!kIsWeb) {
      // No mobile, tenta geocoding nativo como fallback
      try {
        final results = await locationFromAddress(address);
        if (results.isNotEmpty) return results;
      } catch (e) {
        debugPrint('Geocoding nativo falhou: $e');
      }
    }
    
    // Fallback: busca local via cache de cidades
    return await _searchIBGECitiesAsLocations(query.toLowerCase());
  }
  
  // Busca IBGE retornando List<Location>
  Future<List<Location>> _searchIBGECitiesAsLocations(String query) async {
    final results = await _searchIBGECities(query);
    return results.map((city) => Location(
      latitude: city['lat'] as double,
      longitude: city['lng'] as double,
      timestamp: DateTime.now(),
    )).toList();
  }
  
  // Busca via Photon API (Komoot) - muito mais rápido que Nominatim
  Future<List<Location>> _searchPhoton(String query) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://photon.komoot.io/api/'
          '?q=${Uri.encodeComponent(query)}'
          '&lang=pt'
          '&limit=15'
          '&lat=-15.77' // Centro do Brasil para priorizar resultados brasileiros
          '&lon=-47.92'
          '&location_bias_scale=0.2',
        ),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        
        // Filtra apenas resultados do Brasil
        return features
            .where((f) => f['properties']?['country'] == 'Brazil' || 
                         f['properties']?['country'] == 'Brasil')
            .map((f) {
              final coords = f['geometry']?['coordinates'] as List<dynamic>?;
              if (coords != null && coords.length >= 2) {
                return Location(
                  latitude: (coords[1] as num).toDouble(),
                  longitude: (coords[0] as num).toDouble(),
                  timestamp: DateTime.now(),
                );
              }
              return null;
            })
            .whereType<Location>()
            .toList();
      }
    } catch (e) {
      debugPrint('Erro na busca Photon: $e');
    }
    return [];
  }
  
  // Busca via Nominatim API (OpenStreetMap) - retorna ruas, bairros, cidades
  Future<List<Location>> _searchNominatim(String query) async {
    try {
      // Adiciona Brasil à busca para resultados mais relevantes
      final searchQuery = query.contains('brasil') || query.contains('Brazil') 
          ? query 
          : '$query, Brasil';
      
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(searchQuery)}'
          '&format=json'
          '&addressdetails=1'
          '&limit=10'
          '&countrycodes=br', // Foca no Brasil
        ),
        headers: {
          'User-Agent': 'Pertin App/1.0',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => Location(
          latitude: double.parse(item['lat']),
          longitude: double.parse(item['lon']),
          timestamp: DateTime.now(),
        )).toList();
      }
    } catch (e) {
      debugPrint('Erro na busca Nominatim: $e');
    }
    
    return [];
  }
  
  // Retorna nomes formatados dos resultados de busca - VERSÃO ROBUSTA
  // Usa múltiplas APIs em paralelo para maior velocidade e cobertura
  Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    if (query.trim().length < 2) return [];
    
    final results = <Map<String, dynamic>>[];
    final seenLocations = <String>{}; // Evita duplicatas
    
    // Executa buscas em paralelo para maior velocidade
    final futures = await Future.wait([
      _searchPhotonAddresses(query).catchError((_) => <Map<String, dynamic>>[]),
      _searchNominatimAddresses(query).catchError((_) => <Map<String, dynamic>>[]),
      _searchIBGECities(query).catchError((_) => <Map<String, dynamic>>[]),
    ]);
    
    // Combina resultados de todas as fontes
    for (final sourceResults in futures) {
      for (final result in sourceResults) {
        final key = '${(result['lat'] as double).toStringAsFixed(3)},${(result['lng'] as double).toStringAsFixed(3)}';
        if (!seenLocations.contains(key)) {
          seenLocations.add(key);
          results.add(result);
        }
      }
    }
    
    // Ordena por relevância (cidades primeiro, depois outros)
    results.sort((a, b) {
      final aType = a['type'] as String? ?? '';
      final bType = b['type'] as String? ?? '';
      if (aType == 'city' && bType != 'city') return -1;
      if (bType == 'city' && aType != 'city') return 1;
      return 0;
    });
    
    return results.take(12).toList();
  }
  
  // Busca via Photon API (Komoot) - muito mais rápido que Nominatim
  Future<List<Map<String, dynamic>>> _searchPhotonAddresses(String query) async {
    final results = <Map<String, dynamic>>[];
    
    try {
      final response = await http.get(
        Uri.parse(
          'https://photon.komoot.io/api/'
          '?q=${Uri.encodeComponent(query)}'
          '&lang=pt'
          '&limit=15'
          '&lat=-15.77' // Centro do Brasil
          '&lon=-47.92'
          '&location_bias_scale=0.2',
        ),
      ).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>? ?? [];
        
        for (final f in features) {
          final props = f['properties'] ?? {};
          final country = props['country'] as String? ?? '';
          
          // Filtra apenas Brasil
          if (country != 'Brazil' && country != 'Brasil') continue;
          
          final coords = f['geometry']?['coordinates'] as List<dynamic>?;
          if (coords == null || coords.length < 2) continue;
          
          // Monta nome formatado
          final parts = <String>[];
          if (props['name'] != null && props['name'] != props['city']) {
            parts.add(props['name']);
          }
          if (props['district'] != null) parts.add(props['district']);
          if (props['city'] != null) {
            parts.add(props['city']);
          } else if (props['county'] != null) {
            parts.add(props['county']);
          }
          if (props['state'] != null) {
            final sigla = _estadosBrasil[props['state']] ?? props['state'];
            parts.add(sigla);
          }
          
          if (parts.isEmpty) continue;
          
          results.add({
            'name': parts.join(', '),
            'lat': (coords[1] as num).toDouble(),
            'lng': (coords[0] as num).toDouble(),
            'type': props['type'] ?? 'place',
          });
        }
      }
    } catch (e) {
      debugPrint('Photon search error: $e');
    }
    
    return results;
  }
  
  // Busca via Nominatim (OpenStreetMap) - backup mais completo
  Future<List<Map<String, dynamic>>> _searchNominatimAddresses(String query) async {
    final results = <Map<String, dynamic>>[];
    
    try {
      final searchQuery = query.contains('brasil') || query.contains('Brazil') 
          ? query 
          : '$query, Brasil';
      
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(searchQuery)}'
          '&format=json'
          '&addressdetails=1'
          '&limit=10'
          '&countrycodes=br',
        ),
        headers: {
          'User-Agent': 'Pertin App/1.0',
          'Accept-Language': 'pt-BR,pt;q=0.9',
        },
      ).timeout(const Duration(seconds: 6));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        for (final item in data) {
          final address = item['address'] ?? {};
          
          // Formata o nome para ser mais legível
          final parts = <String>[];
          if (address['road'] != null) parts.add(address['road']);
          if (address['suburb'] != null) parts.add(address['suburb']);
          if (address['city'] != null) {
            parts.add(address['city']);
          } else if (address['town'] != null) {
            parts.add(address['town']);
          } else if (address['municipality'] != null) {
            parts.add(address['municipality']);
          }
          if (address['state'] != null) {
            final sigla = _estadosBrasil[address['state']] ?? address['state'];
            parts.add(sigla);
          }
          
          if (parts.isEmpty) {
            parts.add(item['display_name'] ?? 'Local');
          }
          
          results.add({
            'name': parts.join(', '),
            'lat': double.parse(item['lat']),
            'lng': double.parse(item['lon']),
            'type': item['type'] ?? 'place',
          });
        }
      }
    } catch (e) {
      debugPrint('Nominatim search error: $e');
    }
    
    return results;
  }
  
  // Busca TODAS as cidades do Brasil via API do IBGE (5570 cidades!)
  Future<List<Map<String, dynamic>>> _searchIBGECities(String query) async {
    final results = <Map<String, dynamic>>[];
    final queryLower = query.toLowerCase().trim();
    
    // Carrega cache do IBGE se necessário
    await _loadIBGECache();
    
    if (_ibgeCitiesCache == null) return results;
    
    // Busca nas cidades em cache
    for (final city in _ibgeCitiesCache!) {
      final nome = (city['nome'] as String).toLowerCase();
      final uf = (city['uf'] as String).toLowerCase();
      
      // Match flexível: nome contém query ou query contém nome
      if (nome.contains(queryLower) || queryLower.contains(nome)) {
        results.add({
          'name': '${city['nome']}, ${city['uf']}',
          'lat': city['lat'] as double,
          'lng': city['lng'] as double,
          'type': 'city',
        });
      } else if (uf == queryLower) {
        // Busca por UF
        results.add({
          'name': '${city['nome']}, ${city['uf']}',
          'lat': city['lat'] as double,
          'lng': city['lng'] as double,
          'type': 'city',
        });
      }
      
      if (results.length >= 20) break;
    }
    
    return results;
  }
  
  // Carrega e cacheia lista de cidades do IBGE com coordenadas
  Future<void> _loadIBGECache() async {
    // Verifica se cache ainda é válido (24 horas)
    if (_ibgeCitiesCache != null && _ibgeCacheTime != null) {
      if (DateTime.now().difference(_ibgeCacheTime!).inHours < 24) {
        return;
      }
    }
    
    try {
      // API do IBGE para listar todos os municípios com coordenadas
      final response = await http.get(
        Uri.parse('https://servicodados.ibge.gov.br/api/v1/localidades/municipios?view=nivelado'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        
        // Para cada cidade, precisamos das coordenadas
        // A API do IBGE não retorna lat/lng diretamente, então usamos aproximação
        // baseada na microrregião ou calculamos depois quando necessário
        _ibgeCitiesCache = [];
        
        for (final item in data) {
          // Obtém coordenadas aproximadas baseadas no código do município
          // Usamos uma API secundária ou cache local para isso
          _ibgeCitiesCache!.add({
            'id': item['municipio-id'],
            'nome': item['municipio-nome'] ?? item['nome'] ?? '',
            'uf': item['UF-sigla'] ?? item['microrregiao']?['mesorregiao']?['UF']?['sigla'] ?? '',
            // Coordenadas aproximadas do centro da UF (serão refinadas na seleção)
            'lat': _getApproxLatForUF(item['UF-sigla'] ?? ''),
            'lng': _getApproxLngForUF(item['UF-sigla'] ?? ''),
            'needsGeocode': true, // Marca que precisa geocodificar quando selecionado
          });
        }
        
        _ibgeCacheTime = DateTime.now();
        debugPrint('IBGE cache carregado: ${_ibgeCitiesCache!.length} cidades');
      }
    } catch (e) {
      debugPrint('Erro ao carregar cache IBGE: $e');
      // Fallback para lista local básica
      _ibgeCitiesCache = _getBasicCitiesFallback();
    }
  }
  
  // Coordenadas aproximadas do centro de cada estado
  double _getApproxLatForUF(String uf) {
    const coords = {
      'AC': -9.0, 'AL': -9.5, 'AP': 1.0, 'AM': -3.1, 'BA': -12.9, 'CE': -3.7,
      'DF': -15.8, 'ES': -20.3, 'GO': -16.7, 'MA': -2.5, 'MT': -12.6, 'MS': -20.4,
      'MG': -19.9, 'PA': -1.4, 'PB': -7.1, 'PR': -25.4, 'PE': -8.0, 'PI': -5.1,
      'RJ': -22.9, 'RN': -5.8, 'RS': -30.0, 'RO': -11.5, 'RR': 2.8, 'SC': -27.6,
      'SP': -23.5, 'SE': -10.9, 'TO': -10.2,
    };
    return coords[uf] ?? -15.8;
  }
  
  double _getApproxLngForUF(String uf) {
    const coords = {
      'AC': -70.0, 'AL': -35.7, 'AP': -51.0, 'AM': -60.0, 'BA': -38.5, 'CE': -38.5,
      'DF': -47.9, 'ES': -40.3, 'GO': -49.3, 'MA': -44.3, 'MT': -55.9, 'MS': -54.6,
      'MG': -43.9, 'PA': -48.5, 'PB': -34.8, 'PR': -49.3, 'PE': -35.0, 'PI': -42.8,
      'RJ': -43.2, 'RN': -35.2, 'RS': -51.2, 'RO': -63.9, 'RR': -60.7, 'SC': -48.5,
      'SP': -46.6, 'SE': -37.1, 'TO': -48.3,
    };
    return coords[uf] ?? -47.9;
  }
  
  // Lista básica de cidades como fallback
  List<Map<String, dynamic>> _getBasicCitiesFallback() {
    return [
      {'nome': 'São Paulo', 'uf': 'SP', 'lat': -23.5505, 'lng': -46.6333},
      {'nome': 'Rio de Janeiro', 'uf': 'RJ', 'lat': -22.9068, 'lng': -43.1729},
      {'nome': 'Curitiba', 'uf': 'PR', 'lat': -25.4284, 'lng': -49.2733},
      {'nome': 'Belo Horizonte', 'uf': 'MG', 'lat': -19.9167, 'lng': -43.9345},
      {'nome': 'Porto Alegre', 'uf': 'RS', 'lat': -30.0346, 'lng': -51.2177},
      {'nome': 'Salvador', 'uf': 'BA', 'lat': -12.9714, 'lng': -38.5014},
      {'nome': 'Brasília', 'uf': 'DF', 'lat': -15.7942, 'lng': -47.8822},
      {'nome': 'Fortaleza', 'uf': 'CE', 'lat': -3.7172, 'lng': -38.5433},
      {'nome': 'Recife', 'uf': 'PE', 'lat': -8.0476, 'lng': -34.8770},
      {'nome': 'Manaus', 'uf': 'AM', 'lat': -3.1190, 'lng': -60.0217},
      {'nome': 'Toledo', 'uf': 'PR', 'lat': -24.7135, 'lng': -53.7430},
      {'nome': 'Cascavel', 'uf': 'PR', 'lat': -24.9578, 'lng': -53.4595},
      {'nome': 'Londrina', 'uf': 'PR', 'lat': -23.3045, 'lng': -51.1696},
      {'nome': 'Maringá', 'uf': 'PR', 'lat': -23.4205, 'lng': -51.9333},
      {'nome': 'Foz do Iguaçu', 'uf': 'PR', 'lat': -25.5163, 'lng': -54.5854},
      {'nome': 'Florianópolis', 'uf': 'SC', 'lat': -27.5954, 'lng': -48.5480},
      {'nome': 'Joinville', 'uf': 'SC', 'lat': -26.3045, 'lng': -48.8487},
      {'nome': 'Blumenau', 'uf': 'SC', 'lat': -26.9194, 'lng': -49.0661},
      {'nome': 'Campinas', 'uf': 'SP', 'lat': -22.9099, 'lng': -47.0626},
      {'nome': 'Santos', 'uf': 'SP', 'lat': -23.9608, 'lng': -46.3336},
      {'nome': 'Goiânia', 'uf': 'GO', 'lat': -16.6869, 'lng': -49.2648},
      {'nome': 'Belém', 'uf': 'PA', 'lat': -1.4558, 'lng': -48.4902},
      {'nome': 'Guarulhos', 'uf': 'SP', 'lat': -23.4543, 'lng': -46.5337},
      {'nome': 'Campina Grande', 'uf': 'PB', 'lat': -7.2306, 'lng': -35.8811},
      {'nome': 'São Luís', 'uf': 'MA', 'lat': -2.5307, 'lng': -44.3068},
      {'nome': 'Maceió', 'uf': 'AL', 'lat': -9.6658, 'lng': -35.7353},
      {'nome': 'Natal', 'uf': 'RN', 'lat': -5.7945, 'lng': -35.2110},
      {'nome': 'Teresina', 'uf': 'PI', 'lat': -5.0920, 'lng': -42.8038},
      {'nome': 'João Pessoa', 'uf': 'PB', 'lat': -7.1195, 'lng': -34.8450},
      {'nome': 'Aracaju', 'uf': 'SE', 'lat': -10.9472, 'lng': -37.0731},
      {'nome': 'Cuiabá', 'uf': 'MT', 'lat': -15.6014, 'lng': -56.0979},
      {'nome': 'Campo Grande', 'uf': 'MS', 'lat': -20.4697, 'lng': -54.6201},
      {'nome': 'Vitória', 'uf': 'ES', 'lat': -20.3155, 'lng': -40.3128},
      {'nome': 'Ribeirão Preto', 'uf': 'SP', 'lat': -21.1775, 'lng': -47.8103},
      {'nome': 'Uberlândia', 'uf': 'MG', 'lat': -18.9186, 'lng': -48.2772},
      {'nome': 'Sorocaba', 'uf': 'SP', 'lat': -23.5015, 'lng': -47.4526},
      {'nome': 'Contagem', 'uf': 'MG', 'lat': -19.9318, 'lng': -44.0539},
      {'nome': 'Feira de Santana', 'uf': 'BA', 'lat': -12.2669, 'lng': -38.9666},
      {'nome': 'Juiz de Fora', 'uf': 'MG', 'lat': -21.7642, 'lng': -43.3503},
      {'nome': 'Aparecida de Goiânia', 'uf': 'GO', 'lat': -16.8231, 'lng': -49.2464},
      {'nome': 'Ponta Grossa', 'uf': 'PR', 'lat': -25.0916, 'lng': -50.1668},
      {'nome': 'Pelotas', 'uf': 'RS', 'lat': -31.7649, 'lng': -52.3371},
      {'nome': 'Caxias do Sul', 'uf': 'RS', 'lat': -29.1678, 'lng': -51.1794},
      {'nome': 'Canoas', 'uf': 'RS', 'lat': -29.9178, 'lng': -51.1836},
      {'nome': 'Chapecó', 'uf': 'SC', 'lat': -27.1006, 'lng': -52.6152},
      {'nome': 'Criciúma', 'uf': 'SC', 'lat': -28.6775, 'lng': -49.3697},
      {'nome': 'Itajaí', 'uf': 'SC', 'lat': -26.9078, 'lng': -48.6619},
      {'nome': 'Balneário Camboriú', 'uf': 'SC', 'lat': -26.9909, 'lng': -48.6352},
      {'nome': 'São José', 'uf': 'SC', 'lat': -27.6136, 'lng': -48.6366},
      {'nome': 'Palhoça', 'uf': 'SC', 'lat': -27.6453, 'lng': -48.6679},
    ];
  }

  void startLocationTracking({
    required Function(Position) onPositionUpdate,
    int distanceFilter = 10,
  }) {
    _positionSubscription?.cancel();
    
    // Configurações específicas para Android com foreground service
    // Isso permite que o GPS continue funcionando com a tela bloqueada
    late LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 5),
        // IMPORTANTE: Foreground notification para manter o serviço ativo
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: 'Pertin está monitorando sua localização',
          notificationTitle: 'Viagem em andamento',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || 
               defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
        activityType: ActivityType.otherNavigation,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      );
    }
    
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
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
