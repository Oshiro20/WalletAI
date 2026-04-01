import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/database/drift_database.dart';
import '../../../../presentation/providers/database_providers.dart';

class AnalyticsPieChart extends ConsumerStatefulWidget {
  final Map<String, double> dataMap;
  final bool isExpense;

  const AnalyticsPieChart({
    super.key,
    required this.dataMap,
    required this.isExpense,
  });

  @override
  ConsumerState<AnalyticsPieChart> createState() => _AnalyticsPieChartState();
}

class _AnalyticsPieChartState extends ConsumerState<AnalyticsPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.dataMap.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(
            child: Text('No hay datos para mostrar', style: TextStyle(color: Colors.grey))
        ),
      );
    }

    final categoriesAsync = widget.isExpense
        ? ref.watch(expenseCategoriesStreamProvider)
        : ref.watch(incomeCategoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) {
        final total = widget.dataMap.values.fold(0.0, (sum, val) => sum + val);
        
        return SizedBox(
            height: 250,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              touchedIndex = -1;
                              return;
                            }
                            touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _showingSections(widget.dataMap, categories, total),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _Indicators(
                      dataMap: widget.dataMap,
                      categories: categories,
                  ),
                ),
              ],
            ),
        );
      },
      loading: () => const SizedBox(height: 250, child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const SizedBox(height: 250),
    );
  }

  List<PieChartSectionData> _showingSections(
    Map<String, double> data,
    List<Category> categories,
    double total,
  ) {
    final sortedKeys = data.keys.toList()
      ..sort((a, b) => data[b]!.compareTo(data[a]!));

    return List.generate(sortedKeys.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 20.0 : 14.0;
      final radius = isTouched ? 60.0 : 50.0;
      final widgetSize = isTouched ? 55.0 : 40.0;

      final categoryId = sortedKeys[i];
      final value = data[categoryId]!;
      final category = categories.firstWhere(
        (c) => c.id == categoryId,
        orElse: () => Category(
            id: 'unknown',
            name: 'Desconocido',
            type: widget.isExpense ? 'expense' : 'income',
            icon: '?',
            color: '#9E9E9E',
            isSystem: true,
            sortOrder: 0,
            createdAt: DateTime.now()),
      );

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
  const _Badge(
    this.text, {
    required this.size,
    required this.borderColor,
  });
  final String text;
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
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: .5),
            offset: const Offset(3, 3),
            blurRadius: 3,
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}

class _Indicators extends StatelessWidget {
  final Map<String, double> dataMap;
  final List<Category> categories;

  const _Indicators({
    required this.dataMap,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    // Top 5
    final sortedKeys = dataMap.keys.toList()
      ..sort((a, b) => dataMap[b]!.compareTo(dataMap[a]!));
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
                createdAt: DateTime.now()));
        
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
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
