import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pertin/models/trip.dart';
import 'package:pertin/providers/user_provider.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/providers/alarm_provider.dart';
import 'package:pertin/screens/onboarding_screen.dart';
import 'package:pertin/screens/tutorial_screen.dart';
import 'package:pertin/services/alarm_service.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/sleepy_bus_logo.dart';
import 'package:pertin/widgets/common_widgets.dart';
import 'package:pertin/theme/app_colors.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isTestingAlarm = false;

  @override
  Widget build(BuildContext context) {
    return StarrySkyBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildProfileHeader(context),
              const SizedBox(height: 32),
              _buildStatsCards(context),
              const SizedBox(height: 24),
              _buildSettingsSection(context),
              const SizedBox(height: 24),
              _buildAboutSection(),
              const SizedBox(height: 24),
              _buildLogoutButton(context),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;

        return GlassCard(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.babyBlue.withOpacity(0.3),
                      AppColors.lightBlue.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppColors.babyBlue,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? 'Viajante',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (user != null)
                Text(
                  'Membro desde ${DateFormat('MMMM yyyy', 'pt_BR').format(user.createdAt)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCards(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, tripProvider, child) {
        final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Viagens Realizadas',
                    value: '${tripProvider.completedTrips.length}',
                    icon: Icons.check_circle,
                    iconColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    title: 'Total de Viagens',
                    value: '${tripProvider.trips.length}',
                    icon: Icons.directions_bus,
                    iconColor: AppColors.babyBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    title: 'Total em Gastos',
                    value: currencyFormat.format(tripProvider.totalExpenses),
                    icon: Icons.account_balance_wallet,
                    iconColor: AppColors.starYellow,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Configurações',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildSettingItem(
                icon: Icons.person_outline,
                title: 'Editar Perfil',
                onTap: () {
                  _showEditProfileDialog(context);
                },
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.notifications_outlined,
                title: 'Notificações',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeTrackColor: AppColors.babyBlue.withValues(alpha: 0.5),
                  activeThumbColor: AppColors.babyBlue,
                ),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.vibration,
                title: 'Vibração do Alarme',
                trailing: Switch(
                  value: true,
                  onChanged: (value) {},
                  activeTrackColor: AppColors.babyBlue.withValues(alpha: 0.5),
                  activeThumbColor: AppColors.babyBlue,
                ),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.alarm,
                title: 'Testar Alarme',
                trailing: _isTestingAlarm
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.babyBlue,
                        ),
                      )
                    : const Icon(
                        Icons.play_circle_outline,
                        color: AppColors.babyBlue,
                      ),
                onTap: _isTestingAlarm ? null : () => _testAlarm(context),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.file_download_outlined,
                title: 'Exportar Viagens (CSV)',
                onTap: () => _exportTripsToCSV(context),
              ),
              _buildDivider(),
              _buildSettingItem(
                icon: Icons.help_outline,
                title: 'Ver Tutorial',
                trailing: const Icon(
                  Icons.play_circle_outline,
                  color: AppColors.babyBlue,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const TutorialScreen(isFirstTime: false),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.babyBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.babyBlue, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
      ),
      trailing: trailing ?? const Icon(
        Icons.chevron_right,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: AppColors.navyBlue.withOpacity(0.3),
      indent: 56,
    );
  }

  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Sobre',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        GlassCard(
          child: Column(
            children: [
              const SleepyBusLogo(size: 80, animated: false),
              const SizedBox(height: 16),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppColors.babyBlue, AppColors.lightBlue],
                ).createShader(bounds),
                child: const Text(
                  'Pertin',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Versão 1.0.0',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Seu companheiro de viagem que te avisa quando você está chegando no destino.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        _showLogoutDialog(context);
      },
      icon: const Icon(Icons.logout, color: AppColors.error),
      label: const Text(
        'Sair da Conta',
        style: TextStyle(color: AppColors.error),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final userProvider = context.read<UserProvider>();
    final nameController = TextEditingController(text: userProvider.user?.name);
    final emailController = TextEditingController(text: userProvider.user?.email);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nome',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await userProvider.updateProfile(
                name: nameController.text,
                email: emailController.text,
              );
              Navigator.pop(context);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da Conta?'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<UserProvider>().logout();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const OnboardingScreen(),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAlarm(BuildContext context) async {
    setState(() => _isTestingAlarm = true);
    
    try {
      await AlarmService.instance.playAlarm();
      
      // Mostra dialog para parar o alarme
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardDark,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.alarm, color: AppColors.warning),
                SizedBox(width: 12),
                Text(
                  'Alarme de Teste',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
            content: const Text(
              'O alarme está tocando. Clique em "Parar" para encerrar o teste.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  await AlarmService.instance.stopAlarm();
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Parar Alarme'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao testar alarme: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() => _isTestingAlarm = false);
    }
  }

  Future<void> _exportTripsToCSV(BuildContext context) async {
    final tripProvider = context.read<TripProvider>();
    final trips = tripProvider.trips;
    
    if (trips.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma viagem para exportar'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Na web, exportação de arquivos não é suportada da mesma forma
    if (kIsWeb) {
      await _exportToClipboard(context, trips);
      return;
    }

    try {
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
      
      // Cabeçalho do CSV de viagens
      final StringBuffer csvTrips = StringBuffer();
      csvTrips.writeln('ID,Nome,Origem,Destino,Status,Data Início,Data Fim,Total Gastos');
      
      for (final trip in trips) {
        final startTime = dateFormat.format(trip.startTime);
        final endTime = trip.endTime != null ? dateFormat.format(trip.endTime!) : '';
        final totalExpenses = currencyFormat.format(trip.totalExpenses);
        
        // Escapa campos com vírgulas ou aspas
        final name = _escapeCsvField(trip.name);
        final origin = _escapeCsvField(trip.originName);
        final destination = _escapeCsvField(trip.destinationName);
        
        csvTrips.writeln('${trip.id},$name,$origin,$destination,${trip.status.displayName},$startTime,$endTime,$totalExpenses');
      }

      // Cabeçalho do CSV de despesas
      final StringBuffer csvExpenses = StringBuffer();
      csvExpenses.writeln('Viagem,Descrição,Categoria,Valor,Data');
      
      for (final trip in trips) {
        for (final expense in trip.expenses) {
          final tripName = _escapeCsvField(trip.name);
          final description = _escapeCsvField(expense.description);
          final amount = currencyFormat.format(expense.amount);
          final date = dateFormat.format(expense.date);
          
          csvExpenses.writeln('$tripName,$description,${expense.category.displayName},$amount,$date');
        }
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      
      // Tentar salvar na pasta de Downloads (Android) ou Documents (iOS)
      Directory? saveDirectory;
      String savedPath = '';
      
      if (Platform.isAndroid) {
        // No Android, salvar em Downloads via pasta externa
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Navegar para a pasta Downloads do armazenamento interno
          final downloadsPath = '${externalDir.parent.parent.parent.parent.path}/Download';
          final downloadsDir = Directory(downloadsPath);
          if (await downloadsDir.exists()) {
            saveDirectory = downloadsDir;
            savedPath = 'Downloads';
          }
        }
      } else if (Platform.isIOS) {
        // No iOS, usar Documents
        saveDirectory = await getApplicationDocumentsDirectory();
        savedPath = 'Arquivos';
      }
      
      // Fallback para diretório temporário se não conseguir acessar Downloads
      if (saveDirectory == null) {
        saveDirectory = await getTemporaryDirectory();
        savedPath = 'temporário';
      }
      
      final tripsFile = File('${saveDirectory.path}/pertin_viagens_$timestamp.csv');
      final expensesFile = File('${saveDirectory.path}/pertin_despesas_$timestamp.csv');
      
      await tripsFile.writeAsString(csvTrips.toString());
      await expensesFile.writeAsString(csvExpenses.toString());

      if (mounted) {
        // Mostrar diálogo de sucesso com opções
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 28),
                const SizedBox(width: 12),
                const Text('Arquivos salvos!', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Os arquivos CSV foram salvos na pasta $savedPath:',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description, size: 16, color: AppColors.babyBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'pertin_viagens_$timestamp.csv',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.receipt_long, size: 16, color: AppColors.starYellow),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'pertin_despesas_$timestamp.csv',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fechar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  // Compartilhar arquivos como alternativa
                  await Share.shareXFiles(
                    [XFile(tripsFile.path), XFile(expensesFile.path)],
                    subject: 'Dados de Viagens - Pertin',
                    text: 'Exportação de viagens e despesas do app Pertin',
                  );
                },
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Compartilhar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.babyBlue,
                  foregroundColor: AppColors.midnightBlue,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao exportar CSV: $e');
      if (mounted) {
        // Tenta exportar para área de transferência como fallback
        await _exportToClipboard(context, trips);
      }
    }
  }

  Future<void> _exportToClipboard(BuildContext context, List<Trip> trips) async {
    try {
      final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
      final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
      
      final StringBuffer csv = StringBuffer();
      csv.writeln('=== VIAGENS ===');
      csv.writeln('ID\tNome\tOrigem\tDestino\tStatus\tData Início\tData Fim\tTotal Gastos');
      
      for (final trip in trips) {
        final startTime = dateFormat.format(trip.startTime);
        final endTime = trip.endTime != null ? dateFormat.format(trip.endTime!) : '';
        final totalExpenses = currencyFormat.format(trip.totalExpenses);
        
        csv.writeln('${trip.id}\t${trip.name}\t${trip.originName}\t${trip.destinationName}\t${trip.status.displayName}\t$startTime\t$endTime\t$totalExpenses');
      }
      
      csv.writeln('\n=== DESPESAS ===');
      csv.writeln('Viagem\tDescrição\tCategoria\tValor\tData');
      
      for (final trip in trips) {
        for (final expense in trip.expenses) {
          final amount = currencyFormat.format(expense.amount);
          final date = dateFormat.format(expense.date);
          csv.writeln('${trip.name}\t${expense.description}\t${expense.category.displayName}\t$amount\t$date');
        }
      }

      await Clipboard.setData(ClipboardData(text: csv.toString()));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dados copiados para a área de transferência! Cole em uma planilha.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao exportar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
