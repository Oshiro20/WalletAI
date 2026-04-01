import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/database_providers.dart';

/// Resumen mensual premium — 3 mini stat cards horizontales con indicadores de tendencia
class MonthSummaryCard extends ConsumerWidget {
  final AsyncValue<double> incomeAsync;
  final AsyncValue<double> expensesAsync;
  final AsyncValue<double> balanceAsync;

  const MonthSummaryCard({
    super.key,
    required this.incomeAsync,
    required this.expensesAsync,
    required this.balanceAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'S/ ',
      decimalDigits: 0,
    );
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy', 'es').format(now);

    final prevIncomeAsync = ref.watch(previousMonthIncomeProvider);
    final prevExpensesAsync = ref.watch(previousMonthExpensesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Resumen de ${monthName[0].toUpperCase()}${monthName.substring(1)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _StatMiniCard(
                label: 'Ingresos',
                valueAsync: incomeAsync,
                trendAsync: prevIncomeAsync,
                format: currencyFormat,
                color: AppColors.income,
                icon: Icons.arrow_downward_rounded,
                trendIsGood: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatMiniCard(
                label: 'Gastos',
                valueAsync: expensesAsync,
                trendAsync: prevExpensesAsync,
                format: currencyFormat,
                color: AppColors.expense,
                icon: Icons.arrow_upward_rounded,
                trendIsGood: false,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatMiniCard(
                label: 'Balance',
                valueAsync: balanceAsync,
                format: currencyFormat,
                color: AppColors.primary,
                icon: Icons.account_balance_rounded,
                isBold: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final AsyncValue<double> valueAsync;
  final AsyncValue<double>? trendAsync;
  final NumberFormat format;
  final Color color;
  final IconData icon;
  final bool isBold;
  final bool trendIsGood;

  const _StatMiniCard({
    required this.label,
    required this.valueAsync,
    this.trendAsync,
    required this.format,
    required this.color,
    required this.icon,
    this.isBold = false,
    this.trendIsGood = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (trendAsync != null) ...[
                const Spacer(),
                trendAsync!.when(
                  data: (prevValue) => valueAsync.when(
                    data: (currValue) {
                      if (prevValue == 0) return const SizedBox.shrink();
                      final change =
                          ((currValue - prevValue) / prevValue * 100);
                      final isPositive = change >= 0;
                      final isGood = trendIsGood ? isPositive : !isPositive;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (isGood ? AppColors.income : AppColors.expense)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              color: isGood
                                  ? AppColors.income
                                  : AppColors.expense,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${change.abs().toStringAsFixed(0)}%',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isGood
                                    ? AppColors.income
                                    : AppColors.expense,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          valueAsync.when(
            data: (value) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                format.format(value),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                  color: isBold ? color : AppColors.onSurface,
                ),
              ),
            ),
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => Text(
              '--',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
