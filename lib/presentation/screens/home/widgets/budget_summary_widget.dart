import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/database_providers.dart';
import '../../../../data/database/drift_database.dart';

/// Widget compacto para el Home que muestra el estado de los presupuestos del mes
class BudgetSummaryWidget extends ConsumerWidget {
  const BudgetSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return budgetsAsync.when(
      data: (budgets) {
        if (budgets.isEmpty) return const SizedBox();

        return categoriesAsync.when(
          data: (categories) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Presupuestos',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/budgets'),
                      child: const Text('Ver todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...budgets.take(3).map((budget) {
                  final category = categories
                      .where((c) => c.id == budget.categoryId)
                      .firstOrNull;
                  return _BudgetMiniCard(
                    budget: budget,
                    categoryName: category?.name ?? 'Categoría',
                    categoryIcon: category?.icon ?? '💰',
                    categoryColor: category?.color,
                  );
                }),
                if (budgets.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: () => context.push('/budgets'),
                      child: Text(
                        '+ ${budgets.length - 3} presupuestos más',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _BudgetMiniCard extends ConsumerWidget {
  final Budget budget;
  final String categoryName;
  final String categoryIcon;
  final String? categoryColor;

  const _BudgetMiniCard({
    required this.budget,
    required this.categoryName,
    required this.categoryIcon,
    this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spentAsync = ref.watch(budgetSpentProvider(budget.categoryId));

    Color catColor = Theme.of(context).colorScheme.primary;
    try {
      if (categoryColor != null) {
        catColor = Color(int.parse(categoryColor!.replaceFirst('#', '0xFF')));
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: spentAsync.when(
        data: (spent) {
          final pct = (spent / budget.amount).clamp(0.0, 1.0);
          final isOver = spent > budget.amount;
          final barColor = isOver
              ? Colors.red
              : pct >= 0.8
              ? Colors.orange
              : catColor;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(categoryIcon, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'S/ ${spent.toStringAsFixed(0)} / ${budget.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOver
                          ? Colors.red
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: isOver ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          );
        },
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox(),
      ),
    );
  }
}

// Re-export providers needed by this widget
final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final dao = ref.watch(budgetsDaoProvider);
  return dao.watchActiveBudgets();
});

final budgetSpentProvider = FutureProvider.autoDispose.family<double, String>((
  ref,
  categoryId,
) async {
  final dao = ref.watch(transactionsDaoProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final map = await dao.getExpensesByCategory(start, end);
  return map[categoryId] ?? 0.0;
});
