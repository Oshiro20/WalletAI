import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/database_providers.dart';

// ─── Provider de comparación mensual ─────────────────────────────────────────

class MonthComparisonData {
  final double currentIncome;
  final double currentExpense;
  final double prevIncome;
  final double prevExpense;

  const MonthComparisonData({
    required this.currentIncome,
    required this.currentExpense,
    required this.prevIncome,
    required this.prevExpense,
  });

  double get incomeDelta => currentIncome - prevIncome;
  double get expenseDelta => currentExpense - prevExpense;
  double get currentBalance => currentIncome - currentExpense;
  double get prevBalance => prevIncome - prevExpense;
  double get balanceDelta => currentBalance - prevBalance;

  bool get incomeUp => incomeDelta >= 0;
  bool get expenseDown => expenseDelta <= 0; // gasto menor = bueno
  bool get balanceUp => balanceDelta >= 0;
}

final monthComparisonProvider = FutureProvider<MonthComparisonData>((
  ref,
) async {
  final txDao = ref.watch(transactionsDaoProvider);
  final now = DateTime.now();

  // Mes actual
  final curStart = DateTime(now.year, now.month, 1);
  final curEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Mes anterior
  final prevStart = DateTime(now.year, now.month - 1, 1);
  final prevEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

  final curTxs = await txDao.getTransactionsByDateRange(curStart, curEnd);
  final prevTxs = await txDao.getTransactionsByDateRange(prevStart, prevEnd);

  double sumIncome(List txs) =>
      txs.where((t) => t.type == 'income').fold(0.0, (s, t) => s + t.amount);
  double sumExpense(List txs) =>
      txs.where((t) => t.type == 'expense').fold(0.0, (s, t) => s + t.amount);

  return MonthComparisonData(
    currentIncome: sumIncome(curTxs),
    currentExpense: sumExpense(curTxs),
    prevIncome: sumIncome(prevTxs),
    prevExpense: sumExpense(prevTxs),
  );
});

// ─── Widget ───────────────────────────────────────────────────────────────────

class MonthlyComparisonWidget extends ConsumerWidget {
  const MonthlyComparisonWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(monthComparisonProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1);
    final prevLabel = DateFormat('MMMM', 'es').format(prevMonth);
    final fmt = NumberFormat('S/ #,##0.00', 'es');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera
            Row(
              children: [
                Icon(Icons.compare_arrows, color: cs.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'vs $prevLabel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            async.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Text('Error: $e'),
              data: (d) => Column(
                children: [
                  _CompRow(
                    label: 'Ingresos',
                    current: d.currentIncome,
                    delta: d.incomeDelta,
                    isPositiveGood: true,
                    fmt: fmt,
                    cs: cs,
                  ),
                  const Divider(height: 20),
                  _CompRow(
                    label: 'Gastos',
                    current: d.currentExpense,
                    delta: d.expenseDelta,
                    isPositiveGood: false,
                    fmt: fmt,
                    cs: cs,
                  ),
                  const Divider(height: 20),
                  _CompRow(
                    label: 'Balance neto',
                    current: d.currentBalance,
                    delta: d.balanceDelta,
                    isPositiveGood: true,
                    fmt: fmt,
                    cs: cs,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompRow extends StatelessWidget {
  final String label;
  final double current;
  final double delta;
  final bool isPositiveGood;
  final NumberFormat fmt;
  final ColorScheme cs;
  final bool bold;

  const _CompRow({
    required this.label,
    required this.current,
    required this.delta,
    required this.isPositiveGood,
    required this.fmt,
    required this.cs,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final isGood = isPositiveGood ? delta >= 0 : delta <= 0;
    final color = delta == 0
        ? cs.onSurface.withAlpha(150)
        : isGood
        ? Colors.green.shade600
        : Colors.red.shade600;

    final arrow = delta == 0
        ? Icons.remove
        : delta > 0
        ? Icons.arrow_upward_rounded
        : Icons.arrow_downward_rounded;

    final pct = delta == 0 || current - delta == 0
        ? null
        : (delta.abs() / (current - delta).abs() * 100).toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 14 : 13,
          ),
        ),
        Row(
          children: [
            Text(
              fmt.format(current),
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                fontSize: bold ? 14 : 13,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(arrow, size: 12, color: color),
                  if (pct != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      '$pct%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
