import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/database_providers.dart';
import '../../../../data/database/drift_database.dart';

class MapAnalyticsView extends ConsumerWidget {
  const MapAnalyticsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return transactionsAsync.when(
      data: (transactions) {
        // Filtran transacciones que tengan gps
        final mappedTransactions = transactions
            .where((t) => t.latitude != null && t.longitude != null)
            .toList();

        if (mappedTransactions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No hay gastos con ubicación',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Agrega la ubicación en tus transacciones para verlas en el mapa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // Centro inicial: primera transacción o un centro por defecto (Lima, por ejemplo) si estuviera muy lejos
        final initialCenter = LatLng(
          mappedTransactions.first.latitude!,
          mappedTransactions.first.longitude!,
        );

        final markers = mappedTransactions.map((t) {
          final isExpense = t.type == 'expense';
          final markerColor = isExpense
              ? AppColors.expense
              : (t.type == 'income' ? AppColors.income : Colors.blue);

          return Marker(
            point: LatLng(t.latitude!, t.longitude!),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _showLocationDetails(context, t),
              child: Icon(Icons.location_on, color: markerColor, size: 40),
            ),
          );
        }).toList();

        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 14.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.walletai.app',
                  ),
                  MarkerLayer(markers: markers),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Error al cargar mapa: $error')),
    );
  }

  void _showLocationDetails(BuildContext context, Transaction transaction) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final symbol = transaction.currency == 'USD' ? '\$' : 'S/';
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.store, size: 32, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      transaction.locationName ?? 'Ubicación Desconocida',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: AppColors.expense.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.arrow_upward,
                    color: AppColors.expense,
                  ),
                ),
                title: Text(
                  transaction.productName ?? transaction.description ?? 'Gasto',
                ),
                subtitle: Text(
                  DateFormat('dd MMM yyyy').format(transaction.date),
                ),
                trailing: Text(
                  '$symbol ${transaction.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.expense,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
