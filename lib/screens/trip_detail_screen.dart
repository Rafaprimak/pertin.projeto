import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pertin/models/trip.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/providers/alarm_provider.dart';
import 'package:pertin/screens/add_expense_screen.dart';
import 'package:pertin/screens/edit_expense_screen.dart';
import 'package:pertin/screens/tracking_screen.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/common_widgets.dart';
import 'package:pertin/theme/app_colors.dart';
import 'package:intl/intl.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late Trip _trip;
  
  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
  }

  Color _getStatusColor(TripStatus status) {
    switch (status) {
      case TripStatus.agendada:
        return AppColors.info;
      case TripStatus.emAndamento:
        return AppColors.warning;
      case TripStatus.concluida:
        return AppColors.success;
      case TripStatus.cancelada:
        return AppColors.error;
      case TripStatus.adiada:
        return AppColors.babyBlue;
      case TripStatus.pausada:
        return AppColors.navyBlue;
    }
  }

  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Alterar Status da Viagem',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ...TripStatus.values.map((status) {
              final isSelected = status == _trip.status;
              return ListTile(
                leading: Icon(
                  status.icon,
                  color: _getStatusColor(status),
                ),
                title: Text(
                  status.displayName,
                  style: TextStyle(
                    color: isSelected ? _getStatusColor(status) : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: _getStatusColor(status))
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: isSelected
                    ? _getStatusColor(status).withOpacity(0.15)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  if (status != _trip.status) {
                    final tripProvider = context.read<TripProvider>();
                    final alarmProvider = context.read<AlarmProvider>();
                    
                    final success = await tripProvider.updateTripStatus(_trip.id, status);
                    
                    if (success && mounted) {
                      // Se mudou para cancelada, concluída ou adiada, para o tracking
                      final shouldStopTracking = status == TripStatus.cancelada ||
                                                  status == TripStatus.concluida ||
                                                  status == TripStatus.adiada;
                      
                      if (shouldStopTracking && 
                          alarmProvider.isTracking && 
                          alarmProvider.targetTrip?.id == _trip.id) {
                        alarmProvider.stopTracking();
                      }
                      
                      setState(() {
                        _trip = _trip.copyWith(
                          status: status,
                          completed: status == TripStatus.concluida,
                        );
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Status alterado para: ${status.displayName}'),
                          backgroundColor: _getStatusColor(status),
                        ),
                      );
                    }
                  }
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Scaffold(
      body: StarrySkyBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      if (_trip.status == TripStatus.agendada) ...[
                        const SizedBox(height: 16),
                        _buildStartScheduledTripButton(),
                      ],
                      const SizedBox(height: 24),
                      _buildRouteCard(),
                      const SizedBox(height: 24),
                      _buildInfoCards(dateFormat),
                      const SizedBox(height: 24),
                      _buildExpensesSection(context, currencyFormat),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddExpenseScreen(tripId: _trip.id!),
            ),
          );
        },
        backgroundColor: AppColors.babyBlue,
        foregroundColor: AppColors.midnightBlue,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Gasto'),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
              'Detalhes da Viagem',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: _showDeleteConfirmation,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 12),
            Text(
              'Excluir Viagem',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Tem certeza que deseja excluir a viagem "${_trip.name}"?\n\nTodas as despesas associadas também serão excluídas. Esta ação não pode ser desfeita.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Fecha o dialog
              await _deleteTrip();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTrip() async {
    final tripProvider = context.read<TripProvider>();
    
    await tripProvider.deleteTrip(_trip.id);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Viagem excluída com sucesso'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context); // Volta para a tela anterior
    }
  }

  Widget _buildHeader() {
    final statusColor = _getStatusColor(_trip.status);
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _trip.status.icon,
            color: statusColor,
            size: 40,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _trip.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showStatusPicker,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _trip.status.icon,
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _trip.status.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.edit,
                        size: 12,
                        color: statusColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStartScheduledTripButton() {
    final dateFormat = DateFormat('dd/MM/yyyy \'às\' HH:mm');
    final scheduledTime = _trip.scheduledStartTime;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event,
                  color: AppColors.info,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Viagem Agendada',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (scheduledTime != null)
                      Text(
                        'Programada para ${dateFormat.format(scheduledTime)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startScheduledTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text(
                'Iniciar Viagem Agora',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startScheduledTrip() async {
    final tripProvider = context.read<TripProvider>();
    final alarmProvider = context.read<AlarmProvider>();
    
    try {
      final updatedTrip = await tripProvider.startScheduledTrip(_trip.id);
      
      if (updatedTrip != null && mounted) {
        // Inicia o tracking com o alarme
        await alarmProvider.startTracking(updatedTrip);

        // Atualiza o estado local
        setState(() {
          _trip = updatedTrip;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Viagem iniciada! Acompanhe sua localização.'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navega para a tela de tracking
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const TrackingScreen(),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao iniciar viagem. Tente novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Erro ao iniciar viagem agendada: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildRouteCard() {
    return GlassCard(
      child: Column(
        children: [
          _buildLocationRow(
            icon: Icons.my_location,
            iconColor: AppColors.success,
            label: 'Origem',
            address: _trip.originName,
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
            address: _trip.destinationName,
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

  Widget _buildInfoCards(DateFormat dateFormat) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Row(
      children: [
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: AppColors.babyBlue,
                  size: 24,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Início',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  dateFormat.format(_trip.startTime),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.starYellow,
                  size: 24,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Total Gasto',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  currencyFormat.format(_trip.totalExpenses),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.starYellow,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpensesSection(BuildContext context, NumberFormat currencyFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gastos',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_trip.expenses.isEmpty)
          GlassCard(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: AppColors.textMuted.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nenhum gasto registrado',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ..._trip.expenses.map((expense) {
            return GlassCard(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditExpenseScreen(
                      tripId: _trip.id!,
                      expenseId: expense.id!,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.babyBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      expense.category.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.description,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          expense.category.displayName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit_outlined,
                    color: AppColors.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currencyFormat.format(expense.amount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.starYellow,
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 80),
      ],
    );
  }
}
