import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/database_providers.dart';
import '../../../data/database/drift_database.dart';

class RecurringPaymentsScreen extends ConsumerWidget {
  const RecurringPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsStream = ref.watch(recurringPaymentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagos Recurrentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Sugerencias IA',
            onPressed: () => context.push('/recurring/suggestions'),
          ),
        ],
      ),
      body: paymentsStream.when(
        data: (payments) {
          if (payments.isEmpty) {
            return const Center(
              child: Text(
                'No hay pagos recurrentes activos.\n'
                'Agrega uno con el botón +',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }
          return ListView.builder(
            itemCount: payments.length,
            itemBuilder: (context, index) {
              final payment = payments[index];
              return _RecurringPaymentTile(payment: payment);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/recurring/create'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecurringPaymentTile extends StatelessWidget {
  final RecurringPayment payment;

  const _RecurringPaymentTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          child: const Icon(Icons.loop, color: Colors.blue),
        ),
        title: Text(payment.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monto: \$${payment.amount.toStringAsFixed(2)}'),
            Text('Próximo: ${DateFormat('dd/MM/yyyy').format(payment.nextDueDate)}'),
            Text('Frecuencia: ${_translateFrequency(payment.frequency)}'),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.red),
          onPressed: () => _confirmDelete(context, payment.id),
        ),
      ),
    );
  }

  String _translateFrequency(String freq) {
    const map = {
      'daily': 'Diario',
      'weekly': 'Semanal',
      'monthly': 'Mensual',
      'yearly': 'Anual',
    };
    return map[freq] ?? freq;
  }

  void _confirmDelete(BuildContext context, String id) {
    // Implementar diálogo de confirmación y llamada al DAO
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Pago Recurrente'),
        content: const Text('¿Estás seguro? Esto detendrá los cobros futuros.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          Consumer(
            builder: (context, ref, _) {
              return TextButton(
                onPressed: () async {
                  try {
                    await ref.read(recurringPaymentsDaoProvider).deactivateRecurringPayment(id);
                    if (context.mounted) Navigator.pop(ctx);
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al eliminar pago recurrente: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              );
            },
          ),
        ],
      ),
    );
  }
}
