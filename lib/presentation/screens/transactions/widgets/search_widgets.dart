import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/text_search_helper.dart';
import '../../../../data/database/drift_database.dart';

class SearchSummaryCard extends StatelessWidget {
  final double totalExpense;
  final double totalIncome;
  final double totalTransfer;
  final int count;
  final String query;

  const SearchSummaryCard({
    super.key,
    required this.totalExpense,
    this.totalIncome = 0,
    this.totalTransfer = 0,
    required this.count,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Determinar el monto principal a destacar según el tipo predominante
    final double primaryAmount;
    final Color primaryColor;
    final String primaryLabel;
    if (totalExpense > 0) {
      primaryAmount = totalExpense;
      primaryColor = AppColors.expense;
      primaryLabel = 'Total gastado';
    } else if (totalIncome > 0) {
      primaryAmount = totalIncome;
      primaryColor = AppColors.income;
      primaryLabel = 'Total ingresado';
    } else {
      primaryAmount = totalTransfer;
      primaryColor = AppColors.transfer;
      primaryLabel = 'Total transferido';
    }

    final hasMultipleTypes =
        [totalExpense > 0, totalIncome > 0, totalTransfer > 0]
            .where((active) => active)
            .length >
        1;

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Resultados para "$query"',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              primaryLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'S/ ${primaryAmount.toStringAsFixed(2)}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count ${count == 1 ? "transacción encontrada" : "transacciones encontradas"}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (hasMultipleTypes) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (totalIncome > 0)
                    _MiniMetric(
                      label: 'Ingresos',
                      amount: totalIncome,
                      color: AppColors.income,
                    ),
                  if (totalExpense > 0)
                    _MiniMetric(
                      label: 'Gastos',
                      amount: totalExpense,
                      color: AppColors.expense,
                    ),
                  if (totalTransfer > 0)
                    _MiniMetric(
                      label: 'Transfer.',
                      amount: totalTransfer,
                      color: AppColors.transfer,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 2),
        Text(
          'S/ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}

class SearchTrendChart extends StatelessWidget {
  final List<Transaction> transactions;
  final Map<String, double> rates;

  const SearchTrendChart({
    super.key,
    required this.transactions,
    this.rates = const {'PEN': 1.0},
  });

  @override
  Widget build(BuildContext context) {
    final sortedTx = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sortedTx.isEmpty) return const SizedBox.shrink();

    final hasExpenses = sortedTx.any((tx) => tx.type == 'expense');
    final targetType = hasExpenses ? 'expense' : 'income';
    final barColor = hasExpenses ? AppColors.expense : AppColors.income;
    final chartTitle = hasExpenses
        ? 'Tendencia Mensual de Gastos'
        : 'Tendencia Mensual de Ingresos';

    final Map<String, double> monthlyTotals = {};
    for (final tx in sortedTx) {
      if (tx.type == targetType) {
        final key = DateFormat('yyyy-MM').format(tx.date);
        final amountInPen = TextSearchHelper.convertToPen(
          tx.amount,
          tx.currency,
          rates,
        );
        monthlyTotals[key] = (monthlyTotals[key] ?? 0) + amountInPen;
      }
    }

    if (monthlyTotals.isEmpty) return const SizedBox.shrink();

    final List<BarChartGroupData> barGroups = [];
    final List<String> monthLabels = [];

    int index = 0;
    monthlyTotals.forEach((key, value) {
      final date = DateFormat('yyyy-MM').parse(key);
      monthLabels.add(DateFormat('MMM yy', 'es_PE').format(date));

      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value,
              color: barColor,
              width: 16,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ],
        ),
      );
      index++;
    });

    final maxVal = monthlyTotals.values.reduce((a, b) => a > b ? a : b);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              chartTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.5,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxVal > 0 ? maxVal * 1.2 : 10,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          'S/ ${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < monthLabels.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                monthLabels[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
