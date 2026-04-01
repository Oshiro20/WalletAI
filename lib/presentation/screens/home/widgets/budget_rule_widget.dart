import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/database_providers.dart';

/// Widget de distribución de gastos 50/30/20
/// Necesidades (50%) / Deseos (30%) / Ahorro (20%)
class BudgetRuleWidget extends ConsumerWidget {
  const BudgetRuleWidget({super.key});

  // Categorías agrupadas por tipo de necesidad
  static const _necessityCategoryNames = [
    'Vivienda', 'Alimentación', 'Transporte', 'Salud', 'Servicios', 'Supermercado',
    'Agua', 'Luz', 'Gas', 'Internet', 'Hogar', 'Educación',
  ];

  static const _wantsCategoryNames = [
    'Entretenimiento', 'Restaurantes', 'Ocio', 'Compras', 'Suscripciones',
    'Ropa', 'Viajes', 'Delivery',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomeAsync = ref.watch(currentMonthIncomeProvider);
    final expensesByCatAsync = ref.watch(currentMonthExpensesByCategoryProvider);

    return incomeAsync.when(
      data: (income) {
        if (income <= 0) return const SizedBox.shrink();

        return expensesByCatAsync.when(
          data: (categoryExpenses) {
            double necessities = 0;
            double wants = 0;
            double savings = 0;

            for (final entry in categoryExpenses.entries) {
              final catName = entry.key;
              final amount = entry.value.abs();

              if (_necessityCategoryNames.any((n) => catName.toLowerCase().contains(n.toLowerCase()))) {
                necessities += amount;
              } else if (_wantsCategoryNames.any((n) => catName.toLowerCase().contains(n.toLowerCase()))) {
                wants += amount;
              } else {
                wants += amount; // Default to wants
              }
            }

            // Lo que queda de ingresos menos gastos = ahorro
            final totalExpenses = necessities + wants;
            savings = (income - totalExpenses).clamp(0, double.infinity);

            return _RuleCard(
              income: income,
              necessities: necessities,
              wants: wants,
              savings: savings,
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

  const _RuleCard({
    required this.income,
    required this.necessities,
    required this.wants,
    required this.savings,
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: AppColors.primarySoft, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'Regla 50/30/20',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
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

          // Items
          _RuleItem(
            label: 'Necesidades',
            ideal: 50,
            actual: necessitiesPercent,
            amount: format.format(necessities),
            color: const Color(0xFF60A5FA),
          ),
          const SizedBox(height: 10),
          _RuleItem(
            label: 'Deseos',
            ideal: 30,
            actual: wantsPercent,
            amount: format.format(wants),
            color: const Color(0xFFFBBF24),
          ),
          const SizedBox(height: 10),
          _RuleItem(
            label: 'Ahorro',
            ideal: 20,
            actual: savingsPercent,
            amount: format.format(savings),
            color: AppColors.income,
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

  const _RuleItem({
    required this.label,
    required this.ideal,
    required this.actual,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isOver = actual > ideal;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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
          ),
        ),
        Text(
          '${actual.toStringAsFixed(0)}%',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isOver ? AppColors.expense : AppColors.onSurface,
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
