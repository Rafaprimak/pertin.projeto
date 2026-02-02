import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pertin/providers/user_provider.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/providers/alarm_provider.dart';
import 'package:pertin/services/alarm_service.dart';
import 'package:pertin/screens/home_screen.dart';
import 'package:pertin/screens/onboarding_screen.dart';
import 'package:pertin/screens/email_verification_screen.dart';
import 'package:pertin/widgets/sleepy_bus_logo.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/theme/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Inicializa serviços
      debugPrint('Iniciando AlarmService...');
      await AlarmService.instance.init();
      debugPrint('AlarmService iniciado!');

      // Carrega dados do usuário
      if (!mounted) return;
      debugPrint('Carregando UserProvider...');
      await context.read<UserProvider>().init();
      debugPrint('UserProvider carregado!');

      if (!mounted) return;
      debugPrint('Carregando TripProvider...');
      await context.read<TripProvider>().loadTrips();
      debugPrint('TripProvider carregado!');

      // Restaura o rastreamento se houver viagem ativa
      if (!mounted) return;
      final tripProvider = context.read<TripProvider>();
      final alarmProvider = context.read<AlarmProvider>();
      if (tripProvider.activeTrip != null && !alarmProvider.isTracking) {
        debugPrint(
          'Restaurando rastreamento da viagem ativa: ${tripProvider.activeTrip!.name}',
        );
        await alarmProvider.startTracking(tripProvider.activeTrip!);
      }

      // Aguarda animação
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      final userProvider = context.read<UserProvider>();
      final isLoggedIn = userProvider.isLoggedIn;
      final isEmailVerified = userProvider.isEmailVerified;

      debugPrint(
        'Navegando para: ${isLoggedIn ? (isEmailVerified ? "HomeScreen" : "EmailVerificationScreen") : "OnboardingScreen"}',
      );

      Widget destinationScreen;
      if (isLoggedIn) {
        if (isEmailVerified) {
          destinationScreen = const HomeScreen();
        } else {
          destinationScreen = const EmailVerificationScreen(isNewUser: false);
        }
      } else {
        destinationScreen = const OnboardingScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              destinationScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    } catch (e, stackTrace) {
      // Em caso de erro, vai para onboarding
      debugPrint('Erro no splash: $e');
      debugPrint('StackTrace: $stackTrace');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnightBlue,
      body: StarrySkyBackground(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SleepyBusLogo(size: 180),
                      const SizedBox(height: 32),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.babyBlue, AppColors.lightBlue],
                        ).createShader(bounds),
                        child: const Text(
                          'Pertin',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Durma tranquilo, chegue no destino',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary.withOpacity(0.8),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.babyBlue.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
