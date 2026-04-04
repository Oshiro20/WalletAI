import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../providers/database_providers.dart';
import '../../../../data/database/drift_database.dart';

/// Widget compacto para el Home que muestra el progreso de las metas de ahorro.
class SavingsSummaryWidget extends ConsumerWidget {
  const SavingsSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(_savingsGoalsStreamProvider);
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    return goalsAsync.when(
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
      data: (goals) {
        if (goals.isEmpty) return const SizedBox();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Metas de Ahorro',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.push('/savings'),
                  child: const Text('Ver todas'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...goals
                .take(3)
                .map((goal) => _SavingsTile(goal: goal, fmt: fmt, cs: cs)),
          ],
        );
      },
    );
  }
}

class _SavingsTile extends StatelessWidget {
  final SavingsGoal goal;
  final NumberFormat fmt;
  final ColorScheme cs;

  const _SavingsTile({required this.goal, required this.fmt, required this.cs});

  @override
  Widget build(BuildContext context) {
    final progress = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final isComplete = progress >= 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isComplete ? Icons.check_circle : Icons.flag_outlined,
                  color: isComplete ? Colors.green : cs.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    goal.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isComplete ? Colors.green : cs.primary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: cs.surfaceContainerHighest,
              color: isComplete ? Colors.green : cs.primary,
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  fmt.format(goal.currentAmount),
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  fmt.format(goal.targetAmount),
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Stream provider interno para metas de ahorro activas
final _savingsGoalsStreamProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final dao = ref.watch(savingsGoalsDaoProvider);
  return dao.watchActiveGoals();
});
