import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_providers.dart';
import '../../../../data/database/drift_database.dart';

class ExpensePieChart extends ConsumerStatefulWidget {
  const ExpensePieChart({super.key});

  @override
  ConsumerState<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends ConsumerState<ExpensePieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(currentMonthExpensesByCategoryProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gastos por Categoría',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: expensesAsync.when(
                data: (expensesMap) {
                  if (expensesMap.isEmpty) {
                    return const Center(child: Text('No hay gastos este mes'));
                  }

                  return categoriesAsync.when(
                    data: (categories) {
                      final totalExpense = expensesMap.values.fold(
                        0.0,
                        (sum, val) => sum + val,
                      );

                      return Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: PieChart(
                              PieChartData(
                                pieTouchData: PieTouchData(
                                  touchCallback:
                                      (FlTouchEvent event, pieTouchResponse) {
                                        setState(() {
                                          if (!event
                                                  .isInterestedForInteractions ||
                                              pieTouchResponse == null ||
                                              pieTouchResponse.touchedSection ==
                                                  null) {
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
                                centerSpaceRadius: 40,
                                sections: _showingSections(
                                  expensesMap,
                                  categories,
                                  totalExpense,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: _Indicators(
                              expensesMap: expensesMap,
                              categories: categories,
                              total: totalExpense,
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const SizedBox(),
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

  List<PieChartSectionData> _showingSections(
    Map<String, double> expenses,
    List<Category> categories,
    double total,
  ) {
    // Ordenar gastos de mayor a menor
    final sortedKeys = expenses.keys.toList()
      ..sort((a, b) => expenses[b]!.compareTo(expenses[a]!));

    return List.generate(sortedKeys.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 20.0 : 14.0;
      final radius = isTouched ? 60.0 : 50.0;
      final widgetSize = isTouched ? 55.0 : 40.0;

      final categoryId = sortedKeys[i];
      final value = expenses[categoryId]!;
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

      // Parsear color hexadecimal
      Color color;
      try {
        final colorString = category.color ?? '#9E9E9E';
        color = Color(int.parse(colorString.replaceFirst('#', '0xFF')));
      } catch (e) {
        color = Colors.grey;
      }

      return PieChartSectionData(
        color: color,
        value: value,
        title: '${(value / total * 100).toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: const Color(0xffffffff),
        ),
        badgeWidget: _Badge(
          category.icon ?? '?',
          size: widgetSize,
          borderColor: color,
        ),
        badgePositionPercentageOffset: .98,
      );
    });
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, {required this.size, required this.borderColor});
  final String icon;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            offset: const Offset(3, 3),
            blurRadius: 3,
          ),
        ],
      ),
      padding: EdgeInsets.all(size * .15),
      child: Center(
        child: Text(icon, style: TextStyle(fontSize: size * 0.5)),
      ),
    );
  }
}

class _Indicators extends StatelessWidget {
  final Map<String, double> expensesMap;
  final List<Category> categories;
  final double total;

  const _Indicators({
    required this.expensesMap,
    required this.categories,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    // Tomar solo los top 5 para no saturar
    final sortedKeys = expensesMap.keys.toList()
      ..sort((a, b) => expensesMap[b]!.compareTo(expensesMap[a]!));
    final topKeys = sortedKeys.take(5).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: topKeys.map((categoryId) {
        final category = categories.firstWhere(
          (c) => c.id == categoryId,
          orElse: () => Category(
            id: 'unknown',
            name: '?',
            type: 'expense',
            color: '#9E9E9E',
            isSystem: true,
            sortOrder: 0,
            createdAt: DateTime.now(),
          ),
        );

        Color color;
        try {
          final colorString = category.color ?? '#9E9E9E';
          color = Color(int.parse(colorString.replaceFirst('#', '0xFF')));
        } catch (e) {
          color = Colors.grey;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
