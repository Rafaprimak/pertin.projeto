import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pertin/providers/user_provider.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/screens/home_screen.dart';
import 'package:pertin/screens/tutorial_screen.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/sleepy_bus_logo.dart';
import 'package:pertin/theme/app_colors.dart';

class EmailVerificationScreen extends StatefulWidget {
  final bool isNewUser;

  const EmailVerificationScreen({super.key, this.isNewUser = true});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  Timer? _verificationCheckTimer;
  bool _isResending = false;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Verifica periodicamente se o email foi verificado
    _startVerificationCheck();
  }

  @override
  void dispose() {
    _verificationCheckTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startVerificationCheck() {
    _verificationCheckTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _checkVerification(),
    );
  }

  Future<void> _checkVerification() async {
    final userProvider = context.read<UserProvider>();
    final isVerified = await userProvider.checkEmailVerification();

    if (isVerified && mounted) {
      _verificationCheckTimer?.cancel();

      // Recarrega as viagens após verificação
      await context.read<TripProvider>().reloadTrips();

      if (mounted) {
        // Navega para a home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );

        // Se for novo usuário, mostra o tutorial
        if (widget.isNewUser && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const TutorialScreen(isFirstTime: true),
            ),
          );
        }
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend || _isResending) return;

    setState(() => _isResending = true);

    final userProvider = context.read<UserProvider>();
    final success = await userProvider.sendEmailVerification();

    setState(() => _isResending = false);

    if (success && mounted) {
      // Inicia cooldown de 60 segundos
      _startResendCooldown();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email de verificação reenviado!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else if (mounted) {
      final error = userProvider.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Erro ao reenviar email'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _startResendCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          _canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _logout() async {
    await context.read<UserProvider>().logout();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final email = userProvider.currentUserEmail ?? 'seu email';

    return Scaffold(
      backgroundColor: AppColors.midnightBlue,
      body: StarrySkyBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SleepyBusLogo(size: 80),
                const SizedBox(height: 32),

                // Ícone de email
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.babyBlue.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 64,
                    color: AppColors.babyBlue,
                  ),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Verifique seu Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Enviamos um link de verificação para:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.babyBlue,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Clique no link do email para ativar sua conta.\nEsta página será atualizada automaticamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // Indicador de verificação
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.babyBlue.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Aguardando verificação...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                // Botão reenviar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _canResend && !_isResending
                        ? _resendVerificationEmail
                        : null,
                    icon: _isResending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(
                      _canResend
                          ? 'Reenviar Email'
                          : 'Aguarde ${_resendCooldown}s',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.babyBlue,
                      foregroundColor: AppColors.midnightBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Verificar manualmente
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _checkVerification,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Já Verifiquei'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.textSecondary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Link para voltar
                TextButton(
                  onPressed: _logout,
                  child: const Text(
                    'Usar outro email',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Dica
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Não encontrou? Verifique a pasta de spam ou lixo eletrônico.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
