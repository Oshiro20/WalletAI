import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/database/drift_database.dart';
import '../../../../presentation/providers/database_providers.dart';
import '../category_details_screen.dart';

class CategoryBreakdownList extends ConsumerWidget {
  final Map<String, double> dataMap;
  final bool isExpense;

  const CategoryBreakdownList({
    super.key,
    required this.dataMap,
    required this.isExpense,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Calcular total para porcentajes
    final total = dataMap.values.fold(0.0, (sum, val) => sum + val);
    
    // Obtener categorías correspondientes
    final categoriesAsync = isExpense 
        ? ref.watch(expenseCategoriesStreamProvider)
        : ref.watch(incomeCategoriesStreamProvider);

    return categoriesAsync.when(
      data: (categories) {
        // Ordenar datos de mayor a menor
        final sortedKeys = dataMap.keys.toList()
          ..sort((a, b) => dataMap[b]!.compareTo(dataMap[a]!));

        if (sortedKeys.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No hay datos para este período'),
                ),
            );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedKeys.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final categoryId = sortedKeys[index];
            final amount = dataMap[categoryId]!;
            final percentage = total == 0 ? 0.0 : (amount / total);
            
            final category = categories.firstWhere(
              (c) => c.id == categoryId,
              orElse: () => Category(
                id: 'unknown',
                name: 'Desconocido',
                type: isExpense ? 'expense' : 'income', 
                icon: 'question_mark',
                color: '#9E9E9E',
                isSystem: true,
                sortOrder: 0,
                createdAt: DateTime.now()
              ),
            );

            // Parsear color
            Color categoryColor;
            try {
              final colorCode = category.color ?? '#9E9E9E';
               categoryColor = Color(int.parse(colorCode.replaceFirst('#', '0xFF')));
            } catch (_) {
              categoryColor = Colors.grey;
            }

            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  category.icon ?? '?',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                    Text(category.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text('S/ ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const SizedBox(height: 4),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
                            minHeight: 6,
                        ),
                    ),
                    const SizedBox(height: 2),
                    Text('${(percentage * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                ],
              ),
              onTap: () {
                final selectedDate = ref.read(selectedDateProvider);
                final startDate = DateTime(selectedDate.year, selectedDate.month, 1);
                final endDate = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryDetailsScreen(
                      category: category,
                      startDate: startDate,
                      endDate: endDate,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox(),
    );
  }


}
