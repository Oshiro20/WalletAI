import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../data/database/drift_database.dart';
import '../../../../core/theme/app_colors.dart';

class SearchSummaryCard extends StatelessWidget {
  final double totalAmount;
  final int count;
  final String query;

  const SearchSummaryCard({
    super.key,
    required this.totalAmount,
    required this.count,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Resultados para "$query"',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'S/ ${totalAmount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.expense, // Assuming mostly expense search
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count transacciones encontradas',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class SearchTrendChart extends StatelessWidget {
  final List<Transaction> transactions;

  const SearchTrendChart({super.key, required this.transactions});

  @override
  Widget build(BuildContext context) {
    // 1. Group by Month (YYYY-MM)
    final Map<String, double> monthlyTotals = {};
    
    // Sort transactions by date ascending for the chart
    final sortedTx = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (sortedTx.isEmpty) return const SizedBox.shrink();

    for (var tx in sortedTx) {
      if (tx.type == 'expense') { // Only chart expenses for now
        final key = DateFormat('yyyy-MM').format(tx.date);
        monthlyTotals[key] = (monthlyTotals[key] ?? 0) + tx.amount;
      }
    }

    if (monthlyTotals.isEmpty) return const SizedBox.shrink();

    // 2. Prepare Spot Data
    final List<BarChartGroupData> barGroups = [];
    final List<String> monthLabels = [];
    
    int index = 0;
    monthlyTotals.forEach((key, value) {
      final date = DateFormat('yyyy-MM').parse(key);
      monthLabels.add(DateFormat('MMM').format(date)); // Jan, Feb...
      
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value,
              color: AppColors.expense,
              width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        ),
      );
      index++;
    });

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
              'Tendencia Mensual',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            AspectRatio(
              aspectRatio: 1.5,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: monthlyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          'S/ ${rod.toY.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                          if (value.toInt() >= 0 && value.toInt() < monthLabels.length) {
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
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
