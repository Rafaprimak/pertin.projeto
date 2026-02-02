import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pertin/providers/alarm_provider.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/screens/alarm_screen.dart';
import 'package:pertin/screens/add_expense_screen.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/sleepy_bus_logo.dart';
import 'package:pertin/widgets/common_widgets.dart';
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
    });
  }

  void _checkAlarm() {
    final alarmProvider = context.read<AlarmProvider>();
    alarmProvider.addListener(_onAlarmStatusChanged);
  }

  void _onAlarmStatusChanged() {
    final alarmProvider = context.read<AlarmProvider>();
    if (alarmProvider.isAlarmActive && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AlarmScreen()),
      );
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
