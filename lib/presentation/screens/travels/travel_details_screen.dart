import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';

class TravelDetailsScreen extends ConsumerWidget {
  final String travelId;

  const TravelDetailsScreen({super.key, required this.travelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Escuchar el viaje actual (podemos filtrarlo de allTravels o hacer un Future)
    final travelsAsync = ref.watch(allTravelsStreamProvider);

    return travelsAsync.when(
      data: (travels) {
        final travel = travels.firstWhere((t) => t.id == travelId);

        return Scaffold(
          appBar: AppBar(
            title: Text(travel.name),
            actions: [
              if (travel.isActive)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Center(
                    child: Chip(
                      label: Text(
                        'Activo',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          body: FutureBuilder<List<Transaction>>(
            future: _getTravelTransactions(ref, travelId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final transactions = snapshot.data ?? [];
              final totalSpent = transactions.fold<double>(
                0,
                (sum, t) => sum + (t.type == 'expense' ? t.amount : 0),
              );

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBudgetCard(context, travel, totalSpent),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Transacciones',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${transactions.length} items',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                        child: Text(
                          'No hay transacciones registradas en este viaje.',
                        ),
                      ),
                    )
                  else
                    ...transactions.map(
                      (t) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: t.type == 'expense'
                              ? Colors.red.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            t.type == 'expense'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: t.type == 'expense'
                                ? Colors.red
                                : Colors.green,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          t.description ?? t.productName ?? 'Sin descripción',
                        ),
                        subtitle: Text(DateFormat('dd MMM').format(t.date)),
                        trailing: Text(
                          '${t.type == 'expense' ? '-' : '+'} ${t.amount.toStringAsFixed(2)} ${t.currency}',
                          style: TextStyle(
                            color: t.type == 'expense'
                                ? Colors.red
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildBudgetCard(
    BuildContext context,
    Travel travel,
    double totalSpent,
  ) {
    if (travel.budget <= 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Gastado',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Text(
                '${totalSpent.toStringAsFixed(2)} ${travel.baseCurrency}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final percentage = (totalSpent / travel.budget).clamp(0.0, 1.0);
    final remaining = travel.budget - totalSpent;
    final isOverBudget = remaining < 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Presupuesto del Viaje',
                  style: TextStyle(fontSize: 16),
                ),
                Text(
                  '${travel.budget.toStringAsFixed(2)} ${travel.baseCurrency}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percentage,
              minHeight: 12,
              borderRadius: BorderRadius.circular(6),
              backgroundColor: Colors.grey.shade200,
              color: isOverBudget ? Colors.red : Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gastado: ${totalSpent.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                Text(
                  isOverBudget
                      ? 'Excedido por: ${remaining.abs().toStringAsFixed(2)}'
                      : 'Disponible: ${remaining.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: isOverBudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Transaction>> _getTravelTransactions(
    WidgetRef ref,
    String contextId,
  ) async {
    final dao = ref.read(transactionsDaoProvider);
    // Hacemos una simple consulta acá para obtener las transacciones de este viaje.
    return (dao.select(dao.transactions)
          ..where((t) => t.contextId.equals(contextId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();
  }
}
