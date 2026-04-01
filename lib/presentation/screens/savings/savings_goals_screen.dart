import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas de Ahorro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateGoalDialog(context, ref),
          ),
        ],
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text('No tienes metas de ahorro',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Define cuánto quieres ahorrar',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateGoalDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva Meta'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: goals.length,
            itemBuilder: (context, i) => _GoalCard(
              goal: goals[i],
              onDelete: () async {
                final dao = ref.read(savingsGoalsDaoProvider);
                await dao.deleteGoal(goals[i].id);
              },
              onEdit: () => _showCreateGoalDialog(context, ref, existing: goals[i]),
              onAddProgress: () => _showAddProgressDialog(context, ref, goals[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }

  void _showCreateGoalDialog(BuildContext context, WidgetRef ref, {SavingsGoal? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CreateGoalSheet(existing: existing),
    );
  }

  void _showAddProgressDialog(BuildContext context, WidgetRef ref, SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (_) => _AddProgressDialog(goal: goal),
    );
  }
}

// ─── Goal Card ────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onAddProgress;

  const _GoalCard({
    required this.goal,
    required this.onDelete,
    required this.onEdit,
    required this.onAddProgress,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final isCompleted = goal.isCompleted || pct >= 1.0;
    final remaining = goal.targetAmount - goal.currentAmount;

    Color goalColor = Colors.blue;
    try {
      if (goal.color != null) {
        goalColor = Color(int.parse(goal.color!.replaceFirst('#', '0xFF')));
      }
    } catch (_) {}

    // Days remaining
    String? daysText;
    if (goal.deadline != null && !isCompleted) {
      final daysLeft = goal.deadline!.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        daysText = '$daysLeft días restantes';
      } else {
        daysText = '⚠️ Fecha límite vencida';
      }
    }

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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: goalColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(goal.icon ?? '🎯', style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(goal.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (daysText != null)
                        Text(daysText,
                            style: TextStyle(
                                fontSize: 12,
                                color: daysText.contains('vencida')
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (isCompleted)
                  const Chip(
                    label: Text('✅ Completada', style: TextStyle(fontSize: 11)),
                    backgroundColor: Color(0xFFE8F5E9),
                  )
                else
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'add') onAddProgress();
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'add', child: Text('➕ Agregar ahorro')),
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'S/ ${goal.currentAmount.toStringAsFixed(2)} / S/ ${goal.targetAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCompleted ? Colors.green : goalColor),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? Colors.green : goalColor),
              ),
            ),
            if (!isCompleted && remaining > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Faltan S/ ${remaining.toStringAsFixed(2)} para tu meta',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            if (!isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onAddProgress,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Agregar ahorro'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Add Progress Dialog ──────────────────────────────────────────────────────

class _AddProgressDialog extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  const _AddProgressDialog({required this.goal});

  @override
  ConsumerState<_AddProgressDialog> createState() => _AddProgressDialogState();
}

class _AddProgressDialogState extends ConsumerState<_AddProgressDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Agregar a "${widget.goal.name}"'),
      content: TextField(
        controller: _ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Monto a agregar (S/)',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.attach_money),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(_ctrl.text.replaceAll(',', '.'));
            if (amount == null || amount <= 0) return;

            final dao = ref.read(savingsGoalsDaoProvider);
            final newAmount = widget.goal.currentAmount + amount;
            await dao.updateGoalProgress(widget.goal.id, newAmount);

            if (newAmount >= widget.goal.targetAmount) {
              await dao.completeGoal(widget.goal.id);
            }

            if (!context.mounted) return;
            Navigator.of(context).pop();
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// ─── Create Goal Sheet ────────────────────────────────────────────────────────

class _CreateGoalSheet extends ConsumerStatefulWidget {
  final SavingsGoal? existing;
  const _CreateGoalSheet({this.existing});

  @override
  ConsumerState<_CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends ConsumerState<_CreateGoalSheet> {
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  String _icon = '🎯';
  DateTime? _deadline;

  static const _icons = ['🎯', '🏠', '✈️', '🚗', '💻', '📱', '👶', '🎓', '💍', '🏖️', '🏋️', '🎸'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _targetCtrl.text = widget.existing!.targetAmount.toStringAsFixed(2);
      _icon = widget.existing!.icon ?? '🎯';
      _deadline = widget.existing!.deadline;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Editar Meta' : 'Nueva Meta de Ahorro',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Icon picker
            const Text('Ícono', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _icons.map((ic) => GestureDetector(
                onTap: () => setState(() => _icon = ic),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _icon == ic
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: _icon == ic
                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Text(ic, style: const TextStyle(fontSize: 22)),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la meta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
            ),
            const SizedBox(height: 16),

            // Target amount
            TextFormField(
              controller: _targetCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Meta (S/)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 16),

            // Deadline
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(_deadline != null
                  ? 'Fecha límite: ${DateFormat('dd/MM/yyyy').format(_deadline!)}'
                  : 'Sin fecha límite (opcional)'),
              trailing: _deadline != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text(isEdit ? 'Guardar Cambios' : 'Crear Meta',
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final target = double.tryParse(_targetCtrl.text.replaceAll(',', '.'));

    if (name.isEmpty || target == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos')),
      );
      return;
    }

    final dao = ref.read(savingsGoalsDaoProvider);
    final now = DateTime.now();

    if (widget.existing != null) {
      await dao.updateGoal(widget.existing!.copyWith(
        name: name,
        targetAmount: target,
        icon: drift.Value(_icon),
        deadline: drift.Value(_deadline),
        updatedAt: now,
      ));
    } else {
      await dao.createGoal(SavingsGoalsCompanion.insert(
        id: const Uuid().v4(),
        name: name,
        targetAmount: target,
        icon: drift.Value(_icon),
        deadline: drift.Value(_deadline),
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final savingsGoalsStreamProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final dao = ref.watch(savingsGoalsDaoProvider);
  return dao.watchActiveGoals();
});
