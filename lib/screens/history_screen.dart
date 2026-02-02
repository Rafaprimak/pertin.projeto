import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pertin/providers/trip_provider.dart';
import 'package:pertin/models/trip.dart';
import 'package:pertin/screens/trip_detail_screen.dart';
import 'package:pertin/widgets/starry_sky_background.dart';
import 'package:pertin/widgets/common_widgets.dart';
import 'package:pertin/theme/app_colors.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StarrySkyBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Histórico de Viagens',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Consumer<TripProvider>(
                builder: (context, tripProvider, child) {
                  if (tripProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.babyBlue,
                      ),
                    );
                  }

                  final trips = tripProvider.trips;

                  if (trips.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildTripsList(context, trips);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus_outlined,
            size: 80,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma viagem ainda',
            style: TextStyle(
              fontSize: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Suas viagens aparecerão aqui',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripsList(BuildContext context, List<Trip> trips) {
    // Group trips by month
    Map<String, List<Trip>> groupedTrips = {};
    final monthFormat = DateFormat('MMMM yyyy', 'pt_BR');

    for (var trip in trips) {
      final key = monthFormat.format(trip.startTime);
      groupedTrips.putIfAbsent(key, () => []);
      groupedTrips[key]!.add(trip);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: groupedTrips.length,
      itemBuilder: (context, index) {
        final month = groupedTrips.keys.elementAt(index);
        final monthTrips = groupedTrips[month]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                month.substring(0, 1).toUpperCase() + month.substring(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...monthTrips.map((trip) => _buildTripCard(context, trip)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    final dateFormat = DateFormat('dd/MM • HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Dismissible(
      key: Key('trip_${trip.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Excluir Viagem?'),
            content: Text('Deseja excluir a viagem "${trip.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.midnightBlue,
                ),
                child: const Text('Excluir'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        context.read<TripProvider>().deleteTrip(trip.id!);
      },
      child: GlassCard(
        margin: const EdgeInsets.symmetric(vertical: 6),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TripDetailScreen(trip: trip),
            ),
          );
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: trip.completed
                    ? AppColors.success.withOpacity(0.15)
                    : AppColors.warning.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                trip.completed ? Icons.check_circle : Icons.pending,
                color: trip.completed ? AppColors.success : AppColors.warning,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.textMuted.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          trip.destinationName,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(trip.startTime),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (trip.totalExpenses > 0)
                  Text(
                    currencyFormat.format(trip.totalExpenses),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.starYellow,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${trip.expenses.length} gastos',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
