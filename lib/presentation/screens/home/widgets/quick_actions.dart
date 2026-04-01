import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';

/// Quick actions rediseñadas — scroll horizontal premium
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Acciones Rápidas',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: [
              _QuickActionChip(
                icon: Icons.remove_circle_outline_rounded,
                label: 'Gasto',
                color: AppColors.expense,
                onTap: () {
                  context.push(
                    Uri(
                      path: '/transactions/create',
                      queryParameters: {'type': 'expense'},
                    ).toString(),
                  );
                },
              ),
              _QuickActionChip(
                icon: Icons.add_circle_outline_rounded,
                label: 'Ingreso',
                color: AppColors.income,
                onTap: () {
                  context.push(
                    Uri(
                      path: '/transactions/create',
                      queryParameters: {'type': 'income'},
                    ).toString(),
                  );
                },
              ),
              _QuickActionChip(
                icon: Icons.swap_horiz_rounded,
                label: 'Transferir',
                color: AppColors.transfer,
                onTap: () {
                  context.push(
                    Uri(
                      path: '/transactions/create',
                      queryParameters: {'type': 'transfer'},
                    ).toString(),
                  );
                },
              ),
              _QuickActionChip(
                icon: Icons.document_scanner_rounded,
                label: 'Escanear',
                color: AppColors.categoryHome,
                onTap: () => context.push('/scan-receipt'),
              ),
              _QuickActionChip(
                icon: Icons.bar_chart_rounded,
                label: 'Estadísticas',
                color: AppColors.primaryLight,
                onTap: () => context.push('/analytics'),
              ),
              _QuickActionChip(
                icon: Icons.savings_rounded,
                label: 'Presupuesto',
                color: AppColors.warning,
                onTap: () => context.push('/budgets'),
              ),
              _QuickActionChip(
                icon: Icons.account_balance_wallet_rounded,
                label: 'Cuentas',
                color: AppColors.primarySoft,
                onTap: () => context.push('/accounts'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
