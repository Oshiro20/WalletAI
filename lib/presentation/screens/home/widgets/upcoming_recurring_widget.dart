import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../providers/database_providers.dart';
import '../../../../data/database/drift_database.dart';

/// Widget compacto para el Home que muestra los próximos pagos recurrentes.
class UpcomingRecurringWidget extends ConsumerWidget {
  const UpcomingRecurringWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentStream = ref.watch(recurringPaymentsStreamProvider);
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final now = DateTime.now();

    return paymentStream.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (payments) {
        // Mostrar solo los próximos 7 días, máx 3 ítems
        final upcoming = payments
            .where((p) =>
                p.isActive &&
                p.nextDueDate.difference(now).inDays <= 7)
            .toList()
          ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

        if (upcoming.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Próximos Pagos',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.push('/recurring'),
                  child: const Text('Ver todos'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...upcoming.take(3).map((p) => _UpcomingTile(
                  payment: p,
                  fmt: fmt,
                  now: now,
                  cs: cs,
                )),
          ],
        );
      },
    );
  }
}

class _UpcomingTile extends StatelessWidget {
  final RecurringPayment payment;
  final NumberFormat fmt;
  final DateTime now;
  final ColorScheme cs;

  const _UpcomingTile({
    required this.payment,
    required this.fmt,
    required this.now,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final daysLeft = payment.nextDueDate.difference(now).inDays;
    final isOverdue = daysLeft < 0;
    final isToday = daysLeft == 0;

    Color chipColor;
    String chipLabel;
    if (isOverdue) {
      chipColor = Colors.red.shade600;
      chipLabel = 'Vencido';
    } else if (isToday) {
      chipColor = Colors.orange.shade700;
      chipLabel = 'Hoy';
    } else if (daysLeft == 1) {
      chipColor = Colors.orange.shade400;
      chipLabel = 'Mañana';
    } else {
      chipColor = cs.primary;
      chipLabel = 'En $daysLeft d.';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: chipColor.withValues(alpha: 0.15),
          child: Icon(Icons.loop, color: chipColor, size: 20),
        ),
        title: Text(payment.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            DateFormat('dd MMM yyyy', 'es').format(payment.nextDueDate)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(fmt.format(payment.amount),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: chipColor)),
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(chipLabel,
                  style: TextStyle(fontSize: 10, color: chipColor)),
            ),
          ],
        ),
      ),
    );
  }
}
