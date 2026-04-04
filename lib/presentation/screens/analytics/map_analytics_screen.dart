import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';

class MapAnalyticsScreen extends ConsumerStatefulWidget {
  const MapAnalyticsScreen({super.key});

  @override
  ConsumerState<MapAnalyticsScreen> createState() => _MapAnalyticsScreenState();
}

class _MapAnalyticsScreenState extends ConsumerState<MapAnalyticsScreen> {
  final MapController _mapController = MapController();
  final String _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Gastos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Centrar en resultados',
            onPressed: () {
              // Si hay datos, centraremos aquí
              // Por ahora, recargar
            },
          ),
        ],
      ),
      body: transactionsAsync.when(
        data: (transactions) {
          // Filtrar las que tienen Lat y Lon válidos
          final gpsTransactions = transactions
              .where((t) => t.latitude != null && t.longitude != null)
              .toList();

          if (gpsTransactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text('No hay transacciones con ubicación 📍'),
                  const SizedBox(height: 8),
                  const Text(
                    'Recuerda usar el botón "GPS" al crear transacciones.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Calcular el centro promedio para iniciar la cámara
          double avgLat = 0;
          double avgLon = 0;
          for (var t in gpsTransactions) {
            avgLat += t.latitude!;
            avgLon += t.longitude!;
          }
          avgLat /= gpsTransactions.length;
          avgLon /= gpsTransactions.length;

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(avgLat, avgLon),
              initialZoom: 13.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _osmUrl,
                userAgentPackageName: 'com.walletai.app',
              ),
              MarkerLayer(
                markers: gpsTransactions.map((tx) {
                  return Marker(
                    point: LatLng(tx.latitude!, tx.longitude!),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => _showTransactionPopup(tx),
                      child: Icon(
                        tx.type == 'expense'
                            ? Icons.location_on
                            : Icons.location_on,
                        color: tx.type == 'expense' ? Colors.red : Colors.green,
                        size: 40,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showTransactionPopup(Transaction tx) {
    final formatCurrency = NumberFormat.currency(
      symbol: '${tx.currency} ',
      decimalDigits: 2,
    );
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: tx.type == 'expense'
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.green.withValues(alpha: 0.1),
                    child: Icon(
                      tx.type == 'expense'
                          ? Icons.trending_down
                          : Icons.trending_up,
                      color: tx.type == 'expense' ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.description ?? tx.productName ?? 'Transacción',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat("dd MMM yyyy").format(tx.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrency.format(tx.amount),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: tx.type == 'expense' ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (tx.locationName != null) ...[
                Row(
                  children: [
                    const Icon(Icons.place, color: Colors.grey, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tx.locationName!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
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
