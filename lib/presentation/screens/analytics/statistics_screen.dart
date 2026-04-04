import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../presentation/providers/database_providers.dart';
import '../../../core/utils/period_filter.dart';
import '../../../data/datasources/report_generation_service.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedPeriod = ref.watch(selectedAnalyticsPeriodProvider);
    final compAsync = ref.watch(periodComparisonProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar a PDF',
            onPressed: () async {
              if (transactionsAsync is AsyncLoading) return;
              if (compAsync is AsyncLoading) return;

              final list = transactionsAsync.valueOrNull ?? [];
              final comp = compAsync.valueOrNull;
              // Add categories loading
              final categoriesList =
                  ref.read(expenseCategoriesStreamProvider).valueOrNull ?? [];

              if (list.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No hay transacciones para exportar.'),
                  ),
                );
                return;
              }

              final currentExp = comp?['currentExpense'] ?? 0.0;
              final currentInc = comp?['currentIncome'] ?? 0.0;
              final periodStr = selectedPeriod.format(selectedDate);

              await ReportGenerationService.generateAndSharePdf(
                transactions: list,
                categories: categoriesList,
                monthYear: periodStr,
                totalIncome: currentInc,
                totalExpense: currentExp,
                baseCurrency: 'S/',
              );
            },
          ),
          DropdownButton<TimePeriod>(
            value: selectedPeriod,
            icon: Icon(
              Icons.calendar_today,
              color:
                  Theme.of(context).appBarTheme.foregroundColor ?? Colors.black,
            ),
            underline: Container(),
            onChanged: (v) {
              if (v != null) {
                ref.read(selectedAnalyticsPeriodProvider.notifier).state = v;
              }
            },
            items: TimePeriod.values.map((v) {
              return DropdownMenuItem(
                value: v,
                child: Text(
                  v.label,
                  style: TextStyle(
                    color: v == selectedPeriod
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: v == selectedPeriod
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Period selector
            _PeriodSelector(selectedDate: selectedDate, period: selectedPeriod),
            const SizedBox(height: 16),

            // Comparison cards
            _ComparisonSection(),
            const SizedBox(height: 20),

            // Financial Insights
            _InsightsSection(),
            const SizedBox(height: 20),

            // Monthly Trend Chart
            _SectionTitle(
              title: '📈 Tendencia (12 meses)',
              icon: Icons.show_chart,
            ),
            const SizedBox(height: 8),
            _MonthlyTrendChart(),
            const SizedBox(height: 20),

            // Top Expenses
            _SectionTitle(
              title: '🏆 Top 5 Gastos del Período',
              icon: Icons.emoji_events,
            ),
            const SizedBox(height: 8),
            _TopExpensesList(),
            const SizedBox(height: 20),

            // Spending by day of week
            _SectionTitle(
              title: '📅 Gastos por Día de Semana',
              icon: Icons.calendar_view_week,
            ),
            const SizedBox(height: 8),
            _DayOfWeekChart(),
            const SizedBox(height: 20),

            // Expenses by account
            _SectionTitle(
              title: '💳 Gastos por Cuenta',
              icon: Icons.account_balance_wallet,
            ),
            const SizedBox(height: 8),
            _AccountBreakdown(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Period Selector ──────────────────────────────────────────────────────────

class _PeriodSelector extends ConsumerWidget {
  final DateTime selectedDate;
  final TimePeriod period;

  const _PeriodSelector({required this.selectedDate, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final newDate = _shift(selectedDate, period, -1);
            ref.read(selectedDateProvider.notifier).state = newDate;
          },
        ),
        Text(
          period.format(selectedDate),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final newDate = _shift(selectedDate, period, 1);
            ref.read(selectedDateProvider.notifier).state = newDate;
          },
        ),
      ],
    );
  }

  DateTime _shift(DateTime date, TimePeriod p, int dir) {
    switch (p) {
      case TimePeriod.day:
        return date.add(Duration(days: dir));
      case TimePeriod.week:
        return date.add(Duration(days: 7 * dir));
      case TimePeriod.month:
        return DateTime(date.year, date.month + dir);
      case TimePeriod.quarter:
        return DateTime(date.year, date.month + 3 * dir);
      case TimePeriod.semester:
        return DateTime(date.year, date.month + 6 * dir);
      case TimePeriod.year:
        return DateTime(date.year + dir, 1);
    }
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─── Comparison Cards ─────────────────────────────────────────────────────────

class _ComparisonSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compAsync = ref.watch(periodComparisonProvider);
    final dailyAsync = ref.watch(dailyAverageExpenseProvider);

    return compAsync.when(
      data: (comp) {
        final expChange = comp['expenseChange'] ?? 0;
        final incChange = comp['incomeChange'] ?? 0;
        final currentExp = comp['currentExpense'] ?? 0;
        final currentInc = comp['currentIncome'] ?? 0;
        final balance = currentInc - currentExp;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Gastos',
                    value: 'S/ ${currentExp.toStringAsFixed(2)}',
                    subtitle: _changeText(expChange),
                    color: Colors.red.shade400,
                    icon: Icons.trending_down,
                    changePositive: expChange < 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'Ingresos',
                    value: 'S/ ${currentInc.toStringAsFixed(2)}',
                    subtitle: _changeText(incChange),
                    color: Colors.green.shade400,
                    icon: Icons.trending_up,
                    changePositive: incChange > 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Balance',
                    value: 'S/ ${balance.toStringAsFixed(2)}',
                    subtitle: balance >= 0 ? 'Superávit' : 'Déficit',
                    color: balance >= 0
                        ? Colors.blue.shade400
                        : Colors.orange.shade400,
                    icon: balance >= 0 ? Icons.savings : Icons.warning_amber,
                    changePositive: balance >= 0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: dailyAsync.when(
                    data: (avg) => _StatCard(
                      label: 'Promedio/día',
                      value: 'S/ ${avg.toStringAsFixed(2)}',
                      subtitle: 'Gasto diario',
                      color: Colors.purple.shade400,
                      icon: Icons.today,
                      changePositive: true,
                    ),
                    loading: () => const _StatCardSkeleton(),
                    error: (_, __) => const SizedBox(),
                  ),
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  String _changeText(double change) {
    if (change == 0) return 'Sin cambio';
    final sign = change > 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)}% vs anterior';
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color color;
  final IconData icon;
  final bool changePositive;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.color,
    required this.icon,
    required this.changePositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ─── Insights ─────────────────────────────────────────────────────────────────

class _InsightsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(financialInsightsProvider);

    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) return const SizedBox();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: '💡 Insights Financieros',
              icon: Icons.lightbulb_outline,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.08),
                    Theme.of(
                      context,
                    ).colorScheme.secondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: insights
                    .map(
                      (insight) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                insight,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(),
    );
  }
}

// ─── Monthly Trend Chart ──────────────────────────────────────────────────────

class _MonthlyTrendChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(monthlyTrendProvider);

    return trendAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return const Center(child: Text('Sin datos'));
        }
        final maxVal = data.fold<double>(
          0,
          (m, e) => [
            m,
            e['expense'] as double,
            e['income'] as double,
          ].reduce((a, b) => a > b ? a : b),
        );

        return SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final month = data[groupIndex]['month'] as DateTime;
                    final label = DateFormat('MMM', 'es').format(month);
                    final val = rod.toY;
                    final type = rodIndex == 0 ? 'Gasto' : 'Ingreso';
                    return BarTooltipItem(
                      '$label\n$type: S/ ${val.toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontSize: 11),
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
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox();
                      }
                      final month = data[idx]['month'] as DateTime;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('MMM', 'es').format(month),
                          style: const TextStyle(fontSize: 9),
                        ),
                      );
                    },
                    reservedSize: 20,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      'S/${value.toInt()}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(data.length, (i) {
                final expense = (data[i]['expense'] as double);
                final income = (data[i]['income'] as double);
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: expense,
                      color: Colors.red.shade400,
                      width: 6,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                    BarChartRodData(
                      toY: income,
                      color: Colors.green.shade400,
                      width: 6,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// ─── Top Expenses ─────────────────────────────────────────────────────────────

class _TopExpensesList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topAsync = ref.watch(topExpensesProvider);

    return topAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No hay gastos en este período',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return Column(
          children: expenses.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            final medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(medals[i], style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (t.productName != null && t.productName!.isNotEmpty)
                              ? t.productName!
                              : (t.description ?? 'Sin descripción'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('dd/MM/yyyy').format(t.date),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'S/ ${t.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.red.shade400,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// ─── Day of Week Chart ────────────────────────────────────────────────────────

class _DayOfWeekChart extends ConsumerWidget {
  static const _dayLabels = {
    1: 'Lun',
    2: 'Mar',
    3: 'Mié',
    4: 'Jue',
    5: 'Vie',
    6: 'Sáb',
    7: 'Dom',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dowAsync = ref.watch(spendingByDayOfWeekProvider);

    return dowAsync.when(
      data: (data) {
        final maxVal = data.values.fold<double>(0, (m, v) => v > m ? v : m);
        if (maxVal == 0) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sin datos suficientes',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return SizedBox(
          height: 150,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final day = group.x + 1;
                    return BarTooltipItem(
                      '${_dayLabels[day]}\nS/ ${rod.toY.toStringAsFixed(0)}',
                      const TextStyle(color: Colors.white, fontSize: 11),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final day = value.toInt() + 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _dayLabels[day] ?? '',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                    reservedSize: 20,
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
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(7, (i) {
                final day = i + 1;
                final val = data[day] ?? 0;
                final isMax = val == maxVal && maxVal > 0;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: val,
                      color: isMax
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.4),
                      width: 28,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// ─── Account Breakdown ────────────────────────────────────────────────────────

class _AccountBreakdown extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byAccountAsync = ref.watch(expensesByAccountProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);

    return byAccountAsync.when(
      data: (byAccount) {
        if (byAccount.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Sin gastos en este período',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return accountsAsync.when(
          data: (accounts) {
            final total = byAccount.values.fold(0.0, (s, v) => s + v);
            final sorted = byAccount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Column(
              children: sorted.map((entry) {
                final account = accounts
                    .where((a) => a.id == entry.key)
                    .firstOrNull;
                final pct = total > 0 ? entry.value / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            account?.name ?? 'Cuenta desconocida',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'S/ ${entry.value.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(pct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}
