import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_providers.dart';
import '../../../../core/theme/app_colors.dart';

class BalanceTrendChart extends ConsumerStatefulWidget {
  const BalanceTrendChart({super.key});

  @override
  ConsumerState<BalanceTrendChart> createState() => _BalanceTrendChartState();
}

class _BalanceTrendChartState extends ConsumerState<BalanceTrendChart> {
  @override
  Widget build(BuildContext context) {
    final dailyTotalsAsync = ref.watch(currentMonthDailyTotalsProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gasto Diario',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: dailyTotalsAsync.when(
                data: (dailyTotals) {
                  if (dailyTotals.isEmpty) {
                    return const Center(
                      child: Text('No hay actividad este mes'),
                    );
                  }

                  // Preparar datos para el gráfico
                  final now = DateTime.now();
                  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
                  final spots = <FlSpot>[];

                  double maxExpense = 0;

                  for (int i = 1; i <= daysInMonth; i++) {
                    final date = DateTime(now.year, now.month, i);
                    final totals =
                        dailyTotals[date] ?? {'income': 0.0, 'expense': 0.0};
                    final expense = totals['expense'] ?? 0.0;

                    if (expense > maxExpense) maxExpense = expense;

                    spots.add(FlSpot(i.toDouble(), expense));
                  }

                  return LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final int day = value.toInt();
                              if (day % 5 == 0 || day == 1) {
                                // Mostrar cada 5 días
                                return Text(
                                  day.toString(),
                                  style: const TextStyle(fontSize: 10),
                                );
                              }
                              return const SizedBox();
                            },
                            interval: 1,
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: false,
                          ), // Ocultar eje Y para limpieza
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.expense,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.expense.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                      // Tooltip
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                            return touchedBarSpots.map((barSpot) {
                              final flSpot = barSpot;
                              return LineTooltipItem(
                                'Día ${flSpot.x.toInt()} \nS/ ${flSpot.y.toStringAsFixed(2)}',
                                const TextStyle(color: Colors.white),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Text('Error: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
