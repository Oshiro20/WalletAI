import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/debt_payoff_provider.dart';
import '../../providers/net_worth_provider.dart';
import '../../../domain/entities/debt_payoff_entity.dart';

class DebtPayoffScreen extends ConsumerStatefulWidget {
  const DebtPayoffScreen({super.key});

  @override
  ConsumerState<DebtPayoffScreen> createState() => _DebtPayoffScreenState();
}

class _DebtPayoffScreenState extends ConsumerState<DebtPayoffScreen> {
  DebtStrategy _selectedStrategy = DebtStrategy.avalanche;

  @override
  Widget build(BuildContext context) {
    final netWorthAsync = ref.watch(netWorthProvider);
    final debtAsync = ref.watch(debtPayoffProvider(_selectedStrategy));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Plan de Liquidación',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/net-worth'),
            icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
            label: Text(
              'Patrimonio',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: netWorthAsync.when(
        data: (netWorth) {
          final creditCards = netWorth.liabilityAccounts;
          if (creditCards.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.credit_card_off_outlined,
                    size: 64,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes deudas de tarjetas de crédito',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¡Excelente! No necesitas un plan de liquidación',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return debtAsync.when(
            data: (debtPayoff) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DebtSummary(debtPayoff: debtPayoff),
                  const SizedBox(height: 24),
                  _StrategySelector(
                    selectedStrategy: _selectedStrategy,
                    onStrategyChanged: (strategy) =>
                        setState(() => _selectedStrategy = strategy),
                    debtPayoff: debtPayoff,
                  ),
                  const SizedBox(height: 24),
                  _DebtRanking(debtPayoff: debtPayoff),
                  const SizedBox(height: 24),
                  _DebtFreeProjection(debtPayoff: debtPayoff),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DebtSummary extends StatelessWidget {
  final DebtPayoffEntity debtPayoff;
  const _DebtSummary({required this.debtPayoff});

  @override
  Widget build(BuildContext context) {
    final totalDebt = debtPayoff.totalDebt;
    final totalLimit = debtPayoff.debts.fold<double>(
      0,
      (s, c) => s + (c.creditLimit ?? 0.0),
    );
    final totalUsed = totalLimit > 0 ? (totalDebt / totalLimit * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.expense.withValues(alpha: 0.1),
            AppColors.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.expense.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.expense,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Deuda Total',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'S/ ${totalDebt.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.expense,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SummaryStat(
                label: 'Tarjetas',
                value: '${debtPayoff.debts.length}',
                color: AppColors.primarySoft,
              ),
              const SizedBox(width: 16),
              _SummaryStat(
                label: 'Límite total',
                value: 'S/ ${totalLimit.toStringAsFixed(0)}',
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              _SummaryStat(
                label: 'Usado',
                value: '${totalUsed.toStringAsFixed(0)}%',
                color: totalUsed > 80 ? AppColors.expense : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StrategySelector extends StatelessWidget {
  final DebtStrategy selectedStrategy;
  final ValueChanged<DebtStrategy> onStrategyChanged;
  final DebtPayoffEntity debtPayoff;

  const _StrategySelector({
    required this.selectedStrategy,
    required this.onStrategyChanged,
    required this.debtPayoff,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.tonalCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.psychology_rounded,
                color: AppColors.primarySoft,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Estrategia de Pago',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StrategyCard(
                  label: 'Avalancha',
                  description: 'Paga primero la de mayor TEA',
                  isSelected: selectedStrategy == DebtStrategy.avalanche,
                  onTap: () => onStrategyChanged(DebtStrategy.avalanche),
                  icon: Icons.trending_down_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StrategyCard(
                  label: 'Bola de Nieve',
                  description: 'Paga primero la de menor saldo',
                  isSelected: selectedStrategy == DebtStrategy.snowball,
                  onTap: () => onStrategyChanged(DebtStrategy.snowball),
                  icon: Icons.ac_unit_rounded,
                ),
              ),
            ],
          ),
          if (debtPayoff.savingsVsOtherStrategy > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.income.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.savings_rounded,
                    color: AppColors.income,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ahorro estimado: S/ ${debtPayoff.savingsVsOtherStrategy.toStringAsFixed(0)} vs la otra estrategia',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.income,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StrategyCard extends StatelessWidget {
  final String label;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData icon;

  const _StrategyCard({
    required this.label,
    required this.description,
    required this.isSelected,
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.outlineVariant.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.primarySoft
                      : AppColors.onSurfaceVariant,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected
                        ? AppColors.primarySoft
                        : AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: GoogleFonts.manrope(
                fontSize: 10,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtRanking extends StatelessWidget {
  final DebtPayoffEntity debtPayoff;
  const _DebtRanking({required this.debtPayoff});

  @override
  Widget build(BuildContext context) {
    final sorted = debtPayoff.orderedDebts;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppColors.tonalCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_numbered_rounded,
                color: AppColors.primarySoft,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Ranking de Deudas',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final debt = entry.value;
            final limit = debt.creditLimit ?? 0.0;
            final usedPercent = limit > 0 ? (debt.balance / limit * 100) : 0.0;
            final medals = ['🥇', '🥈', '🥉'];

            return Container(
              margin: EdgeInsets.only(bottom: i < sorted.length - 1 ? 12 : 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        i < 3 ? medals[i] : '${i + 1}',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              debt.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
                              'TEA: ${(debt.annualInterestRate * 100).toStringAsFixed(0)}% | Pago mín: S/ ${debt.minimumPayment.toStringAsFixed(0)}',
                              style: GoogleFonts.manrope(
                                fontSize: 11,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '- S/ ${debt.balance.toStringAsFixed(2)}',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
                  ),
                  if (limit > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: usedPercent / 100,
                              minHeight: 6,
                              backgroundColor: AppColors.surfaceContainer,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                usedPercent > 80
                                    ? AppColors.expense
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${usedPercent.toStringAsFixed(0)}%',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DebtFreeProjection extends StatelessWidget {
  final DebtPayoffEntity debtPayoff;
  const _DebtFreeProjection({required this.debtPayoff});

  @override
  Widget build(BuildContext context) {
    final monthsToPayoff = debtPayoff.estimatedMonthsToPayoff;
    final debtFreeDate = debtPayoff.estimatedDebtFreeDate;
    final totalInterest = debtPayoff.estimatedTotalInterest;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.income.withValues(alpha: 0.1),
            AppColors.surfaceContainerHighest,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.income.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: AppColors.income,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Proyección Libre de Deuda',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            () {
              final raw = DateFormat('MMMM yyyy', 'es').format(debtFreeDate);
              return raw[0].toUpperCase() + raw.substring(1);
            }(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.income,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'En aproximadamente $monthsToPayoff meses',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ProjectionStat(
                label: 'Intereses est.',
                value: 'S/ ${totalInterest.toStringAsFixed(0)}',
              ),
              const SizedBox(width: 16),
              _ProjectionStat(
                label: 'Costo total',
                value: 'S/ ${debtPayoff.totalCost.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectionStat extends StatelessWidget {
  final String label;
  final String value;
  const _ProjectionStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
      ],
    );
  }
}
