import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/sleepy_bus_logo.dart';
import 'package:pertin/widgets/common_widgets.dart';
import 'package:pertin/theme/app_colors.dart';

class TutorialScreen extends StatefulWidget {
  /// Se true, mostra botão de pular e salva que o tutorial foi visto
  final bool isFirstTime;
  
  const TutorialScreen({super.key, this.isFirstTime = false});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialPage> _pages = [
    TutorialPage(
      icon: Icons.directions_bus,
      iconWidget: const SleepyBusLogo(size: 120, animated: true),
      title: 'Bem-vindo ao Pertin!',
      description: 'Seu companheiro de viagem que te avisa quando você está chegando no destino. Nunca mais perca a parada certa!',
      color: AppColors.babyBlue,
    ),
    TutorialPage(
      icon: Icons.add_location_alt,
      title: 'Crie suas Viagens',
      description: 'Adicione uma nova viagem informando o destino. O app vai monitorar sua localização e te alertar quando estiver perto.',
      color: AppColors.success,
      tipText: 'Dica: Você pode agendar viagens futuras!',
    ),
    TutorialPage(
      icon: Icons.notifications_active,
      title: 'Alarme Inteligente',
      description: 'Escolha a distância do alarme (500m a 5km). Quando você estiver próximo do destino, o alarme tocará para te acordar!',
      color: AppColors.warning,
      tipText: 'Perfeito para aquela soneca no ônibus! 😴',
    ),
    TutorialPage(
      icon: Icons.account_balance_wallet,
      title: 'Controle de Gastos',
      description: 'Registre todos os gastos das suas viagens: passagens, alimentação, hospedagem e mais. Veja relatórios por categoria e mês.',
      color: AppColors.starYellow,
      tipText: 'Mantenha suas finanças de viagem organizadas!',
    ),
    TutorialPage(
      icon: Icons.history,
      title: 'Histórico Completo',
      description: 'Todas as suas viagens ficam salvas no histórico. Você pode ver detalhes, adicionar gastos e acompanhar seu progresso.',
      color: AppColors.info,
    ),
    TutorialPage(
      icon: Icons.rocket_launch,
      title: 'Pronto para Viajar!',
      description: 'Agora você está pronto para usar o Pertin. Crie sua primeira viagem e aproveite a tranquilidade de nunca perder sua parada!',
      color: AppColors.babyBlue,
      isLastPage: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeTutorial() async {
    if (widget.isFirstTime) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_completed', true);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeTutorial();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarrySkyBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header com botão de pular
              if (widget.isFirstTime)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _completeTutorial,
                        child: const Text(
                          'Pular',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: AppColors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Tutorial',
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
                ),

              // Conteúdo do tutorial
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index]);
                  },
                ),
              ),

              // Indicadores de página
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? _pages[_currentPage].color
                            : AppColors.navyBlue,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // Botões de navegação
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Row(
                  children: [
                    // Botão voltar
                    if (_currentPage > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousPage,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.white,
                            side: const BorderSide(color: AppColors.navyBlue),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back, size: 20),
                              SizedBox(width: 8),
                              Text('Voltar'),
                            ],
                          ),
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),

                    const SizedBox(width: 16),

                    // Botão próximo/começar
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pages[_currentPage].color,
                          foregroundColor: AppColors.midnightBlue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1
                                  ? 'Começar!'
                                  : 'Próximo',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage == _pages.length - 1
                                  ? Icons.check
                                  : Icons.arrow_forward,
                              size: 20,
                            ),
                          ],
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
    );
  }

  Widget _buildPage(TutorialPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícone ou Widget customizado
          if (page.iconWidget != null)
            page.iconWidget!
          else
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: page.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                page.icon,
                size: 80,
                color: page.color,
              ),
            ),

          const SizedBox(height: 40),

          // Título
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          // Descrição
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),

          // Dica (opcional)
          if (page.tipText != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: page.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: page.color.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: page.color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      page.tipText!,
                      style: TextStyle(
                        fontSize: 14,
                        color: page.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Emoji para última página
          if (page.isLastPage) ...[
            const SizedBox(height: 32),
            const Text(
              '🚌✨',
              style: TextStyle(fontSize: 48),
            ),
          ],
        ],
      ),
    );
  }
}

class TutorialPage {
  final IconData icon;
  final Widget? iconWidget;
  final String title;
  final String description;
  final Color color;
  final String? tipText;
  final bool isLastPage;

  TutorialPage({
    required this.icon,
    this.iconWidget,
    required this.title,
    required this.description,
    required this.color,
    this.tipText,
    this.isLastPage = false,
  });
}
