import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pertin/providers/alarm_provider.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/screens/alarm_screen.dart';
import 'package:pertin/screens/add_expense_screen.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/sleepy_bus_logo.dart';
import 'package:pertin/widgets/common_widgets.dart';
import 'package:pertin/widgets/web_platform_warning.dart';
import 'package:pertin/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Modo economia de bateria para iOS/Web (escurece a tela)
  bool _batterySaverMode = false;
  // Modo bolso - tela completamente preta, precisa segurar para sair
  bool _pocketMode = false;
  bool _holdingToExit = false;
  double _holdProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Check for alarm trigger
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAlarm();
      // Mostra tutorial do modo bolso na primeira vez (apenas para web/iOS)
      if (kIsWeb) {
        _showPocketModeTutorialIfNeeded();
      }
    });
  }

  Future<void> _showPocketModeTutorialIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('has_seen_pocket_mode_tutorial') ?? false;
    
    if (!hasSeenTutorial && mounted) {
      await _showPocketModeTutorial();
      await prefs.setBool('has_seen_pocket_mode_tutorial', true);
    }
  }

  Future<void> _showPocketModeTutorial() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Row(
          children: [
            Icon(Icons.tips_and_updates, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Dica Importante!',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para usar o app no iPhone sem gastar muita bateria e sem toques acidentais:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              
              // Modo Bolso
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.back_hand, color: Colors.deepPurple, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Modo Bolso',
                          style: TextStyle(
                            color: Colors.deepPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Tela 100% preta\n• Ignora toques acidentais\n• Segure 2 segundos para sair\n• O alarme toca normalmente!',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Acesso Guiado
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phonelink_lock, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Acesso Guiado (iOS)',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Para economia máxima de bateria:\n\n1. Ajustes → Acessibilidade → Acesso Guiado → Ativar\n2. Com o app aberto, clique 3x no botão lateral\n3. Toque em "Iniciar"\n\nIsso bloqueia todos os botões e desativa a tela!',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.battery_charging_full, color: Colors.amber, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dica: Conecte o carregador durante viagens longas!',
                        style: TextStyle(color: Colors.amber, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.babyBlue,
              foregroundColor: AppColors.midnightBlue,
            ),
            child: const Text('Entendi!'),
          ),
        ],
      ),
    );
  }

  void _checkAlarm() {
    final alarmProvider = context.read<AlarmProvider>();
    alarmProvider.addListener(_onAlarmStatusChanged);
  }

  void _onAlarmStatusChanged() {
    final alarmProvider = context.read<AlarmProvider>();
    if (alarmProvider.isAlarmActive && mounted) {
      // Sai do modo bolso/economia se o alarme disparar
      if (_pocketMode || _batterySaverMode) {
        setState(() {
          _pocketMode = false;
          _batterySaverMode = false;
        });
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AlarmScreen()),
      );
    }
  }

  void _startHoldTimer() async {
    const totalDuration = Duration(seconds: 2);
    const updateInterval = Duration(milliseconds: 50);
    final steps = totalDuration.inMilliseconds / updateInterval.inMilliseconds;
    
    for (int i = 0; i <= steps && _holdingToExit; i++) {
      await Future.delayed(updateInterval);
      if (!_holdingToExit || !mounted) return;
      
      setState(() {
        _holdProgress = i / steps;
      });
      
      if (_holdProgress >= 1.0) {
        setState(() {
          _pocketMode = false;
          _holdProgress = 0.0;
          _holdingToExit = false;
        });
        return;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    context.read<AlarmProvider>().removeListener(_onAlarmStatusChanged);
    super.dispose();
  }

  void _stopTracking() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Viagem?'),
        content: const Text(
          'Tem certeza que deseja cancelar o rastreamento desta viagem?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AlarmProvider>().stopTracking();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.midnightBlue,
            ),
            child: const Text('Sim, cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // MODO BOLSO - tela completamente preta, ignora toques
    // Precisa SEGURAR por 3 segundos para sair
    if (_pocketMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onLongPressStart: (_) {
            setState(() => _holdingToExit = true);
            _startHoldTimer();
          },
          onLongPressEnd: (_) {
            setState(() {
              _holdingToExit = false;
              _holdProgress = 0.0;
            });
          },
          child: Consumer<AlarmProvider>(
            builder: (context, alarmProvider, child) {
              return Container(
                color: Colors.black,
                width: double.infinity,
                height: double.infinity,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: _holdingToExit ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: CircularProgressIndicator(
                                value: _holdProgress,
                                strokeWidth: 8,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                              ),
                            ),
                            const Icon(
                              Icons.lock_open,
                              color: Colors.white,
                              size: 40,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _holdProgress >= 1.0 ? 'Solte para sair' : 'Segure para desbloquear',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          '${(alarmProvider.distanceToDestination / 1000).toStringAsFixed(1)} km restantes',
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // Modo economia de bateria - tela escura com informações mínimas
    if (_batterySaverMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => setState(() => _batterySaverMode = false),
          child: SafeArea(
            child: Consumer<AlarmProvider>(
              builder: (context, alarmProvider, child) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.battery_saver,
                        color: Colors.green,
                        size: 48,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Modo Economia de Bateria',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${(alarmProvider.distanceToDestination / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'até o destino',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Alarme em ${alarmProvider.alertRadius.toInt()}m',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      const Text(
                        'Toque na tela para voltar',
                        style: TextStyle(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: StarrySkyBackground(
        child: SafeArea(
          child: Consumer<AlarmProvider>(
            builder: (context, alarmProvider, child) {
              final trip = alarmProvider.targetTrip;
              if (trip == null) {
                return const Center(
                  child: Text('Nenhuma viagem ativa'),
                );
              }

              return Column(
                children: [
                  // Banner de aviso para usuários web
                  if (kIsWeb) const WebTrackingBanner(),
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildDistanceIndicator(alarmProvider),
                          const SizedBox(height: 32),
                          _buildTripInfo(trip),
                          const SizedBox(height: 24),
                          _buildExpensesCard(trip),
                          const SizedBox(height: 24),
                          _buildSleepModeCard(),
                          // Botão economia de bateria apenas para iOS/Web
                          if (kIsWeb) ...[
                            const SizedBox(height: 16),
                            _buildBatterySaverButton(),
                          ],
                          const SizedBox(height: 24),
                          _buildCancelButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
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
              'Viagem em Andamento',
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

  Widget _buildDistanceIndicator(AlarmProvider alarmProvider) {
    final progress = alarmProvider.distanceToDestination > 0
        ? 1 - (alarmProvider.distanceToDestination / 10000).clamp(0, 1)
        : 0.0;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.babyBlue.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.babyBlue.withOpacity(0.2),
                          AppColors.lightBlue.withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: CustomPaint(
                      painter: _ProgressPainter(progress: progress.toDouble()),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  alarmProvider.formattedDistance,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'restantes',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.success.withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Rastreando localização...',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTripInfo(Trip trip) {
    return GlassCard(
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.my_location,
            iconColor: AppColors.success,
            label: 'Origem',
            address: trip.originName,
          ),
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.only(left: 10),
            child: Column(
              children: List.generate(
                3,
                (index) => Container(
                  width: 2,
                  height: 8,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.navyBlue,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLocationRow(
            icon: Icons.flag,
            iconColor: AppColors.error,
            label: 'Destino',
            address: trip.destinationName,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSleepModeCard() {
    return GlassCard(
      child: Column(
        children: [
          const SleepyBusLogo(size: 80),
          const SizedBox(height: 16),
          const Text(
            'Modo Soneca Ativado',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Relaxe e descanse. Vamos te avisar quando estiver chegando!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.starYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.notifications_active,
                  color: AppColors.starYellow,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Consumer<AlarmProvider>(
                  builder: (context, alarmProvider, child) {
                    return Text(
                      'Alarme em ${alarmProvider.alertRadius.toInt()}m',
                      style: const TextStyle(
                        color: AppColors.starYellow,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return ElevatedButton.icon(
      onPressed: _stopTracking,
      icon: const Icon(Icons.close),
      label: const Text('Cancelar Viagem'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error,
        foregroundColor: AppColors.midnightBlue,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Widget _buildBatterySaverButton() {
    return GlassCard(
      child: Column(
        children: [
          // Modo Bolso (recomendado)
          InkWell(
            onTap: () => _showPocketModeDialog(),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.back_hand,
                      color: Colors.deepPurple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Modo Bolso',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Recomendado',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tela preta, ignora toques. Segure 2s para sair.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.white.withOpacity(0.1)),
          // Modo Economia Simples
          InkWell(
            onTap: () => setState(() => _batterySaverMode = true),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.battery_saver,
                      color: Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Modo Economia',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tela escura com distância visível',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPocketModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Row(
          children: [
            Icon(Icons.back_hand, color: Colors.deepPurple),
            SizedBox(width: 12),
            Text('Modo Bolso', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A tela ficará completamente preta e não responderá a toques acidentais.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text(
              '📱 Coloque o celular no bolso ou virado para baixo',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              '🔔 O alarme vai tocar normalmente quando chegar',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Text(
              '🔓 Para sair: segure a tela por 2 segundos',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            Text(
              '💡 Dica: Use o "Acesso Guiado" do iOS para economia máxima de bateria (Ajustes > Acessibilidade > Acesso Guiado)',
              style: TextStyle(color: Colors.amber, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _pocketMode = true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
            ),
            child: const Text('Ativar Modo Bolso'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesCard(Trip trip) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    
    // Busca a viagem atualizada do provider para sincronização
    final tripProvider = context.watch<TripProvider>();
    final Trip updatedTrip = tripProvider.getTripById(trip.id) ?? trip;
    
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.starYellow.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet,
                        color: AppColors.starYellow,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        'Gastos da Viagem',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    currencyFormat.format(updatedTrip.totalExpenses),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.starYellow,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (updatedTrip.expenses.isEmpty)
            Center(
              child: Text(
                'Nenhum gasto registrado',
                style: TextStyle(
                  color: AppColors.textMuted.withOpacity(0.7),
                ),
              ),
            )
          else
            ...updatedTrip.expenses.take(3).map((expense) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      expense.category.icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        expense.description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 0,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currencyFormat.format(expense.amount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (updatedTrip.expenses.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+${updatedTrip.expenses.length - 3} gastos...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted.withOpacity(0.7),
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddExpenseScreen(tripId: updatedTrip.id!),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar Gasto'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.babyBlue,
                side: const BorderSide(color: AppColors.babyBlue),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  final double progress;

  _ProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.navyBlue.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.babyBlue, AppColors.lightBlue],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
