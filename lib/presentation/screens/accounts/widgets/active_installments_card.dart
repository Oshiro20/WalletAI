import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../data/database/drift_database.dart';
import '../../../providers/database_providers.dart';

/// Tarjeta que muestra las compras en cuotas activas para una tarjeta de crédito
class ActiveInstallmentsCard extends ConsumerWidget {
  final Account account;

  const ActiveInstallmentsCard({
    super.key,
    required this.account,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (account.type != 'credit_card') return const SizedBox.shrink();

    final installmentsAsync = ref.watch(
      creditInstallmentsByAccountStreamProvider(account.id),
    );

    return installmentsAsync.when(
      data: (installments) {
        final activeList = installments.where((i) => i.status == 'active').toList();
        if (activeList.isEmpty) return const SizedBox.shrink();

        final currencyFmt = NumberFormat.currency(
          locale: 'es_PE',
          symbol: '${account.currency} ',
        );
        final dateFmt = DateFormat('dd/MM/yyyy');
        final theme = Theme.of(context);

        // Suma de las cuotas mensuales comprometidas
        final totalMonthlyFees = activeList.fold<double>(
          0.0,
          (sum, item) => sum + item.monthlyPayment,
        );

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.calendar_month,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Compras en Cuotas Activas',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Compromiso mensual: ${currencyFmt.format(totalMonthlyFees)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${activeList.length}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Lista de compras en cuotas
                ...activeList.map((item) {
                  final progress = item.totalInstallments > 0
                      ? item.paidInstallments / item.totalInstallments
                      : 0.0;
                  final remainingCount = item.totalInstallments - item.paidInstallments;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              currencyFmt.format(item.monthlyPayment),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Cuota ${item.paidInstallments} de ${item.totalInstallments} ($remainingCount restante${remainingCount == 1 ? '' : 's'})',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              item.hasInterest
                                  ? 'TEA: ${item.tea?.toStringAsFixed(1) ?? '0'}%'
                                  : 'Sin intereses',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: item.hasInterest ? Colors.orange.shade800 : Colors.green.shade700,
                                fontWeight: FontWeight.w600,
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
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress >= 1.0 ? Colors.green : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '1ra cuota: ${dateFmt.format(item.firstDueDate)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Row(
                              children: [
                                TextButton.icon(
                                  icon: const Icon(Icons.check_circle_outline, size: 16),
                                  label: const Text('Pagar 1 cuota', style: TextStyle(fontSize: 12)),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () async {
                                    final dao = ref.read(creditInstallmentsDaoProvider);
                                    await dao.incrementPaidInstallments(item.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Cuota pagada para "${item.title}". Restan ${remainingCount - 1} cuotas.',
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
