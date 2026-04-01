import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/database/drift_database.dart';
import '../../../../presentation/providers/database_providers.dart';
import '../../../../core/theme/app_colors.dart';
import 'widgets/subcategory_pie_chart.dart';

class CategoryDetailsScreen extends ConsumerStatefulWidget {
  final Category category;
  final DateTime startDate;
  final DateTime endDate;

  const CategoryDetailsScreen({
    super.key,
    required this.category,
    required this.startDate,
    required this.endDate,
  });

  @override
  ConsumerState<CategoryDetailsScreen> createState() => _CategoryDetailsScreenState();
}

class _CategoryDetailsScreenState extends ConsumerState<CategoryDetailsScreen> {
  String? _selectedSubcategoryId;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final startDate = widget.startDate;
    final endDate = widget.endDate;
    // 1. Get Transactions
    final transactionsAsync = ref.watch(categoricalTransactionsProvider(
      TransactionFilters(
        startDate: startDate,
        endDate: endDate,
        categoryId: category.id,
        type: category.type,
      ),
    ));

    // 2. Get Subcategory Breakdown
    final subcategoryBreakdownAsync = ref.watch(analyticsSubcategoriesProvider(category.id));
    final allSubcategories = ref.watch(allSubcategoriesStreamProvider).asData?.value ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header & Chart
            Container(
              color: Theme.of(context).cardColor,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                   Hero(
                     tag: 'category_icon_${category.id}',
                     child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Color(int.parse((category.color ?? '#9E9E9E').replaceFirst('#', '0xFF'))).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        category.icon ?? '?',
                        style: const TextStyle(fontSize: 40),
                      ),
                  ),
                   ),
                  const SizedBox(height: 24),
                  
                  // Pie Chart
                  subcategoryBreakdownAsync.when(
                    data: (dataMap) {
                      if (dataMap.isEmpty) return const SizedBox.shrink();
                      final total = dataMap.values.fold(0.0, (sum, val) => sum + val);
                      final baseColor = Color(int.parse((category.color ?? '#9E9E9E').replaceFirst('#', '0xFF')));

                      return Column(
                        children: [
                          Text(
                            'S/ ${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total en ${DateFormat('MMMM', 'es').format(startDate)}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 24),
                          SubcategoryPieChart(
                            dataMap: dataMap,
                            baseColor: baseColor,
                          ),
                          const SizedBox(height: 24),
                          // Chips for filtering
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('Todas'),
                                  selected: _selectedSubcategoryId == null,
                                  onSelected: (val) {
                                    if (val) setState(() => _selectedSubcategoryId = null);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ...dataMap.keys.map((subId) {
                                  final sub = allSubcategories.firstWhere(
                                      (s) => s.id == subId,
                                      orElse: () => Subcategory(
                                          id: subId,
                                          name: 'Desconocido',
                                          categoryId: category.id,
                                          sortOrder: 0,
                                          createdAt: DateTime.now()));
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(sub.name),
                                      selected: _selectedSubcategoryId == subId,
                                      onSelected: (val) {
                                        setState(() => _selectedSubcategoryId = val ? subId : null);
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('Error al cargar gráfico: $e'),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),

            // Transactions List
            transactionsAsync.when(
              data: (transactions) {
                final filteredTransactions = _selectedSubcategoryId == null
                    ? transactions
                    : transactions.where((t) => t.subcategoryId == _selectedSubcategoryId).toList();

                if (filteredTransactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(_selectedSubcategoryId == null
                        ? 'No hay transacciones en este período'
                        : 'No hay transacciones en esta subcategoría'),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredTransactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final t = filteredTransactions[index];
                    return _TransactionTile(transaction: t);
                  },
                );
              },
              loading: () => const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator())
              ),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final Transaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need to fetch the subcategory name if it exists
    final allSubcategories = ref.watch(allSubcategoriesStreamProvider).asData?.value ?? [];
    String? subName;
    if (transaction.subcategoryId != null) {
      final sub = allSubcategories.where((s) => s.id == transaction.subcategoryId).firstOrNull;
      if (sub != null) subName = sub.name;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
           const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (transaction.productName?.isNotEmpty == true)
                      ? transaction.productName!
                      : (transaction.description?.isNotEmpty == true ? transaction.description! : 'Sin descripción'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                Text(
                  [
                    if (transaction.productName?.isNotEmpty == true && transaction.description?.isNotEmpty == true)
                      transaction.description!,
                    if (subName != null) subName,
                  ].join(' • '),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  DateFormat('d MMM yyyy').format(transaction.date),
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '- S/ ${transaction.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
