import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/providers/alarm_provider.dart';
import 'package:pertin/services/location_service.dart';
import 'package:pertin/screens/tracking_screen.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/common_widgets.dart';
import 'package:pertin/theme/app_colors.dart';

class NewTripScreen extends StatefulWidget {
  const NewTripScreen({super.key});

  @override
  State<NewTripScreen> createState() => _NewTripScreenState();
}

class _NewTripScreenState extends State<NewTripScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _destinationController = TextEditingController();
  final _ticketPriceController = TextEditingController();
  
  Position? _currentPosition;
  String _currentAddress = 'Obtendo localização...';
  double? _destinationLat;
  double? _destinationLng;
  String _destinationAddress = '';
  double _alertRadius = 200;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _addTicketPrice = false;
  bool _scheduleTrip = false;
  DateTime? _scheduledDateTime;
  List<SearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    _ticketPriceController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final position = await LocationService.instance.getCurrentPosition();
    if (position != null && mounted) {
      final address = await LocationService.instance.getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _currentPosition = position;
        _currentAddress = address;
      });
    } else if (mounted) {
      setState(() {
        _currentAddress = 'Não foi possível obter a localização';
      });
    }
  }

  Future<void> _searchDestination(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final locations = await LocationService.instance.getCoordinatesFromAddress(query);
      
      List<SearchResult> results = [];
      for (var location in locations.take(5)) {
        // Primeiro tenta pegar o nome da cidade local
        String? cityName = LocationService.instance.getCityNameFromCoordinates(
          location.latitude,
          location.longitude,
        );
        
        // Se não encontrar, busca o endereço
        final address = cityName ?? await LocationService.instance.getAddressFromCoordinates(
          location.latitude,
          location.longitude,
        );
        
        results.add(SearchResult(
          address: address,
          lat: location.latitude,
          lng: location.longitude,
        ));
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _selectDestination(SearchResult result) {
    setState(() {
      _destinationController.text = result.address;
      _destinationAddress = result.address;
      _destinationLat = result.lat;
      _destinationLng = result.lng;
      _searchResults = [];
    });
  }

  Future<void> _startTrip() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aguarde a localização atual ser obtida'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    if (_destinationLat == null || _destinationLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione um destino válido'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Parse do valor da passagem
    double? ticketPrice;
    if (_addTicketPrice && _ticketPriceController.text.isNotEmpty) {
      final priceText = _ticketPriceController.text
          .replaceAll('R\$', '')
          .replaceAll('.', '')
          .replaceAll(',', '.')
          .trim();
      ticketPrice = double.tryParse(priceText);
    }

    final trip = await context.read<TripProvider>().createTrip(
      name: _nameController.text.trim(),
      originName: _currentAddress,
      originLat: _currentPosition!.latitude,
      originLng: _currentPosition!.longitude,
      destinationName: _destinationAddress,
      destinationLat: _destinationLat!,
      destinationLng: _destinationLng!,
      ticketPrice: ticketPrice,
      scheduledStartTime: _scheduleTrip ? _scheduledDateTime : null,
    );

    if (trip != null && mounted) {
      // Se for viagem agendada, apenas salva e volta
      if (_scheduleTrip && _scheduledDateTime != null && _scheduledDateTime!.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Viagem agendada para ${_formatDateTime(_scheduledDateTime!)}'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop();
      } else {
        // Se for viagem imediata, inicia tracking
        context.read<AlarmProvider>().setAlertRadius(_alertRadius);
        await context.read<AlarmProvider>().startTracking(trip);

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const TrackingScreen()),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarrySkyBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTripNameField(),
                        const SizedBox(height: 20),
                        _buildOriginCard(),
                        const SizedBox(height: 20),
                        _buildDestinationCard(),
                        if (_searchResults.isNotEmpty) _buildSearchResults(),
                        const SizedBox(height: 20),
                        _buildTicketPriceCard(),
                        const SizedBox(height: 20),
                        _buildScheduleTripCard(),
                        const SizedBox(height: 20),
                        _buildAlertRadiusCard(),
                        const SizedBox(height: 32),
                        GradientButton(
                          text: _scheduleTrip ? 'Agendar Viagem' : 'Iniciar Viagem',
                          icon: _scheduleTrip ? Icons.event : Icons.play_arrow,
                          isLoading: _isLoading,
                          onPressed: _startTrip,
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
          ),
          const Expanded(
            child: Text(
              'Nova Viagem',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildTripNameField() {
    return GlassCard(
      child: StyledTextField(
        controller: _nameController,
        labelText: 'Nome da Viagem',
        hintText: 'Ex: Viagem para casa',
        prefixIcon: Icons.edit,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Digite um nome para a viagem';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildOriginCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.my_location,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Origem',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentAddress,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                if (_currentPosition == null)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.babyBlue,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.flag,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Destino',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StyledTextField(
            controller: _destinationController,
            labelText: 'Buscar destino',
            hintText: 'Digite o endereço ou local',
            prefixIcon: Icons.search,
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.babyBlue,
                      ),
                    ),
                  )
                : null,
            onChanged: _searchDestination,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Digite um destino';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return GlassCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: AppColors.navyBlue.withOpacity(0.3),
        ),
        itemBuilder: (context, index) {
          final result = _searchResults[index];
          return ListTile(
            leading: const Icon(
              Icons.location_on_outlined,
              color: AppColors.babyBlue,
            ),
            title: Text(
              result.address,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
            onTap: () => _selectDestination(result),
          );
        },
      ),
    );
  }

  Widget _buildTicketPriceCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.confirmation_number,
                  color: AppColors.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Valor da Passagem',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _addTicketPrice,
                onChanged: (value) {
                  setState(() {
                    _addTicketPrice = value;
                    if (!value) {
                      _ticketPriceController.clear();
                    }
                  });
                },
                activeColor: AppColors.success,
              ),
            ],
          ),
          if (_addTicketPrice) ...[
            const SizedBox(height: 8),
            const Text(
              'Registre o valor da passagem como despesa inicial (opcional)',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            StyledTextField(
              controller: _ticketPriceController,
              labelText: 'Valor (R\$)',
              hintText: 'Ex: 45,00',
              prefixIcon: Icons.attach_money,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (_addTicketPrice && (value == null || value.isEmpty)) {
                  return 'Digite o valor da passagem';
                }
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day/$month/$year às $hour:$minute';
  }

  Future<void> _selectScheduleDateTime() async {
    final now = DateTime.now();
    
    // Seleciona a data
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.babyBlue,
              onPrimary: AppColors.midnightBlue,
              surface: AppColors.cardDark,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date == null || !mounted) return;

    // Seleciona a hora
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime ?? now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.babyBlue,
              onPrimary: AppColors.midnightBlue,
              surface: AppColors.cardDark,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (time == null || !mounted) return;

    setState(() {
      _scheduledDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Widget _buildScheduleTripCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.event,
                  color: AppColors.info,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Agendar Viagem',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _scheduleTrip,
                onChanged: (value) {
                  setState(() {
                    _scheduleTrip = value;
                    if (!value) {
                      _scheduledDateTime = null;
                    }
                  });
                },
                activeColor: AppColors.info,
              ),
            ],
          ),
          if (_scheduleTrip) ...[
            const SizedBox(height: 8),
            const Text(
              'Planeje sua viagem para uma data e hora futura',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectScheduleDateTime,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _scheduledDateTime != null
                        ? AppColors.info.withValues(alpha: 0.5)
                        : AppColors.navyBlue,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: _scheduledDateTime != null
                          ? AppColors.info
                          : AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scheduledDateTime != null
                            ? _formatDateTime(_scheduledDateTime!)
                            : 'Selecionar data e hora',
                        style: TextStyle(
                          fontSize: 14,
                          color: _scheduledDateTime != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertRadiusCard() {
    // Opções de distância organizadas
    final List<double> distanceOptions = [
      100, 200, 500, 1000, 2000, 5000, 10000, 15000
    ];

    String formatDistance(double meters) {
      if (meters >= 1000) {
        return '${(meters / 1000).toStringAsFixed(0)} km';
      }
      return '${meters.toInt()} m';
    }

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.starYellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.notifications_active,
                  color: AppColors.starYellow,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Raio do Alarme',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'O alarme tocará quando você estiver a ${formatDistance(_alertRadius)} do destino',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          // Seção: Pequenas Distâncias
          const Text(
            'Pequenas distâncias',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: distanceOptions
                .where((d) => d <= 2000)
                .map((distance) => _buildDistanceChip(distance, formatDistance))
                .toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Seção: Grandes Distâncias
          const Text(
            'Grandes distâncias',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: distanceOptions
                .where((d) => d > 2000)
                .map((distance) => _buildDistanceChip(distance, formatDistance))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceChip(double distance, String Function(double) formatDistance) {
    final isSelected = _alertRadius == distance;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _alertRadius = distance);
        },
        borderRadius: BorderRadius.circular(25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [AppColors.babyBlue, AppColors.lightBlue],
                  )
                : null,
            color: isSelected ? null : AppColors.cardDark,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isSelected ? AppColors.babyBlue : AppColors.navyBlue,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.babyBlue.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            formatDistance(distance),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isSelected ? AppColors.midnightBlue : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class SearchResult {
  final String address;
  final double lat;
  final double lng;

  SearchResult({
    required this.address,
    required this.lat,
    required this.lng,
  });
}
