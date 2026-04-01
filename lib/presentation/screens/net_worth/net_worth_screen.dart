import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/database_providers.dart';
import '../../providers/net_worth_provider.dart';
import '../../../data/database/drift_database.dart' show SavingsGoal;

class NetWorthScreen extends ConsumerWidget {
  const NetWorthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final netWorthAsync = ref.watch(netWorthProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Patrimonio Neto',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => context.push('/accounts'),
            tooltip: 'Ver cuentas',
          ),
        ],
      ),
      body: netWorthAsync.when(
        data: (netWorth) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NetWorthHeroCard(netWorth: netWorth),
              const SizedBox(height: 24),
              _AssetsLiabilitiesBar(netWorth: netWorth),
              const SizedBox(height: 24),
              _FinancialHealthCard(netWorth: netWorth),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Activos',
                icon: Icons.trending_up_rounded,
                color: AppColors.income,
              ),
              const SizedBox(height: 12),
              if (netWorth.assetAccounts.isEmpty)
                const _EmptySection(label: 'No hay cuentas de activos')
              else
                Column(
                  children: netWorth.assetAccounts
                      .map((acc) => _AccountTile(account: acc))
                      .toList(),
                ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Pasivos',
                icon: Icons.trending_down_rounded,
                color: AppColors.expense,
              ),
              const SizedBox(height: 12),
              if (netWorth.liabilityAccounts.isEmpty)
                const _EmptySection(label: 'No tienes deudas registradas')
              else
                Column(
                  children: netWorth.liabilityAccounts
                      .map((acc) => _CreditCardTile(account: acc))
                      .toList(),
                ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Metas de Ahorro',
                icon: Icons.flag_rounded,
                color: AppColors.warning,
              ),
              const SizedBox(height: 12),
              const _SavingsGoalsSection(),
              const SizedBox(height: 16),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _NetWorthHeroCard extends StatelessWidget {
  final dynamic netWorth;
  const _NetWorthHeroCard({required this.netWorth});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Patrimonio Neto',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'S/ ${netWorth.netWorth.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activos: S/ ${netWorth.totalAssets.toStringAsFixed(0)} | Pasivos: S/ ${netWorth.totalLiabilities.toStringAsFixed(0)}',
            style: GoogleFonts.manrope(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetsLiabilitiesBar extends StatelessWidget {
  final dynamic netWorth;
  const _AssetsLiabilitiesBar({required this.netWorth});

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Distribución',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: netWorth.assetsPercentage.round().clamp(1, 99) as int,
                    child: Container(
                      decoration: const BoxDecoration(color: AppColors.income),
                    ),
                  ),
                  Expanded(
                    flex:
                        (100 - netWorth.assetsPercentage.round()).clamp(1, 99)
                            as int,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.expense.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _DistributionItem(
                label: 'Activos',
                amount: netWorth.totalAssets,
                percent: netWorth.assetsPercentage,
                color: AppColors.income,
              ),
              _DistributionItem(
                label: 'Pasivos',
                amount: netWorth.totalLiabilities,
                percent: netWorth.liabilitiesPercentage,
                color: AppColors.expense,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinancialHealthCard extends StatelessWidget {
  final dynamic netWorth;
  const _FinancialHealthCard({required this.netWorth});

  @override
  Widget build(BuildContext context) {
    final score = netWorth.financialHealthScore;
    final status = netWorth.financialStatus;
    final debtRatio = netWorth.debtToAssetRatio;

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
              const Icon(
                Icons.health_and_safety_rounded,
                color: AppColors.income,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Salud Financiera',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                '$status',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: score >= 60 ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(
                score >= 60 ? AppColors.income : AppColors.expense,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${score.toStringAsFixed(0)}/100',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                'Ratio deuda: ${(debtRatio * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DistributionItem extends StatelessWidget {
  final String label;
  final double amount;
  final double percent;
  final Color color;
  const _DistributionItem({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'S/ ${amount.toStringAsFixed(0)}',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  final dynamic account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final typeIcons = {
      'cash': Icons.payments_rounded,
      'bank': Icons.account_balance_rounded,
      'wallet': Icons.account_balance_wallet_rounded,
      'savings': Icons.savings_rounded,
    };
    final typeLabels = {
      'cash': 'Efectivo',
      'bank': 'Banco',
      'wallet': 'Billetera',
      'savings': 'Ahorros',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              typeIcons[account.type] ?? Icons.account_balance_rounded,
              color: AppColors.income,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.onSurface,
                  ),
                ),
                Text(
                  typeLabels[account.type] ?? account.type,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'S/ ${account.balance.toStringAsFixed(2)}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.income,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCardTile extends StatelessWidget {
  final dynamic account;
  const _CreditCardTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final debt = account.balance;
    final limit = account.creditLimit ?? 0.0;
    final usedPercent = limit > 0 ? (debt / limit * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.expense.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.credit_card_rounded,
                  color: AppColors.expense,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.onSurface,
                      ),
                    ),
                    Text(
                      'Tarjeta de Crédito',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '- S/ ${debt.toStringAsFixed(2)}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
          if (limit > 0) ...[
            const SizedBox(height: 12),
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
            const SizedBox(height: 4),
            Text(
              'Límite: S/ ${limit.toStringAsFixed(2)}',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SavingsGoalsSection extends ConsumerWidget {
  const _SavingsGoalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(_netWorthSavingsGoalsProvider);
    return goalsAsync.when(
      data: (goals) {
        final activeGoals = goals.where((g) => !g.isCompleted).toList();
        if (activeGoals.isEmpty) {
          return const _EmptySection(
            label: 'No tienes metas de ahorro activas',
          );
        }
        return Column(
          children: activeGoals.take(3).map((goal) {
            final progress = goal.targetAmount > 0
                ? (goal.currentAmount / goal.targetAmount)
                : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        progress >= 1.0
                            ? Icons.check_circle_rounded
                            : Icons.flag_rounded,
                        color: progress >= 1.0
                            ? AppColors.income
                            : AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          goal.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainer,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        progress >= 1.0 ? AppColors.income : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'S/ ${goal.currentAmount.toStringAsFixed(0)} / S/ ${goal.targetAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const _CardSkeleton(),
      error: (_, __) => const _EmptySection(label: 'Error al cargar metas'),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
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

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primarySoft,
        ),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String label;
  const _EmptySection({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppColors.tonalCard(),
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

final _netWorthSavingsGoalsProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final dao = ref.watch(savingsGoalsDaoProvider);
  return dao.watchActiveGoals();
});
