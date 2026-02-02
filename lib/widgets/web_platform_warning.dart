import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pertin/theme/app_colors.dart';

/// Widget que mostra um aviso importante para usuários da versão web
/// Especialmente útil para instruir usuários de iPhone sobre como usar o app
class WebPlatformWarning extends StatefulWidget {
  final VoidCallback? onDismiss;
  final VoidCallback? onInstallPWA;
  final VoidCallback? onRequestPermissions;

  const WebPlatformWarning({
    super.key,
    this.onDismiss,
    this.onInstallPWA,
    this.onRequestPermissions,
  });

  @override
  State<WebPlatformWarning> createState() => _WebPlatformWarningState();
}

class _WebPlatformWarningState extends State<WebPlatformWarning> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: 0.15),
            AppColors.starYellow.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.phone_iphone,
                      color: AppColors.warning,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📱 Dica para iPhone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Toque para ver instruções importantes',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          AnimatedCrossFade(
            firstChild: _buildExpandedContent(),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _isExpanded 
                ? CrossFadeState.showFirst 
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.navyBlue),
          const SizedBox(height: 8),
          
          // Instruções
          _buildInstruction(
            icon: Icons.download_rounded,
            title: 'Instale como App',
            description: 'Safari → Compartilhar (↑) → "Adicionar à Tela de Início"',
          ),
          const SizedBox(height: 12),
          
          _buildInstruction(
            icon: Icons.notifications_active,
            title: 'Permita Notificações',
            description: 'Necessário para o alarme funcionar em segundo plano',
          ),
          const SizedBox(height: 12),
          
          _buildInstruction(
            icon: Icons.visibility,
            title: 'Mantenha o App Visível',
            description: 'Durante viagens, deixe o app aberto na tela',
          ),
          const SizedBox(height: 12),
          
          _buildInstruction(
            icon: Icons.battery_charging_full,
            title: 'Desative Economia de Bateria',
            description: 'Ajustes → Bateria → Modo de Baixa Energia: OFF',
          ),
          
          const SizedBox(height: 16),
          
          // Botões de ação
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onRequestPermissions,
                  icon: const Icon(Icons.notifications, size: 18),
                  label: const Text('Permitir Notificações'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.babyBlue,
                    side: const BorderSide(color: AppColors.babyBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Botão de fechar
          Center(
            child: TextButton(
              onPressed: widget.onDismiss,
              child: const Text(
                'Entendi, não mostrar novamente',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstruction({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.babyBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            color: AppColors.babyBlue,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Banner compacto que fica fixo no topo durante o tracking
class WebTrackingBanner extends StatelessWidget {
  const WebTrackingBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success.withValues(alpha: 0.9),
            AppColors.success.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: const SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '📱 Mantenha esta tela visível para garantir que o alarme funcione!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
