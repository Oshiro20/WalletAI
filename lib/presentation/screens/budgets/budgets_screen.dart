import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateBudgetDialog(context, ref),
          ),
        ],
      ),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.savings_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('No tienes presupuestos configurados',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Toca + para crear uno',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateBudgetDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear Presupuesto'),
                  ),
                ],
              ),
            );
          }
          return categoriesAsync.when(
            data: (categories) => ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: budgets.length,
              itemBuilder: (context, i) {
                return _BudgetCard(
                  budget: budgets[i],
                  categories: categories,
                  onDelete: () async {
                    final dao = ref.read(budgetsDaoProvider);
                    await dao.deleteBudget(budgets[i].id);
                  },
                  onEdit: () => _showCreateBudgetDialog(context, ref, existing: budgets[i]),
                );
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }

  void _showCreateBudgetDialog(BuildContext context, WidgetRef ref, {Budget? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateBudgetSheet(existing: existing),
    );
  }
}

// ─── Budget Card ──────────────────────────────────────────────────────────────

class _BudgetCard extends ConsumerWidget {
  final Budget budget;
  final List<Category> categories;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _BudgetCard({
    required this.budget,
    required this.categories,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = categories.where((c) => c.id == budget.categoryId).firstOrNull;
    final spentAsync = ref.watch(budgetSpentProvider(budget.categoryId));

    Color categoryColor = Colors.blue;
    try {
      if (category?.color != null) {
        categoryColor = Color(int.parse(category!.color!.replaceFirst('#', '0xFF')));
      }
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(category?.icon ?? '💰', style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category?.name ?? 'Categoría',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        _periodLabel(budget.period),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            spentAsync.when(
              data: (spent) {
                final pct = (spent / budget.amount).clamp(0.0, 1.0);
                final isOver = spent > budget.amount;
                final barColor = isOver
                    ? Colors.red
                    : pct >= 0.8
                        ? Colors.orange
                        : categoryColor;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'S/ ${spent.toStringAsFixed(2)} / S/ ${budget.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isOver ? Colors.red : null),
                        ),
                        Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: barColor,
                              fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    if (isOver)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '⚠️ Superaste el límite por S/ ${(spent - budget.amount).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      )
                    else if (pct >= 0.8)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          '⚡ Cerca del límite — te quedan S/ ${(budget.amount - spent).toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'monthly': return 'Mensual';
      case 'weekly': return 'Semanal';
      case 'yearly': return 'Anual';
      default: return period;
    }
  }
}

// ─── Create Budget Sheet ──────────────────────────────────────────────────────

class _CreateBudgetSheet extends ConsumerStatefulWidget {
  final Budget? existing;
  const _CreateBudgetSheet({this.existing});

  @override
  ConsumerState<_CreateBudgetSheet> createState() => _CreateBudgetSheetState();
}

class _CreateBudgetSheetState extends ConsumerState<_CreateBudgetSheet> {
  final _amountCtrl = TextEditingController();
  String _period = 'monthly';
  String? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _amountCtrl.text = widget.existing!.amount.toStringAsFixed(2);
      _period = widget.existing!.period;
      _selectedCategoryId = widget.existing!.categoryId;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesStreamProvider);
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEdit ? 'Editar Presupuesto' : 'Nuevo Presupuesto',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Category selector
          categoriesAsync.when(
            data: (cats) => DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: cats.map((c) => DropdownMenuItem(
                value: c.id,
                child: Row(children: [
                  Text(c.icon ?? '📦'),
                  const SizedBox(width: 8),
                  Text(c.name),
                ]),
              )).toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(height: 16),

          // Amount
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Límite (S/)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 16),

          // Period
          DropdownButtonFormField<String>(
            initialValue: _period,
            decoration: const InputDecoration(
              labelText: 'Período',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month),
            ),
            items: const [
              DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
              DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
              DropdownMenuItem(value: 'yearly', child: Text('Anual')),
            ],
            onChanged: (v) => setState(() => _period = v ?? 'monthly'),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(isEdit ? 'Guardar Cambios' : 'Crear Presupuesto',
                  style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0 || _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    final dao = ref.read(budgetsDaoProvider);
    final now = DateTime.now();

    if (widget.existing != null) {
      await dao.updateBudget(widget.existing!.copyWith(
        amount: amount,
        period: _period,
        categoryId: _selectedCategoryId!,
      ));
    } else {
      await dao.createBudget(BudgetsCompanion.insert(
        id: const Uuid().v4(),
        categoryId: _selectedCategoryId!,
        amount: amount,
        period: _period,
        startDate: DateTime(now.year, now.month, 1),
        createdAt: now,
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final budgetsStreamProvider = StreamProvider<List<Budget>>((ref) {
  final dao = ref.watch(budgetsDaoProvider);
  return dao.watchActiveBudgets();
});

final budgetSpentProvider = FutureProvider.autoDispose.family<double, String>((ref, categoryId) async {
  final dao = ref.watch(transactionsDaoProvider);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final map = await dao.getExpensesByCategory(start, end);
  return map[categoryId] ?? 0.0;
});
