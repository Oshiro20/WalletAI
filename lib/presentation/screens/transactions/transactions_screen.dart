import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/database_providers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/empty_state_widget.dart';
import '../../providers/transaction_repository_provider.dart';

import '../../../core/utils/period_filter.dart';

import '../../../l10n/app_localizations.dart';
import '../../widgets/common/tutorial_tooltip.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final GlobalKey _filterKey = GlobalKey();
  String? _expandedTransactionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkTutorial());
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('tutorial_transactions_shown') ?? false;

    if (!shown && mounted) {
      ShowcaseView.get().startShowCase([_filterKey]);
      await prefs.setBool('tutorial_transactions_shown', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(transactionFiltersProvider);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final balanceAsync = ref.watch(filteredBalanceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.transactionsTitle),
        actions: [
          Showcase.withWidget(
            key: _filterKey,
            container: TutorialTooltip(
              title: AppLocalizations.of(context)!.showcaseFiltersTitle,
              description: AppLocalizations.of(context)!.showcaseFiltersDesc,
              nextLabel: 'Entendido',
              onNext: () => ShowcaseView.get().completed(_filterKey),
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {
                _showFilterOptions(context, ref, filters.period);
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Selector de Mes y Filtros Rápidos
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            color: AppColors.surfaceContainerLow,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: () {
                        final currentStart = filters.startDate!;
                        DateTime newDate;

                        switch (filters.period) {
                          case TimePeriod.day:
                            newDate = currentStart.subtract(
                              const Duration(days: 1),
                            );
                            break;
                          case TimePeriod.week:
                            newDate = currentStart.subtract(
                              const Duration(days: 7),
                            );
                            break;
                          case TimePeriod.month:
                            newDate = DateTime(
                              currentStart.year,
                              currentStart.month - 1,
                              1,
                            );
                            break;
                          case TimePeriod.quarter:
                            newDate = DateTime(
                              currentStart.year,
                              currentStart.month - 3,
                              1,
                            );
                            break;
                          case TimePeriod.semester:
                            newDate = DateTime(
                              currentStart.year,
                              currentStart.month - 6,
                              1,
                            );
                            break;
                          case TimePeriod.year:
                            newDate = DateTime(currentStart.year - 1, 1, 1);
                            break;
                        }

                        final range = filters.period.calculateRange(newDate);

                        ref
                            .read(transactionFiltersProvider.notifier)
                            .state = filters.copyWith(
                          startDate: range.start,
                          endDate: range.end,
                        );
                      },
                    ),
                    Text(
                      filters.period.format(filters.startDate!).toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        final currentStart = filters.startDate!;
                        DateTime newDate;

                        switch (filters.period) {
                          case TimePeriod.day:
                            newDate = currentStart.add(const Duration(days: 1));
                            break;
                          case TimePeriod.week:
                            newDate = currentStart.add(const Duration(days: 7));
                            break;
                          case TimePeriod.month:
                            newDate = DateTime(
                              currentStart.year,
                              currentStart.month + 1,
                              1,
                            );
                            break;
                          case TimePeriod.quarter:
                            newDate = DateTime(
                              currentStart.year,
                              currentStart.month + 3,
                              1,
                            );
                            break;
                          case TimePeriod.semester:
                            newDate = DateTime(
                              currentStart.year,
                              currentStart.month + 6,
                              1,
                            );
                            break;
                          case TimePeriod.year:
                            newDate = DateTime(currentStart.year + 1, 1, 1);
                            break;
                        }

                        final range = filters.period.calculateRange(newDate);

                        ref
                            .read(transactionFiltersProvider.notifier)
                            .state = filters.copyWith(
                          startDate: range.start,
                          endDate: range.end,
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: AppLocalizations.of(context)!.filterAll,
                        isSelected: filters.type == null,
                        onSelected: (_) {
                          ref.read(transactionFiltersProvider.notifier).state =
                              filters.copyWith(type: null);
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: AppLocalizations.of(context)!.filterExpense,
                        isSelected: filters.type == 'expense',
                        color: AppColors.expense,
                        onSelected: (_) {
                          ref.read(transactionFiltersProvider.notifier).state =
                              filters.copyWith(type: 'expense');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: AppLocalizations.of(context)!.filterIncome,
                        isSelected: filters.type == 'income',
                        color: AppColors.income,
                        onSelected: (_) {
                          ref.read(transactionFiltersProvider.notifier).state =
                              filters.copyWith(type: 'income');
                        },
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: AppLocalizations.of(context)!.filterTransfer,
                        isSelected: filters.type == 'transfer',
                        color: AppColors.transfer,
                        onSelected: (_) {
                          ref.read(transactionFiltersProvider.notifier).state =
                              filters.copyWith(type: 'transfer');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. Resumen del Periodo con gradientes
          balanceAsync.when(
            data: (data) => Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.surfaceContainerHighest,
                    AppColors.surfaceContainerHigh,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryItem(
                    label: AppLocalizations.of(context)!.income,
                    amount: data['income']!,
                    color: AppColors.income,
                    icon: Icons.arrow_downward_rounded,
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.outlineVariant.withValues(alpha: 0.2),
                  ),
                  _SummaryItem(
                    label: AppLocalizations.of(context)!.expenses,
                    amount: data['expense']!,
                    color: AppColors.expense,
                    icon: Icons.arrow_upward_rounded,
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: AppColors.outlineVariant.withValues(alpha: 0.2),
                  ),
                  _SummaryItem(
                    label: AppLocalizations.of(context)!.total,
                    amount: data['total']!,
                    color: data['total']! >= 0
                        ? AppColors.income
                        : AppColors.expense,
                    icon: Icons.account_balance_rounded,
                    isTotal: true,
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(
              height: 60,
              child: Center(child: LinearProgressIndicator()),
            ),
            error: (_, __) => const SizedBox(),
          ),

          // 3. Lista de Transacciones con Swipe Gestures
          Expanded(
            child: transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return EmptyStateWidget.transactions(
                    onCreate: () => context.push('/transactions/create'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final showDateHeader =
                        index == 0 ||
                        !DateUtils.isSameDay(
                          transactions[index - 1].date,
                          transaction.date,
                        );
                    final isExpanded = _expandedTransactionId == transaction.id;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                            child: Text(
                              DateFormat(
                                'EEEE, d MMMM',
                                'es',
                              ).format(transaction.date),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.primarySoft,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        _SwipeableTransactionTile(
                          transaction: transaction,
                          isExpanded: isExpanded,
                          onToggleExpand: () {
                            setState(() {
                              _expandedTransactionId = isExpanded
                                  ? null
                                  : transaction.id;
                            });
                          },
                          onDelete: () async {
                            try {
                              final repository = ref.read(
                                transactionRepositoryProvider,
                              );
                              await repository.deleteTransaction(
                                transaction.id,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      AppLocalizations.of(
                                        context,
                                      )!.transactionDeleted,
                                    ),
                                    backgroundColor: AppColors.expense,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error al eliminar: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          onDuplicate: () {
                            context.push(
                              Uri(
                                path: '/transactions/create',
                                queryParameters: {'type': transaction.type},
                              ).toString(),
                              extra: {
                                'amount': transaction.amount,
                                'description': transaction.description,
                                'productName': transaction.productName,
                                'categoryId': transaction.categoryId,
                                'subcategoryId': transaction.subcategoryId,
                                'accountId': transaction.accountId,
                              },
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (error, stack) =>
                  ErrorDisplayWidget(message: error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterOptions(
    BuildContext context,
    WidgetRef ref,
    TimePeriod currentPeriod,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  AppLocalizations.of(context)!.selectPeriod,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              ...TimePeriod.values.map((period) {
                return ListTile(
                  title: Text(period.label),
                  selected: period == currentPeriod,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                  trailing: period == currentPeriod
                      ? const Icon(Icons.check, color: AppColors.primarySoft)
                      : null,
                  onTap: () {
                    final now = DateTime.now();
                    final range = period.calculateRange(now);

                    ref
                        .read(transactionFiltersProvider.notifier)
                        .state = TransactionFilters(
                      startDate: range.start,
                      endDate: range.end,
                      period: period,
                    );

                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Swipeable Transaction Tile ──────────────────────────────────────────────

class _SwipeableTransactionTile extends StatelessWidget {
  final dynamic transaction;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _SwipeableTransactionTile({
    required this.transaction,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('tx_${transaction.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onDuplicate();
          return false;
        }
        // Retornamos true para confirmar el swipe de eliminación
        return true;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      background: _SwipeBackground(
        icon: Icons.content_copy_rounded,
        label: 'Duplicar',
        color: AppColors.transfer,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
      ),
      secondaryBackground: _SwipeBackground(
        icon: Icons.delete_outline_rounded,
        label: 'Eliminar',
        color: AppColors.expense,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onToggleExpand,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isExpanded
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.outlineVariant.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getTypeColor(
                          transaction.type,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getTypeIcon(transaction.type),
                        color: _getTypeColor(transaction.type),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final hasProduct = transaction.productName != null && transaction.productName!.toString().trim().isNotEmpty;
                          final hasDescription = transaction.description != null && transaction.description!.toString().trim().isNotEmpty;
                          
                          final mainText = transaction.type == 'transfer'
                              ? AppLocalizations.of(context)!.filterTransfer
                              : (hasProduct ? transaction.productName! : (hasDescription ? transaction.description! : AppLocalizations.of(context)!.noDescription));
                              
                          final subText = transaction.type == 'transfer' 
                              ? null 
                              : (hasProduct && hasDescription ? transaction.description! : null);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mainText,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (subText != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '🏬 $subText',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          );
                        }
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_getCurrencySymbol(transaction.currency)} ${transaction.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.plusJakartaSans(
                            color: _getTypeColor(transaction.type),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          DateFormat('HH:mm').format(transaction.date),
                          style: GoogleFonts.manrope(
                            fontSize: 10,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Panel expandible de detalle
          if (isExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(
                    icon: Icons.category_rounded,
                    label: 'Categoría',
                    value: transaction.categoryId ?? '—',
                  ),
                  if (transaction.accountId != null) ...[
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Cuenta',
                      value: transaction.accountId.toString(),
                    ),
                  ],
                  if (transaction.latitude != null &&
                      transaction.longitude != null) ...[
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.location_on_rounded,
                      label: 'Ubicación',
                      value:
                          transaction.locationName ??
                          '${transaction.latitude}, ${transaction.longitude}',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.map_rounded,
                          size: 32,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/transactions/edit/${transaction.id}',
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 16),
                          label: Text(AppLocalizations.of(context)!.edit),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primarySoft,
                            side: BorderSide(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDuplicate,
                          icon: const Icon(
                            Icons.content_copy_rounded,
                            size: 16,
                          ),
                          label: const Text('Duplicar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.transfer,
                            side: BorderSide(
                              color: AppColors.transfer.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'income':
        return AppColors.income;
      case 'expense':
        return AppColors.expense;
      case 'transfer':
        return AppColors.transfer;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward_rounded;
      case 'expense':
        return Icons.arrow_upward_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _getCurrencySymbol(String? currency) {
    if (currency == null) return 'S/';
    switch (currency) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'PEN':
        return 'S/';
      default:
        return '$currency ';
    }
  }
}

// ─── Swipe Background ────────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Alignment alignment;
  final EdgeInsets padding;

  const _SwipeBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignment,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: alignment,
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Detail Row ──────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Filter Chip ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeColor = color ?? cs.primary;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : cs.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: activeColor,
      backgroundColor: cs.surfaceContainerHigh,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      side: isSelected
          ? BorderSide(color: activeColor, width: 1.5)
          : BorderSide(color: cs.outlineVariant, width: 1),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ─── Summary Item ────────────────────────────────────────────────────────────

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isTotal;

  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 11,
            color: AppColors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'S/ ${amount.toStringAsFixed(2)}',
          style: GoogleFonts.plusJakartaSans(
            color: color,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w700,
            fontSize: isTotal ? 16 : 13,
          ),
        ),
      ],
    );
  }
}
