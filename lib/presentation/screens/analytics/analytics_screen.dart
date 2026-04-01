import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/database_providers.dart';
import '../../../core/utils/period_filter.dart';
import '../../../data/datasources/report_generation_service.dart';
import '../../../data/database/drift_database.dart';
import 'widgets/category_breakdown_list.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final selectedPeriod = ref.watch(selectedAnalyticsPeriodProvider);
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final compAsync = ref.watch(periodComparisonProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Análisis',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exportar PDF',
            onPressed: () async {
              final list = transactionsAsync.valueOrNull ?? [];
              final comp = compAsync.valueOrNull;
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
            icon: const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.primarySoft,
            ),
            underline: Container(),
            onChanged: (TimePeriod? newValue) {
              if (newValue != null) {
                ref.read(selectedAnalyticsPeriodProvider.notifier).state =
                    newValue;
              }
            },
            items: TimePeriod.values.map<DropdownMenuItem<TimePeriod>>((
              TimePeriod value,
            ) {
              return DropdownMenuItem<TimePeriod>(
                value: value,
                child: Text(
                  value.label,
                  style: GoogleFonts.manrope(
                    color: value == selectedPeriod
                        ? AppColors.primarySoft
                        : AppColors.onSurface,
                    fontWeight: value == selectedPeriod
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primarySoft,
          labelColor: AppColors.primarySoft,
          unselectedLabelColor: AppColors.onSurfaceVariant,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          unselectedLabelStyle: GoogleFonts.manrope(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(
              text: 'Gastos',
              icon: Icon(Icons.arrow_upward_rounded, size: 16),
            ),
            Tab(
              text: 'Ingresos',
              icon: Icon(Icons.arrow_downward_rounded, size: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _DateSelector(selectedDate: selectedDate, period: selectedPeriod),
          _PeriodSummary(summaryAsync: summaryAsync, compAsync: compAsync),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_ExpenseAnalysisTab(), _IncomeAnalysisTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Date Selector ────────────────────────────────────────────────────────────

class _DateSelector extends ConsumerWidget {
  final DateTime selectedDate;
  final TimePeriod period;

  const _DateSelector({required this.selectedDate, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: AppColors.primarySoft,
            ),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state = _shift(
                selectedDate,
                period,
                -1,
              );
            },
          ),
          Text(
            period.format(selectedDate),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primarySoft,
            ),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state = _shift(
                selectedDate,
                period,
                1,
              );
            },
          ),
        ],
      ),
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

// ─── Period Summary Cards ─────────────────────────────────────────────────────

class _PeriodSummary extends StatelessWidget {
  final AsyncValue<Map<String, double>> summaryAsync;
  final AsyncValue<Map<String, dynamic>> compAsync;

  const _PeriodSummary({required this.summaryAsync, required this.compAsync});

  @override
  Widget build(BuildContext context) {
    return summaryAsync.when(
      data: (summary) {
        final income = summary['income'] ?? 0;
        final expense = summary['expense'] ?? 0;
        final balance = summary['balance'] ?? 0;
        final comp = compAsync.valueOrNull;
        final expChange = comp?['expenseChange'] ?? 0.0;
        final incChange = comp?['incomeChange'] ?? 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.surfaceContainerHighest,
                  AppColors.surfaceContainerHigh,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryStat(
                    label: 'Ingresos',
                    amount: income,
                    color: AppColors.income,
                    icon: Icons.arrow_downward_rounded,
                    change: incChange,
                    changePositive: incChange > 0,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _SummaryStat(
                    label: 'Gastos',
                    amount: expense,
                    color: AppColors.expense,
                    icon: Icons.arrow_upward_rounded,
                    change: expChange,
                    changePositive: expChange < 0,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.outlineVariant.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _SummaryStat(
                    label: 'Balance',
                    amount: balance,
                    color: balance >= 0 ? AppColors.income : AppColors.expense,
                    icon: Icons.account_balance_rounded,
                    isBold: true,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final double? change;
  final bool changePositive;
  final bool isBold;

  const _SummaryStat({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.change,
    this.changePositive = true,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'S/ ${amount.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            fontSize: isBold ? 15 : 13,
          ),
        ),
        if (change != null) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                changePositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: changePositive ? AppColors.income : AppColors.expense,
                size: 10,
              ),
              const SizedBox(width: 2),
              Text(
                '${change!.abs().toStringAsFixed(0)}%',
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: changePositive ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─── Expense Analysis Tab ─────────────────────────────────────────────────────

class _ExpenseAnalysisTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(analyticsExpensesByCategoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Distribución por Categoría',
            icon: Icons.pie_chart_rounded,
          ),
          const SizedBox(height: 12),
          dataAsync.when(
            data: (dataMap) {
              if (dataMap.isEmpty) return const _EmptyData();
              final total = dataMap.values.fold(0.0, (s, v) => s + v);
              return _EnhancedDonutChart(dataMap: dataMap, total: total);
            },
            loading: () => const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),

          _SectionTitle(title: 'Insights IA', icon: Icons.auto_awesome_rounded),
          const SizedBox(height: 12),
          const _InsightsIACard(),
          const SizedBox(height: 24),

          _SectionTitle(
            title: 'Tendencia Mensual',
            icon: Icons.show_chart_rounded,
          ),
          const SizedBox(height: 12),
          const _AreaTrendChart(),
          const SizedBox(height: 24),

          _SectionTitle(
            title: 'Top 5 Gastos',
            icon: Icons.emoji_events_rounded,
          ),
          const SizedBox(height: 12),
          const _TopExpensesList(),
          const SizedBox(height: 24),

          _SectionTitle(
            title: 'Gasto por Día',
            icon: Icons.calendar_view_week_rounded,
          ),
          const SizedBox(height: 12),
          const _DayOfWeekChart(),
          const SizedBox(height: 24),

          _SectionTitle(
            title: 'Gastos por Cuenta',
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 12),
          const _AccountBreakdown(),
          const SizedBox(height: 24),

          _SectionTitle(
            title: 'Detalle por Categoría',
            icon: Icons.list_rounded,
          ),
          const SizedBox(height: 12),
          dataAsync.when(
            data: (dataMap) {
              if (dataMap.isEmpty) return const SizedBox();
              return CategoryBreakdownList(dataMap: dataMap, isExpense: true);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ─── Income Analysis Tab ─────────────────────────────────────────────────────

class _IncomeAnalysisTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(analyticsIncomeByCategoryProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Distribución de Ingresos',
            icon: Icons.pie_chart_rounded,
          ),
          const SizedBox(height: 12),
          dataAsync.when(
            data: (dataMap) {
              if (dataMap.isEmpty) return const _EmptyData();
              final total = dataMap.values.fold(0.0, (s, v) => s + v);
              return _EnhancedDonutChart(dataMap: dataMap, total: total);
            },
            loading: () => const SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            title: 'Detalle por Categoría',
            icon: Icons.list_rounded,
          ),
          const SizedBox(height: 12),
          dataAsync.when(
            data: (dataMap) {
              if (dataMap.isEmpty) return const SizedBox();
              return CategoryBreakdownList(dataMap: dataMap, isExpense: false);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
    );
  }
}

// ─── Enhanced Donut Chart ─────────────────────────────────────────────────────

class _EnhancedDonutChart extends ConsumerStatefulWidget {
  final Map<String, double> dataMap;
  final double total;

  const _EnhancedDonutChart({required this.dataMap, required this.total});

  @override
  ConsumerState<_EnhancedDonutChart> createState() =>
      _EnhancedDonutChartState();
}

class _EnhancedDonutChartState extends ConsumerState<_EnhancedDonutChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) {
        final sortedKeys = widget.dataMap.keys.toList()
          ..sort((a, b) => widget.dataMap[b]!.compareTo(widget.dataMap[a]!));

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppColors.tonalCard(),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                                setState(() {
                                  if (!event.isInterestedForInteractions ||
                                      pieTouchResponse == null ||
                                      pieTouchResponse.touchedSection == null) {
                                    touchedIndex = -1;
                                    return;
                                  }
                                  touchedIndex = pieTouchResponse
                                      .touchedSection!
                                      .touchedSectionIndex;
                                });
                              },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: List.generate(sortedKeys.length, (i) {
                          final isTouched = i == touchedIndex;
                          final categoryId = sortedKeys[i];
                          final value = widget.dataMap[categoryId]!;
                          final category = categories.firstWhere(
                            (c) => c.id == categoryId,
                            orElse: () => Category(
                              id: 'unknown',
                              name: 'Desconocido',
                              type: 'expense',
                              icon: '?',
                              color: '#9E9E9E',
                              isSystem: true,
                              sortOrder: 0,
                              createdAt: DateTime.now(),
                            ),
                          );
                          Color color;
                          try {
                            color = Color(
                              int.parse(
                                (category.color ?? '#9E9E9E').replaceFirst(
                                  '#',
                                  '0xFF',
                                ),
                              ),
                            );
                          } catch (_) {
                            color = Colors.grey;
                          }

                          return PieChartSectionData(
                            color: color,
                            value: value,
                            title: isTouched
                                ? '${(value / widget.total * 100).toStringAsFixed(0)}%'
                                : '',
                            radius: isTouched ? 65 : 55,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            badgeWidget: _DonutBadge(
                              category.icon ?? '?',
                              size: isTouched ? 50 : 40,
                              borderColor: color,
                            ),
                            badgePositionPercentageOffset: .98,
                          );
                        }),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'S/ ${widget.total.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Text(
                          'Total gastos',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: sortedKeys.take(5).map((categoryId) {
                  final category = categories.firstWhere(
                    (c) => c.id == categoryId,
                    orElse: () => Category(
                      id: 'unknown',
                      name: '?',
                      type: 'expense',
                      icon: '?',
                      color: '#9E9E9E',
                      isSystem: true,
                      sortOrder: 0,
                      createdAt: DateTime.now(),
                    ),
                  );
                  Color color;
                  try {
                    color = Color(
                      int.parse(
                        (category.color ?? '#9E9E9E').replaceFirst('#', '0xFF'),
                      ),
                    );
                  } catch (_) {
                    color = Colors.grey;
                  }
                  final pct = (widget.dataMap[categoryId]! / widget.total * 100)
                      .toStringAsFixed(0);

                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${category.name} $pct%',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 250,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(height: 250),
    );
  }
}

class _DonutBadge extends StatelessWidget {
  final String text;
  final double size;
  final Color borderColor;

  const _DonutBadge(this.text, {required this.size, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(
        child: Text(text, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}

// ─── Insights IA Card ─────────────────────────────────────────────────────────

class _InsightsIACard extends ConsumerWidget {
  const _InsightsIACard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(financialInsightsProvider);

    return insightsAsync.when(
      data: (insights) {
        if (insights.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: AppColors.tonalCard(),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primarySoft,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Insights IA',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        'Agrega más transacciones para recibir consejos personalizados',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.08),
                AppColors.surfaceContainerHighest,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.primarySoft,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Powered by WalletAI',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primarySoft,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => context.push('/assistant'),
                    child: Text(
                      'Chat IA →',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primarySoft,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              ...insights.map(
                (insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          insight,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: AppColors.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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

// ─── Area Trend Chart ─────────────────────────────────────────────────────────

class _AreaTrendChart extends ConsumerWidget {
  const _AreaTrendChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendAsync = ref.watch(monthlyTrendProvider);

    return trendAsync.when(
      data: (data) {
        if (data.isEmpty) return const _EmptyData();

        final spots = data.asMap().entries.map((e) {
          return FlSpot(e.key.toDouble(), e.value['expense'] as double);
        }).toList();

        final maxVal = spots.fold<double>(0, (m, s) => m > s.y ? m : s.y);

        return Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: AppColors.tonalCard(),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxVal > 0 ? maxVal / 4 : 100,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, _) => Text(
                      'S/${value.toInt()}',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= data.length) {
                        return const SizedBox();
                      }
                      final month = data[idx]['month'] as DateTime;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('MMM', 'es').format(month),
                          style: GoogleFonts.manrope(
                            fontSize: 9,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  gradient: AppColors.expenseGradient,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.expense.withValues(alpha: 0.3),
                        AppColors.expense.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final month = data[spot.x.toInt()]['month'] as DateTime;
                      return LineTooltipItem(
                        '${DateFormat('MMM', 'es').format(month)}\nS/ ${spot.y.toStringAsFixed(0)}',
                        GoogleFonts.manrope(
                          color: AppColors.onSurface,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(height: 200),
    );
  }
}

// ─── Top Expenses ─────────────────────────────────────────────────────────────

class _TopExpensesList extends ConsumerWidget {
  const _TopExpensesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topAsync = ref.watch(topExpensesProvider);

    return topAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) return const _EmptyData();
        final medals = ['🥇', '🥈', '🥉', '4', '5'];
        return Container(
          decoration: AppColors.tonalCard(),
          child: Column(
            children: expenses.asMap().entries.map((entry) {
              final i = entry.key;
              final t = entry.value;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Text(medals[i], style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (t.productName != null && t.productName!.isNotEmpty)
                                ? t.productName!
                                : (t.description ?? 'Sin descripción'),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(t.date),
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'S/ ${t.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppColors.expense,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
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

  const _DayOfWeekChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dowAsync = ref.watch(spendingByDayOfWeekProvider);

    return dowAsync.when(
      data: (data) {
        final maxVal = data.values.fold<double>(0, (m, v) => v > m ? v : m);
        if (maxVal == 0) return const _EmptyData();

        return Container(
          height: 160,
          padding: const EdgeInsets.all(16),
          decoration: AppColors.tonalCard(),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxVal * 1.2,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) {
                      final day = value.toInt() + 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _dayLabels[day] ?? '',
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
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
              gridData: const FlGridData(show: false),
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
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.3),
                      width: 24,
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
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(height: 160),
    );
  }
}

// ─── Account Breakdown ────────────────────────────────────────────────────────

class _AccountBreakdown extends ConsumerWidget {
  const _AccountBreakdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byAccountAsync = ref.watch(expensesByAccountProvider);
    final accountsAsync = ref.watch(accountsStreamProvider);

    return byAccountAsync.when(
      data: (byAccount) {
        if (byAccount.isEmpty) return const _EmptyData();
        return accountsAsync.when(
          data: (accounts) {
            final total = byAccount.values.fold(0.0, (s, v) => s + v);
            final sorted = byAccount.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: AppColors.tonalCard(),
              child: Column(
                children: sorted.map((entry) {
                  final account = accounts
                      .where((a) => a.id == entry.key)
                      .firstOrNull;
                  final pct = total > 0 ? entry.value / total : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              account?.name ?? 'Cuenta desconocida',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: AppColors.onSurface,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'S/ ${entry.value.toStringAsFixed(2)}',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                                color: AppColors.expense,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(pct * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: AppColors.surfaceContainer,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
    );
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
        Icon(icon, size: 18, color: AppColors.primarySoft),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}

// ─── Empty Data ───────────────────────────────────────────────────────────────

class _EmptyData extends StatelessWidget {
  const _EmptyData();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppColors.tonalCard(),
      child: Center(
        child: Text(
          'No hay datos para este período',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
