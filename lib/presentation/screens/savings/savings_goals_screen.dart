import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/services/financial_planning_service.dart';
import '../../../core/utils/amount_input_helper.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';
import '../../providers/transaction_repository_provider.dart';

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final accountNames = {for (final a in accounts) a.id: a.name};

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
                  Icon(
                    Icons.flag_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes metas de ahorro',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Define cuánto quieres ahorrar y te sugerimos tu aporte mensual',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
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

          final totalMonthlySuggested =
              FinancialPlanningService.totalSuggestedMonthlySavings(goals);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (totalMonthlySuggested > 0) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C896).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF00C896).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.savings_outlined,
                        color: Color(0xFF00C896),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plan mensual sugerido: S/ ${totalMonthlySuggested.toStringAsFixed(2)}/mes',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Color(0xFF00C896),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Los abonos a cuentas de ahorro se registran como transferencia (no inflan tus gastos ni bajan tu patrimonio).',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              for (final goal in goals)
                _GoalCard(
                  goal: goal,
                  linkedAccountName: goal.accountId != null
                      ? accountNames[goal.accountId]
                      : null,
                  onDelete: () async {
                    final dao = ref.read(savingsGoalsDaoProvider);
                    await dao.deleteGoal(goal.id);
                  },
                  onEdit: () =>
                      _showCreateGoalDialog(context, ref, existing: goal),
                  onAddProgress: () =>
                      _showAddProgressDialog(context, ref, goal),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Error: $e'),
      ),
    );
  }

  void _showCreateGoalDialog(
    BuildContext context,
    WidgetRef ref, {
    SavingsGoal? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateGoalSheet(existing: existing),
    );
  }

  void _showAddProgressDialog(
    BuildContext context,
    WidgetRef ref,
    SavingsGoal goal,
  ) {
    showDialog(
      context: context,
      builder: (_) => _AddProgressDialog(goal: goal),
    );
  }
}

// ─── Goal Card ────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  final SavingsGoal goal;
  final String? linkedAccountName;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onAddProgress;

  const _GoalCard({
    required this.goal,
    this.linkedAccountName,
    required this.onDelete,
    required this.onEdit,
    required this.onAddProgress,
  });

  @override
  Widget build(BuildContext context) {
    final pct = goal.targetAmount > 0
        ? (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final isCompleted = goal.isCompleted || pct >= 1.0;
    final plan = FinancialPlanningService.computeGoalPlan(goal);

    Color goalColor = Colors.blue;
    try {
      if (goal.color != null) {
        goalColor = Color(int.parse(goal.color!.replaceFirst('#', '0xFF')));
      }
    } catch (_) {}

    String? daysText;
    if (goal.deadline != null && !isCompleted) {
      final daysLeft = goal.deadline!.difference(DateTime.now()).inDays;
      if (daysLeft > 0) {
        daysText =
            '$daysLeft días restantes (${DateFormat('dd/MM/yyyy').format(goal.deadline!)})';
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
                  child: Text(
                    goal.icon ?? '🎯',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (linkedAccountName != null)
                        Text(
                          '🏦 Cuenta ahorro: $linkedAccountName',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF00C896),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (daysText != null)
                        Text(
                          daysText,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: daysText.contains('vencida')
                                ? Colors.red
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                          ),
                        ),
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
                      const PopupMenuItem(
                        value: 'add',
                        child: Text('💸 Transferir / Abonar'),
                      ),
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar'),
                      ),
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
                    color: isCompleted ? Colors.green : goalColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCompleted ? Colors.green : goalColor,
                ),
              ),
            ),
            if (!isCompleted && plan.remainingAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Faltan S/ ${plan.remainingAmount.toStringAsFixed(2)} para tu meta',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (!isCompleted &&
                plan.suggestedMonthlyAmount != null &&
                plan.suggestedMonthlyAmount! > 0) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C896).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '🎯 Aporte sugerido: S/ ${plan.suggestedMonthlyAmount!.toStringAsFixed(2)}/mes '
                  '(~S/ ${plan.suggestedWeeklyAmount!.toStringAsFixed(0)}/sem · ${plan.monthsRemaining} mes${plan.monthsRemaining == 1 ? '' : 'es'})',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00C896),
                  ),
                ),
              ),
            ],
            if (!isCompleted)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onAddProgress,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(
                      plan.suggestedMonthlyAmount != null &&
                              plan.suggestedMonthlyAmount! > 0
                          ? 'Transferir cuota (S/ ${plan.suggestedMonthlyAmount!.toStringAsFixed(0)})'
                          : 'Transferir / Abonar ahorro',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 9),
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

// ─── Add Progress Dialog (Transferencia real a cuenta de ahorro o apartado) ───

class _AddProgressDialog extends ConsumerStatefulWidget {
  final SavingsGoal goal;
  const _AddProgressDialog({required this.goal});

  @override
  ConsumerState<_AddProgressDialog> createState() => _AddProgressDialogState();
}

class _AddProgressDialogState extends ConsumerState<_AddProgressDialog> {
  final _ctrl = TextEditingController();
  String? _sourceAccountId;
  String? _destinationAccountId; // null = solo apartar sin mover cuenta
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _destinationAccountId = widget.goal.accountId;
    final plan = FinancialPlanningService.computeGoalPlan(widget.goal);
    if (plan.suggestedMonthlyAmount != null &&
        plan.suggestedMonthlyAmount! > 0) {
      _ctrl.text = plan.suggestedMonthlyAmount!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final plan = FinancialPlanningService.computeGoalPlan(widget.goal);

    return AlertDialog(
      title: Text('Abonar a "${widget.goal.name}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _ctrl,
              onTap: () => clearAmountIfZero(_ctrl),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto a transferir (S/)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              autofocus: true,
              enabled: !_isSaving,
            ),
            if (plan.suggestedMonthlyAmount != null &&
                plan.suggestedMonthlyAmount! > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: Text(
                      'Cuota mes: S/ ${plan.suggestedMonthlyAmount!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onPressed: () => setState(
                      () => _ctrl.text = plan.suggestedMonthlyAmount!
                          .toStringAsFixed(2),
                    ),
                  ),
                  ActionChip(
                    label: Text(
                      'Cuota sem: S/ ${plan.suggestedWeeklyAmount!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onPressed: () => setState(
                      () => _ctrl.text = plan.suggestedWeeklyAmount!
                          .toStringAsFixed(2),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            accountsAsync.when(
              data: (accounts) {
                final activeAccounts = accounts
                    .where((a) => a.isActive && a.type != 'credit_card')
                    .toList();
                if (activeAccounts.isEmpty) {
                  return const Text(
                    'Se actualizará solo el avance de la meta.',
                    style: TextStyle(fontSize: 12),
                  );
                }

                // Destino por defecto: cuenta vinculada a la meta o cuenta de ahorro existente
                if (_destinationAccountId != null &&
                    !activeAccounts.any((a) => a.id == _destinationAccountId)) {
                  _destinationAccountId = null;
                }
                if (_sourceAccountId == null) {
                  final liquid = activeAccounts
                      .where(
                        (a) =>
                            a.id != _destinationAccountId &&
                            (a.type == 'bank' ||
                                a.type == 'wallet' ||
                                a.type == 'cash'),
                      )
                      .firstOrNull;
                  _sourceAccountId = liquid?.id ?? activeAccounts.first.id;
                }

                final isRealTransfer =
                    _destinationAccountId != null &&
                    _sourceAccountId != null &&
                    _destinationAccountId != _sourceAccountId;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String?>(
                      initialValue: _destinationAccountId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cuenta destino (Ahorro)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.savings_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            'Solo apartar (sin mover saldos)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ...activeAccounts.map(
                          (a) => DropdownMenuItem<String?>(
                            value: a.id,
                            child: Text(
                              '${a.name} (S/ ${a.balance.toStringAsFixed(2)})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: _isSaving
                          ? null
                          : (v) => setState(() => _destinationAccountId = v),
                    ),
                    if (_destinationAccountId != null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _sourceAccountId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Transferir desde (Origen)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.account_balance_wallet),
                        ),
                        items: activeAccounts
                            .map(
                              (a) => DropdownMenuItem(
                                value: a.id,
                                child: Text(
                                  '${a.name} (S/ ${a.balance.toStringAsFixed(2)})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (v) {
                                if (v != null) {
                                  setState(() => _sourceAccountId = v);
                                }
                              },
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      isRealTransfer
                          ? '✅ Se registrará como transferencia hacia tu cuenta de ahorro (no cuenta como gasto y protege tu patrimonio).'
                          : _destinationAccountId == null
                          ? 'ℹ️ Solo suma al progreso de la meta sin descontar ni crear un gasto falso.'
                          : '⚠️ Elige una cuenta de origen distinta a la cuenta destino para transferir.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isRealTransfer
                            ? const Color(0xFF00C896)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error al cargar cuentas: $e'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _destinationAccountId != null ? 'Transferir' : 'Abonar',
                ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    if (_destinationAccountId != null &&
        _sourceAccountId == _destinationAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La cuenta de origen y destino deben ser distintas (o elige "Solo apartar").',
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final dao = ref.read(savingsGoalsDaoProvider);

      // Si hay cuenta destino + origen distintas: TRANSFERENCIA REAL (nunca gasto falso)
      if (_destinationAccountId != null && _sourceAccountId != null) {
        final transactionId = const Uuid().v4();
        final transactionCompanion = TransactionsCompanion.insert(
          id: transactionId,
          type: 'transfer',
          amount: amount,
          accountId: _sourceAccountId!,
          destinationAccountId: drift.Value(_destinationAccountId),
          productName: drift.Value('Ahorro: ${widget.goal.name}'),
          description: drift.Value(
            'Transferencia a meta de ahorro: ${widget.goal.name}',
          ),
          date: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await repo.addTransaction(
          transaction: transactionCompanion,
          accountId: _sourceAccountId!,
          amount: amount,
          type: 'transfer',
          destinationAccountId: _destinationAccountId,
        );
      }

      final newAmount = widget.goal.currentAmount + amount;
      await dao.updateGoalProgress(widget.goal.id, newAmount);
      if (newAmount >= widget.goal.targetAmount) {
        await dao.completeGoal(widget.goal.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _destinationAccountId != null
                ? '✅ S/ ${amount.toStringAsFixed(2)} transferidos a "${widget.goal.name}"'
                : '✅ S/ ${amount.toStringAsFixed(2)} apartados en "${widget.goal.name}"',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abonar a la meta: $e')),
        );
      }
    }
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
  String? _linkedAccountId;

  static const _icons = [
    '🎯',
    '🏠',
    '✈️',
    '🚗',
    '💻',
    '📱',
    '👶',
    '🎓',
    '💍',
    '🏖️',
    '🏋️',
    '🎸',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _nameCtrl.text = widget.existing!.name;
      _targetCtrl.text = widget.existing!.targetAmount.toStringAsFixed(2);
      _icon = widget.existing!.icon ?? '🎯';
      _deadline = widget.existing!.deadline;
      _linkedAccountId = widget.existing!.accountId;
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
    final accounts = ref.watch(accountsStreamProvider).valueOrNull ?? const [];
    final activeAccounts = accounts
        .where((a) => a.isActive && a.type != 'credit_card')
        .toList();

    final parsedTarget =
        double.tryParse(_targetCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final previewPlan = (parsedTarget > 0 && _deadline != null)
        ? FinancialPlanningService.computeGoalPlan(
            SavingsGoal(
              id: 'preview',
              name: _nameCtrl.text,
              targetAmount: parsedTarget,
              currentAmount: widget.existing?.currentAmount ?? 0,
              deadline: _deadline,
              isCompleted: false,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          )
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEdit ? 'Editar Meta' : 'Nueva Meta de Ahorro',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            const Text('Ícono', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _icons
                  .map(
                    (ic) => GestureDetector(
                      onTap: () => setState(() => _icon = ic),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _icon == ic
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2)
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: _icon == ic
                              ? Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Text(ic, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre de la meta',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _targetCtrl,
              onTap: () => clearAmountIfZero(_targetCtrl),
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Meta (S/)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 14),

            if (activeAccounts.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue: activeAccounts.any(
                  (a) => a.id == _linkedAccountId,
                )
                    ? _linkedAccountId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Cuenta destino de ahorro (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.savings_outlined),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sin cuenta vinculada'),
                  ),
                  ...activeAccounts.map(
                    (a) => DropdownMenuItem<String?>(
                      value: a.id,
                      child: Text(
                        '${a.name} (${a.type == 'savings' ? 'Ahorro' : a.type})',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _linkedAccountId = v),
              ),
              const SizedBox(height: 10),
            ],

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(
                _deadline != null
                    ? 'Fecha límite: ${DateFormat('dd/MM/yyyy').format(_deadline!)}'
                    : 'Fecha límite (para calcular cuota mensual)',
              ),
              trailing: _deadline != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _deadline = null),
                    )
                  : null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      _deadline ?? DateTime.now().add(const Duration(days: 90)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),

            if (previewPlan?.suggestedMonthlyAmount != null &&
                previewPlan!.suggestedMonthlyAmount! > 0) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C896).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '🎯 Para lograrlo en ${previewPlan.monthsRemaining} mes(es), separa aprox. '
                  'S/ ${previewPlan.suggestedMonthlyAmount!.toStringAsFixed(2)}/mes '
                  '(~S/ ${previewPlan.suggestedWeeklyAmount!.toStringAsFixed(0)}/sem).',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00C896),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isEdit ? 'Guardar Cambios' : 'Crear Meta',
                  style: const TextStyle(fontSize: 16),
                ),
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
        const SnackBar(content: Text('Completa nombre y monto válido')),
      );
      return;
    }

    final dao = ref.read(savingsGoalsDaoProvider);
    final now = DateTime.now();

    if (widget.existing != null) {
      await dao.updateGoal(
        widget.existing!.copyWith(
          name: name,
          targetAmount: target,
          icon: drift.Value(_icon),
          deadline: drift.Value(_deadline),
          accountId: drift.Value(_linkedAccountId),
          updatedAt: now,
        ),
      );
    } else {
      await dao.createGoal(
        SavingsGoalsCompanion.insert(
          id: const Uuid().v4(),
          name: name,
          targetAmount: target,
          icon: drift.Value(_icon),
          deadline: drift.Value(_deadline),
          accountId: drift.Value(_linkedAccountId),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }
}
