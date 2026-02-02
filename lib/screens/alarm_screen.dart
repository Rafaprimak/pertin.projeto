import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pertin/providers/alarm_provider.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/screens/add_expense_screen.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/theme/app_colors.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _flashController;
  late Animation<double> _pulseAnimation;
  late Animation<Color?> _flashAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _flashAnimation = ColorTween(
      begin: AppColors.backgroundDark,
      end: AppColors.babyBlue.withOpacity(0.3),
    ).animate(_flashController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  Future<void> _stopAlarm() async {
    final alarmProvider = context.read<AlarmProvider>();
    final tripProvider = context.read<TripProvider>();
    final trip = alarmProvider.targetTrip;

    await alarmProvider.stopAlarm();
    alarmProvider.stopTracking();

    if (trip != null) {
      await tripProvider.completeTrip(
        trip.id!,
        distance: alarmProvider.distanceToDestination,
      );

      if (mounted) {
        _showTripCompletedDialog(trip.id!);
      }
    }
  }

  void _showTripCompletedDialog(int tripId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Column(
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Você Chegou!',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Viagem concluída com sucesso! Deseja registrar algum gasto desta viagem?',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Depois'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AddExpenseScreen(tripId: tripId),
                ),
              );
            },
            child: const Text('Adicionar Gasto'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _flashAnimation,
        builder: (context, child) {
          return Container(
            color: _flashAnimation.value,
            child: StarrySkyBackground(
              animated: false,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                padding: const EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.babyBlue.withOpacity(0.2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.babyBlue.withOpacity(0.5),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.notifications_active,
                                  size: 100,
                                  color: AppColors.babyBlue,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 48),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [AppColors.babyBlue, AppColors.lightBlue],
                          ).createShader(bounds),
                          child: const Text(
                            'VOCÊ CHEGOU!',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Consumer<AlarmProvider>(
                          builder: (context, alarmProvider, child) {
                            return Text(
                              alarmProvider.targetTrip?.destinationName ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 64),
                        GestureDetector(
                          onTap: _stopAlarm,
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.buttonGradient,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.babyBlue.withOpacity(
                                        0.3 + 0.2 * (_pulseAnimation.value - 1),
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      size: 48,
                                      color: AppColors.midnightBlue,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'DESLIGAR',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.midnightBlue,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Toque para desligar o alarme',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
