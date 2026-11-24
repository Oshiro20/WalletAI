import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/financial_planning_service.dart';
import '../../../providers/database_providers.dart';
import 'budget_summary_widget.dart';

/// Tarjeta compacta de "Cuota diaria segura" en el Inicio:
/// cruza presupuestos activos del mes (o ingresos del mes, incluyendo sueldos
/// de fin de mes asignados a este mes) menos gastos actuales, pagos recurrentes
/// pendientes y la cuota mensual pendiente de tus Metas de Ahorro ("Págate a ti primero").
class SafeDailySpendCard extends ConsumerWidget {
  final AsyncValue<double> monthIncomeAsync;
  final AsyncValue<double> monthExpensesAsync;

  const SafeDailySpendCard({
    super.key,
    required this.monthIncomeAsync,
    required this.monthExpensesAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsStreamProvider);
    final recurringAsync = ref.watch(recurringPaymentsStreamProvider);
    final goalsAsync = ref.watch(savingsGoalsStreamProvider);
    final goalSavingsThisMonth =
        ref.watch(currentMonthGoalSavingsProvider).valueOrNull ?? 0.0;

    final income = monthIncomeAsync.asData?.value ?? 0.0;
    final expenses = monthExpensesAsync.asData?.value ?? 0.0;
    final budgets = budgetsAsync.asData?.value ?? const [];
    final recurring = recurringAsync.asData?.value ?? const [];
    final goals = goalsAsync.asData?.value ?? const [];

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = (daysInMonth - now.day + 1).clamp(1, 31);

    final monthlyBudgetsTotal = budgets
        .where((b) => b.isActive && b.period == 'monthly')
        .fold<double>(0.0, (sum, b) => sum + b.amount);

    final hasBudgetCeiling = monthlyBudgetsTotal > 0;
    final ceiling = hasBudgetCeiling ? monthlyBudgetsTotal : income;
    if (ceiling <= 0) return const SizedBox.shrink();

    final endOfMonth = DateTime(now.year, now.month, daysInMonth, 23, 59, 59);
    final pendingRecurring = recurring
        .where(
          (r) =>
              r.isActive &&
              !r.nextDueDate.isBefore(DateTime(now.year, now.month, now.day)) &&
              !r.nextDueDate.isAfter(endOfMonth),
        )
        .fold<double>(0.0, (sum, r) => sum + r.amount);

    final totalMonthlyGoals =
        FinancialPlanningService.totalSuggestedMonthlySavings(goals, now: now);
    final pendingGoalSavings = (totalMonthlyGoals - goalSavingsThisMonth).clamp(
      0.0,
      double.infinity,
    );

    final remainingRoom =
        ceiling - expenses - pendingRecurring - pendingGoalSavings;
    final safePerDay = remainingRoom > 0 ? remainingRoom / remainingDays : 0.0;
    final isTight = remainingRoom <= 0;

    final fmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final cs = Theme.of(context).colorScheme;
    final accent = isTight ? Colors.orangeAccent : const Color(0xFF00C896);

    final reserveNotes = <String>[
      if (pendingRecurring > 0) '${fmt.format(pendingRecurring)} fijos',
      if (pendingGoalSavings > 0) '${fmt.format(pendingGoalSavings)} metas',
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.go('/assistant'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accent.withValues(alpha: 0.32)),
        ),
        child: Row(
          children: [
            Icon(
              isTight ? Icons.warning_amber_rounded : Icons.shield_outlined,
              color: accent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTight
                        ? 'Presupuesto del mes al límite'
                        : 'Cuota segura hoy: ${fmt.format(safePerDay)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTight
                        ? 'Quedan $remainingDays día(s) · gastos y reservas superan ${hasBudgetCeiling ? 'tus presupuestos' : 'tus ingresos'}'
                        : 'Quedan $remainingDays día(s) · ${fmt.format(remainingRoom)} libres'
                              '${reserveNotes.isNotEmpty ? ' (reservando ${reserveNotes.join(' + ')})' : ''}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: accent.withValues(alpha: 0.8),
            ),
          ],
        ),
      ),
    );
  }
}
