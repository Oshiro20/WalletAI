import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../providers/database_providers.dart';

/// Balance card glassmorphic con desglose de Activos / Pasivos
class BalanceCard extends ConsumerWidget {
  final double balance;
  final String title;

  const BalanceCard({
    super.key,
    required this.balance,
    this.title = 'Patrimonio Neto',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'S/ ',
      decimalDigits: 2,
    );
    final accountsAsync = ref.watch(accountsStreamProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: AppColors.glassCard(
        color: AppColors.surfaceBright,
        opacity: 0.7,
        borderRadius: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primarySoft,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Eye icon for hide/show balance (future)
              Icon(
                Icons.visibility_outlined,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Balance principal ────────────────────────────────────
          Text(
            currencyFormat.format(balance),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),

          // ── Desglose Activos / Pasivos ───────────────────────────
          accountsAsync.when(
            data: (accounts) {
              double assets = 0;
              double liabilities = 0;

              for (final acc in accounts) {
                if (acc.type == 'credit_card') {
                  liabilities += acc.balance.abs();
                } else {
                  assets += acc.balance;
                }
              }

              final total = assets + liabilities;
              final assetsPercent = total > 0 ? (assets / total) : 0.5;

              return Column(
                children: [
                  // Progress bar visual
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 6,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (assetsPercent * 100).round().clamp(1, 99),
                            child: Container(color: AppColors.income),
                          ),
                          Expanded(
                            flex: ((1 - assetsPercent) * 100).round().clamp(
                              1,
                              99,
                            ),
                            child: Container(
                              color: AppColors.expense.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Labels
                  Row(
                    children: [
                      _BreakdownItem(
                        label: 'Activos',
                        amount: currencyFormat.format(assets),
                        color: AppColors.income,
                        icon: Icons.trending_up_rounded,
                      ),
                      const Spacer(),
                      _BreakdownItem(
                        label: 'Pasivos',
                        amount: currencyFormat.format(liabilities),
                        color: AppColors.expense,
                        icon: Icons.trending_down_rounded,
                        alignEnd: true,
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primarySoft,
                  ),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;
  final bool alignEnd;

  const _BreakdownItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: alignEnd
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              amount,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
