import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/financial_planning_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/database_providers.dart';

/// Widget de distribución de presupuesto personalizable (50/30/20, 60/20/20, etc.)
/// Cruza nombres reales de categorías e incluye transferencias reales a Metas de Ahorro.
class BudgetRuleWidget extends ConsumerWidget {
  const BudgetRuleWidget({super.key});

  static const _necessityCategoryNames = [
    'vivienda',
    'alojamiento',
    'alimentación',
    'alimentacion',
    'transporte',
    'salud',
    'servicios',
    'supermercado',
    'mercado',
    'agua',
    'luz',
    'gas',
    'internet',
    'hogar',
    'educación',
    'educacion',
    'trabajo',
    'vehículo',
    'vehiculo',
    'cuidado personal',
    'mascotas',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(currentMonthIncomeProvider);
    final expensesByCatAsync = ref.watch(
      currentMonthExpensesByCategoryProvider,
    );
    final goalSavings =
        ref.watch(currentMonthGoalSavingsProvider).valueOrNull ?? 0.0;
    final categories =
        ref.watch(allCategoriesFutureProvider).valueOrNull ?? const [];
    final preset = ref.watch(budgetRulePresetProvider);

    final catNameById = {for (final c in categories) c.id: c.name};

    return incomeAsync.when(
      data: (income) {
        if (income <= 0) return const SizedBox.shrink();

        return expensesByCatAsync.when(
          data: (categoryExpenses) {
            double necessities = 0;
            double wants = 0;

            for (final entry in categoryExpenses.entries) {
              final catName = (catNameById[entry.key] ?? entry.key)
                  .toLowerCase();
              final amount = entry.value.abs();

              if (_necessityCategoryNames.any(catName.contains)) {
                necessities += amount;
              } else {
                wants += amount;
              }
            }

            final totalExpenses = necessities + wants;
            final leftover = (income - totalExpenses - goalSavings).clamp(
              0.0,
              double.infinity,
            );
            // Ahorro efectivo = transferencias reales a ahorro/metas + remanente del mes
            final savings = goalSavings + leftover;

            return _RuleCard(
              income: income,
              necessities: necessities,
              wants: wants,
              savings: savings,
              transferredSavings: goalSavings,
              preset: preset,
              onSelectPreset: (next) =>
                  ref.read(budgetRulePresetProvider.notifier).setPreset(next),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final double income;
  final double necessities;
  final double wants;
  final double savings;
  final double transferredSavings;
  final BudgetRulePreset preset;
  final ValueChanged<BudgetRulePreset> onSelectPreset;

  const _RuleCard({
    required this.income,
    required this.necessities,
    required this.wants,
    required this.savings,
    required this.transferredSavings,
    required this.preset,
    required this.onSelectPreset,
  });

  @override
  Widget build(BuildContext context) {
    final format = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 0);
    final total = necessities + wants + savings;

    final necessitiesPercent = total > 0 ? (necessities / income * 100) : 0.0;
    final wantsPercent = total > 0 ? (wants / income * 100) : 0.0;
    final savingsPercent = total > 0 ? (savings / income * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.tonalCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: AppColors.primarySoft,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Regla ${preset.label}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              PopupMenuButton<BudgetRulePreset>(
                tooltip: 'Cambiar regla',
                onSelected: onSelectPreset,
                itemBuilder: (_) => BudgetRulePreset.values
                    .map(
                      (p) => PopupMenuItem(
                        value: p,
                        child: Text('${p.label} · ${p.subtitle}'),
                      ),
                    )
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preset.subtitle,
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primarySoft,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: AppColors.primarySoft,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: necessitiesPercent.round().clamp(1, 100),
                    child: Container(color: const Color(0xFF60A5FA)),
                  ),
                  Expanded(
                    flex: wantsPercent.round().clamp(1, 100),
                    child: Container(color: const Color(0xFFFBBF24)),
                  ),
                  Expanded(
                    flex: savingsPercent.round().clamp(1, 100),
                    child: Container(color: AppColors.income),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          _RuleItem(
            label: 'Necesidades',
            ideal: preset.needsPct.toDouble(),
            actual: necessitiesPercent,
            amount: format.format(necessities),
            color: const Color(0xFF60A5FA),
          ),
          const SizedBox(height: 10),
          _RuleItem(
            label: 'Deseos',
            ideal: preset.wantsPct.toDouble(),
            actual: wantsPercent,
            amount: format.format(wants),
            color: const Color(0xFFFBBF24),
          ),
          const SizedBox(height: 10),
          _RuleItem(
            label: transferredSavings > 0
                ? 'Ahorro (${format.format(transferredSavings)} en metas)'
                : 'Ahorro',
            ideal: preset.savingsPct.toDouble(),
            actual: savingsPercent,
            amount: format.format(savings),
            color: AppColors.income,
            isSavings: true,
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String label;
  final double ideal;
  final double actual;
  final String amount;
  final Color color;
  final bool isSavings;

  const _RuleItem({
    required this.label,
    required this.ideal,
    required this.actual,
    required this.amount,
    required this.color,
    this.isSavings = false,
  });

  @override
  Widget build(BuildContext context) {
    final isWarning = isSavings ? actual < ideal : actual > ideal;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '${actual.toStringAsFixed(0)}%',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isWarning ? AppColors.expense : AppColors.onSurface,
          ),
        ),
        Text(
          ' / ${ideal.toStringAsFixed(0)}%',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            amount,
            textAlign: TextAlign.right,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
