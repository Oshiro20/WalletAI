import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/period_filter.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/database_providers.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../../data/database/drift_database.dart';
import 'package:uuid/uuid.dart';
import '../../providers/transaction_repository_provider.dart';
import 'package:drift/drift.dart' as drift;

class _CreditCardMath {
  final double debt;
  final double available;
  const _CreditCardMath(this.debt, this.available);

  static _CreditCardMath calculate(double balance, double? limit) {
    final safeLimit = limit ?? 0.0;
    if (balance <= 0) {
      final debt = balance.abs();
      final available = safeLimit > 0 ? (safeLimit - debt > 0 ? safeLimit - debt : 0.0) : 0.0;
      return _CreditCardMath(debt, available);
    } else {
      final available = balance;
      final debt = safeLimit > 0 ? (safeLimit - available > 0 ? safeLimit - available : 0.0) : 0.0;
      return _CreditCardMath(debt, available);
    }
  }
}

class _StatementInfo {
  final double statementDebt; // Pago del mes (Deuda facturada congelada)
  final double totalDebt;     // Consumo Total
  final DateTime lastClosingDate;
  final DateTime? paymentDueDate;
  const _StatementInfo(this.statementDebt, this.totalDebt, this.lastClosingDate, this.paymentDueDate);
}

final _statementInfoProvider = FutureProvider.autoDispose.family<_StatementInfo, Account>((ref, account) async {
  if (account.type != 'credit_card' || account.closingDay == null) {
    return _StatementInfo(0.0, 0.0, DateTime.now(), null);
  }
  
  final now = DateTime.now();
  final closingDay = account.closingDay!;
  
  // 1. Calculate the last absolute closing timestamp
  DateTime lastClosingDate;
  if (now.day > closingDay) {
    // Already passed the closing day this month
    lastClosingDate = DateTime(now.year, now.month, closingDay, 23, 59, 59);
  } else {
    // Closing day hasn't arrived this month, so last close was last month
    var year = now.year;
    var month = now.month - 1;
    if (month == 0) {
      month = 12;
      year--;
    }
    // Handle Feb 28/29 cases
    var day = closingDay;
    if (month == 2 && day > 28) {
      day = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
    } else if ((month == 4 || month == 6 || month == 9 || month == 11) && day > 30) {
      day = 30;
    }
    lastClosingDate = DateTime(year, month, day, 23, 59, 59);
  }

  // 2. Calculate the payment due date for that specific cycle (usually next month)
  DateTime? paymentDueDate;
  if (account.paymentDueDay != null) {
      var pYear = lastClosingDate.year;
      var pMonth = lastClosingDate.month + 1;
      if (pMonth > 12) { pMonth = 1; pYear++; }
      var pDay = account.paymentDueDay!;
      
      // Check boundaries
      if (pMonth == 2 && pDay > 28) {
        pDay = (pYear % 4 == 0 && (pYear % 100 != 0 || pYear % 400 == 0)) ? 29 : 28;
      } else if ((pMonth == 4 || pMonth == 6 || pMonth == 9 || pMonth == 11) && pDay > 30) {
        pDay = 30;
      }
      paymentDueDate = DateTime(pYear, pMonth, pDay);
      
      // Extremely quick cycles where payment happens the exact SAME month 
      var sameMonthPayDay = account.paymentDueDay!;
      if (sameMonthPayDay > lastClosingDate.day) {
          var sDay = sameMonthPayDay;
          if (lastClosingDate.month == 2 && sDay > 28) {
              sDay = (lastClosingDate.year % 4 == 0 && (lastClosingDate.year % 100 != 0 || lastClosingDate.year % 400 == 0)) ? 29 : 28;
          } else if ((lastClosingDate.month == 4 || lastClosingDate.month == 6 || lastClosingDate.month == 9 || lastClosingDate.month == 11) && sDay > 30) {
              sDay = 30;
          }
          var sameMonthPayDate = DateTime(lastClosingDate.year, lastClosingDate.month, sDay);
          if (sameMonthPayDate.difference(lastClosingDate).inDays >= 10) { 
              paymentDueDate = sameMonthPayDate;
          }
      }
  }

  // 3. Mathematical reverse-logic: Find all expenses AFTER the last closing date
  final dao = ref.read(transactionsDaoProvider);
  final txs = await dao.getTransactionsByAccount(account.id, limit: 1000); // Need enough history
  
  double recentExpensesSum = 0.0;
  for (final tx in txs) {
    if (tx.date.isAfter(lastClosingDate)) {
      // If the CC was the source of funds, it's an expense that INCREASED total debt.
      // (This excludes payments we made TO the CC, those reduced debt and we don't reverse them).
      if (tx.accountId == account.id && (tx.type == 'expense' || tx.type == 'transfer' || tx.type == 'installment')) {
          recentExpensesSum += tx.amount;
      }
    }
  }

  // 4. Calculate Current Total Debt using our dynamic math logic
  final math = _CreditCardMath.calculate(account.balance, account.creditLimit);
  final totalDebt = math.debt;
  
  // 5. The true "Pago del Mes" is the Total Debt MINUS any recent expenses.
  double statementDebt = totalDebt - recentExpensesSum;
  if (statementDebt < 0) statementDebt = 0.0; // Paid off completely
  
  return _StatementInfo(statementDebt, totalDebt, lastClosingDate, paymentDueDate);
});

/// Provider de account por ID (StreamProvider.family para reactividad)
final accountByIdProvider = StreamProvider.family<Account?, String>((ref, id) {
  final dao = ref.watch(accountsDaoProvider);
  return dao.watchAccount(id);
});

/// Provider de transacciones de una cuenta en un período
final accountTransactionsProvider =
    StreamProvider.autoDispose.family<List<Transaction>, _AccountPeriodParams>(
        (ref, params) {
  final dao = ref.watch(transactionsDaoProvider);
  final range = params.period.calculateRange(params.anchorDate);
  return dao.watchFilteredTransactions(
    startDate: range.start,
    endDate: range.end,
    accountId: params.accountId,
  );
});

class _AccountPeriodParams {
  final String accountId;
  final TimePeriod period;
  final DateTime anchorDate;

  const _AccountPeriodParams({
    required this.accountId,
    required this.period,
    required this.anchorDate,
  });

  @override
  bool operator ==(Object other) =>
      other is _AccountPeriodParams &&
      other.accountId == accountId &&
      other.period == period &&
      other.anchorDate == anchorDate;

  @override
  int get hashCode => accountId.hashCode ^ period.hashCode ^ anchorDate.hashCode;
}

class AccountDetailScreen extends ConsumerStatefulWidget {
  final String accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  ConsumerState<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends ConsumerState<AccountDetailScreen> {
  TimePeriod _selectedPeriod = TimePeriod.month;
  DateTime _anchorDate = DateTime.now();

  void _prevPeriod() {
    setState(() {
      _anchorDate = _shiftDate(_anchorDate, _selectedPeriod, forward: false);
    });
  }

  void _nextPeriod() {
    final next = _shiftDate(_anchorDate, _selectedPeriod, forward: true);
    if (next.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      setState(() => _anchorDate = next);
    }
  }

  DateTime _shiftDate(DateTime date, TimePeriod period, {required bool forward}) {
    final sign = forward ? 1 : -1;
    switch (period) {
      case TimePeriod.day:
        return date.add(Duration(days: sign));
      case TimePeriod.week:
        return date.add(Duration(days: 7 * sign));
      case TimePeriod.month:
        return DateTime(date.year, date.month + sign, 1);
      case TimePeriod.quarter:
        return DateTime(date.year, date.month + (3 * sign), 1);
      case TimePeriod.semester:
        return DateTime(date.year, date.month + (6 * sign), 1);
      case TimePeriod.year:
        return DateTime(date.year + sign, date.month, 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(accountByIdProvider(widget.accountId));
    final params = _AccountPeriodParams(
      accountId: widget.accountId,
      period: _selectedPeriod,
      anchorDate: _anchorDate,
    );
    final transactionsAsync = ref.watch(accountTransactionsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: accountAsync.when(
          data: (account) => Text(account?.name ?? 'Cuenta'),
          loading: () => const Text('Cargando...'),
          error: (_, __) => const Text('Cuenta'),
        ),
        actions: [
          accountAsync.when(
            data: (account) => account != null
                ? IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => context.push('/accounts/edit/${account.id}'),
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Header de cuenta ────────────────────────────────────────────
          accountAsync.when(
            data: (account) {
              if (account == null) return const SizedBox.shrink();
              return _AccountHeader(
                account: account,
                onPayPressed: account.type == 'credit_card'
                    ? () => _showPaymentModal(context, account)
                    : null,
              );
            },
            loading: () => const LoadingWidget(),
            error: (e, _) => ErrorDisplayWidget(message: e.toString()),
          ),

          // ─── Selector de período ─────────────────────────────────────────
          _PeriodSelector(
            selectedPeriod: _selectedPeriod,
            anchorDate: _anchorDate,
            onPeriodChanged: (p) => setState(() {
              _selectedPeriod = p;
              _anchorDate = DateTime.now();
            }),
            onPrev: _prevPeriod,
            onNext: _nextPeriod,
          ),

          // ─── Resumen del período ─────────────────────────────────────────
          transactionsAsync.when(
            data: (txs) => _PeriodSummaryCard(transactions: txs, accountId: widget.accountId),
            loading: () => const SizedBox(height: 72, child: LoadingWidget()),
            error: (e, _) => const SizedBox.shrink(),
          ),

          // ─── Lista de transacciones ──────────────────────────────────────
          Expanded(
            child: transactionsAsync.when(
              data: (txs) {
                if (txs.isEmpty) {
                  return _EmptyPeriod(period: _selectedPeriod, anchor: _anchorDate);
                }
                // Agrupar por fecha
                final grouped = <DateTime, List<Transaction>>{};
                for (final t in txs) {
                  final day = DateTime(t.date.year, t.date.month, t.date.day);
                  grouped.putIfAbsent(day, () => []).add(t);
                }
                final sortedDays = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: sortedDays.length,
                  itemBuilder: (context, i) {
                    final day = sortedDays[i];
                    final dayTxs = grouped[day]!;
                    return _DayGroup(day: day, transactions: dayTxs, accountId: widget.accountId);
                  },
                );
              },
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorDisplayWidget(message: e.toString()),
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentModal(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: _CreditCardPaymentSheet(destAccount: account),
      ),
    );
  }
}

// ── Widgets auxiliares ─────────────────────────────────────────────────────

class _AccountHeader extends StatelessWidget {
  final dynamic account;
  final VoidCallback? onPayPressed;

  const _AccountHeader({required this.account, this.onPayPressed});

  Color _typeColor(String type) {
    switch (type) {
      case 'cash': return AppColors.income;
      case 'bank': return AppColors.primary;
      case 'wallet': return Colors.orange;
      case 'savings': return AppColors.transfer;
      case 'credit_card': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'cash': return Icons.payments;
      case 'bank': return Icons.account_balance;
      case 'wallet': return Icons.smartphone;
      case 'savings': return Icons.savings;
      case 'credit_card': return Icons.credit_card;
      default: return Icons.account_balance_wallet;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'cash': return 'Efectivo';
      case 'bank': return 'Banco';
      case 'wallet': return 'Billetera digital';
      case 'savings': return 'Ahorros';
      case 'card': return 'Tarjeta';
      case 'credit_card': return 'Tarjeta de crédito';
      default: return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(account.type);
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(_typeIcon(account.type), color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _typeLabel(account.type),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  account.type == 'credit_card' 
                      ? 'Deuda T.: ${fmt.format(_CreditCardMath.calculate(account.balance, account.creditLimit).debt)}'
                      : fmt.format(account.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
                if (account.type == 'credit_card' && account.creditLimit != null && account.creditLimit! > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Disponible: ${fmt.format(_CreditCardMath.calculate(account.balance, account.creditLimit).available)}',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                if (onPayPressed != null) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('Pagar Tarjeta'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: color,
                      backgroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: onPayPressed,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final TimePeriod selectedPeriod;
  final DateTime anchorDate;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _PeriodSelector({
    required this.selectedPeriod,
    required this.anchorDate,
    required this.onPeriodChanged,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Chips de período
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: TimePeriod.values.map((p) {
              final selected = p == selectedPeriod;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(p.label),
                  selected: selected,
                  onSelected: (_) => onPeriodChanged(p),
                  selectedColor: cs.primaryContainer,
                  labelStyle: TextStyle(
                    color: selected ? cs.onPrimaryContainer : null,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        // Navegación prev/next
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrev,
                tooltip: 'Período anterior',
              ),
              Text(
                selectedPeriod.format(anchorDate),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: onNext,
                tooltip: 'Período siguiente',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodSummaryCard extends StatelessWidget {
  final List<Transaction> transactions;
  final String accountId;
  const _PeriodSummaryCard({required this.transactions, required this.accountId});

  @override
  Widget build(BuildContext context) {
    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.type == 'income') {
        income += t.amount;
      } else if (t.type == 'expense') {
        expense += t.amount;
      } else if (t.type == 'transfer') {
        if (t.destinationAccountId == accountId) {
          income += t.amount; // Transferencia recibida
        } else if (t.accountId == accountId) {
          expense += t.amount; // Transferencia enviada
        }
      }
    }
    final balance = income - expense;
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(label: 'Ingresos', value: fmt.format(income), color: AppColors.income),
          Container(width: 1, height: 36, color: Colors.grey.withValues(alpha: 0.3)),
          _SummaryItem(label: 'Gastos', value: fmt.format(expense), color: AppColors.expense),
          Container(width: 1, height: 36, color: Colors.grey.withValues(alpha: 0.3)),
          _SummaryItem(
            label: 'Balance',
            value: fmt.format(balance),
            color: balance >= 0 ? AppColors.income : AppColors.expense,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      ],
    );
  }
}

class _DayGroup extends StatelessWidget {
  final DateTime day;
  final List<Transaction> transactions;
  final String accountId;
  const _DayGroup({required this.day, required this.transactions, required this.accountId});

  @override
  Widget build(BuildContext context) {
    final dayFmt = DateFormat('EEEE, d MMM', 'es');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            dayFmt.format(day),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        ...transactions.map((t) => _TransactionTile(transaction: t, accountId: accountId)),
      ],
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  final Transaction transaction;
  final String accountId;
  const _TransactionTile({required this.transaction, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTransfer = transaction.type == 'transfer';
    final isTransferIn = isTransfer && transaction.destinationAccountId == accountId;
    final isTransferOut = isTransfer && transaction.accountId == accountId;

    final isExpense = transaction.type == 'expense' || isTransferOut;
    final isIncome = transaction.type == 'income' || isTransferIn;
    
    final color = isExpense ? AppColors.expense : isIncome ? AppColors.income : AppColors.transfer;
    final sign = isExpense ? '-' : isIncome ? '+' : '';
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    final displayName = (transaction.productName != null && transaction.productName!.isNotEmpty)
        ? transaction.productName!
        : (isTransfer 
            ? (isTransferIn ? 'Transferencia recibida' : 'Transferencia enviada')
            : (transaction.description ?? 'Sin descripción'));

    final card = Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isExpense ? Icons.arrow_upward : isIncome ? Icons.arrow_downward : Icons.swap_horiz,
            color: color,
            size: 18,
          ),
        ),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: transaction.description != null && transaction.productName != null
            ? Text(transaction.description!, style: const TextStyle(fontSize: 11))
            : null,
        trailing: Text(
          '$sign ${fmt.format(transaction.amount)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14),
        ),
      ),
    );

    return Dismissible(
      key: Key('acct_dtl_tx_${transaction.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async => true,
      onDismissed: (_) {
        ref.read(transactionRepositoryProvider).deleteTransaction(transaction.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transacción eliminada')),
        );
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: card,
    );
  }
}

class _EmptyPeriod extends StatelessWidget {
  final TimePeriod period;
  final DateTime anchor;
  const _EmptyPeriod({required this.period, required this.anchor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Sin movimientos',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'No hay transacciones en ${period.format(anchor)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet interactivo para pagar Tarjeta de Crédito ────────────────────────
class _CreditCardPaymentSheet extends ConsumerStatefulWidget {
  final Account destAccount;
  const _CreditCardPaymentSheet({required this.destAccount});

  @override
  ConsumerState<_CreditCardPaymentSheet> createState() => _CreditCardPaymentSheetState();
}

class _CreditCardPaymentSheetState extends ConsumerState<_CreditCardPaymentSheet> {
  final _amountController = TextEditingController();
  String? _selectedSourceAccountId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    // Forzar redibujado para el mensaje dinámico debajo del input
    setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _setAmount(double amount) {
    _amountController.text = amount.toStringAsFixed(2);
  }

  Future<void> _submitPayment() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || _selectedSourceAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa monto y selecciona cuenta origen')),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido mayor a 0')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(transactionRepositoryProvider);
      const uuid = Uuid();
      final transactionId = uuid.v4();

      final transaction = TransactionsCompanion.insert(
        id: transactionId,
        type: 'transfer',
        amount: amount,
        accountId: _selectedSourceAccountId!,
        destinationAccountId: drift.Value(widget.destAccount.id),
        description: drift.Value('Pago T.C. ${widget.destAccount.name}'),
        date: DateTime.now(),
        isRecurring: const drift.Value(false),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.addTransaction(
        transaction: transaction,
        accountId: _selectedSourceAccountId!,
        amount: amount,
        type: 'transfer',
        destinationAccountId: widget.destAccount.id,
      );

      if (mounted) {
        Navigator.pop(context); // Cierra el modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pago registrado exitosamente ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar pago: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final fmt = NumberFormat.currency(symbol: 'S/ ', decimalDigits: 2);
    
    // Async load del Statement Math 
    final statementAsync = ref.watch(_statementInfoProvider(widget.destAccount));
    
    // Matemática general unificada para Disponibles siempre estables
    final math = _CreditCardMath.calculate(widget.destAccount.balance, widget.destAccount.creditLimit);
    final availableCredit = math.available;
    
    // Input actual (para feedback UI)
    final currentInputAmount = double.tryParse(_amountController.text) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pagar ${widget.destAccount.name}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // --- Resumen Inteligente de la Tarjeta ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: statementAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
              error: (err, _) => Text('Error cargando ciclo: $err'),
              data: (info) {
                // Cálculo Mínimo: 5% del PAGO DEL MES (Statement Debt), no del Consumo Total
                double minPayment = info.statementDebt * 0.05;
                if (minPayment < 30.0 && info.statementDebt > 0) minPayment = info.statementDebt < 30.0 ? info.statementDebt : 30.0;
                
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Columna Pago Del Mes (Destacado)
                        Column(
                          children: [
                            const Text('Pago del mes', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                            Text(
                              info.statementDebt > 0 ? fmt.format(info.statementDebt) : 'S/ 0.00',
                              style: TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.bold,
                                color: info.statementDebt > 0 ? Theme.of(context).colorScheme.error : Colors.green,
                              ),
                            ),
                            if (info.paymentDueDate != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('Vence ${DateFormat('dd MMM').format(info.paymentDueDate!)}', 
                                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        Container(width: 1, height: 40, color: Colors.grey.withValues(alpha: 0.3)),
                        // Columna Deuda Total (Secundario)
                        Column(
                          children: [
                            const Text('Consumo Total', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              info.totalDebt > 0 ? fmt.format(info.totalDebt) : 'S/ 0.00',
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.w600,
                                color: info.totalDebt > 0 ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Línea Total:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(fmt.format(widget.destAccount.creditLimit ?? 0.0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Disponible:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(
                          fmt.format(availableCredit), 
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: widget.destAccount.creditLimit != null && availableCredit < (widget.destAccount.creditLimit! * 0.15) 
                                ? Theme.of(context).colorScheme.error 
                                : Colors.green
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    // Quick Action Chips Dinámicos basados en la info del Statement
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (info.statementDebt > 0)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ActionChip(
                                label: Text('Pagar Mes', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                                onPressed: () => _setAmount(info.statementDebt),
                              ),
                            ),
                          if (minPayment > 0 && minPayment < info.statementDebt)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ActionChip(
                                label: Text('Mínimo', style: const TextStyle(fontSize: 12)),
                                onPressed: () => _setAmount(minPayment),
                              ),
                            ),
                          if (info.totalDebt > info.statementDebt)
                            ActionChip(
                              label: Text('Pagar Total', style: const TextStyle(fontSize: 12)),
                              onPressed: () => _setAmount(info.totalDebt),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
          const SizedBox(height: 24),
          
          // --- Input de Monto ---
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto a pagar',
              prefixText: 'S/ ',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
          ),
          const SizedBox(height: 8),
          // --- Mensaje Dinámico ---
          statementAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (info) {
              if (currentInputAmount > 0 && info.totalDebt > 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Builder(
                    builder: (context) {
                      if (currentInputAmount > info.totalDebt) {
                        return Text(
                          'El monto supera la deuda total.',
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        );
                      } else if (currentInputAmount >= info.totalDebt) {
                        return const Text(
                          'Deuda total liquidada 🎉',
                          style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        );
                      } else if (info.statementDebt > 0 && currentInputAmount >= info.statementDebt) {
                         return const Text(
                          'Pago del mes cubierto ✅',
                          style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        );
                      } else {
                        final remaining = info.statementDebt - currentInputAmount;
                        return Text(
                          'Faltan ${fmt.format(remaining < 0 ? 0 : remaining)} para cubrir el mes.',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        );
                      }
                    },
                  ),
                );
              }
              return const SizedBox.shrink();
            }
          ),
            
          const SizedBox(height: 16),
          
          // --- Selector de Cuenta Origen ---
          accountsAsync.when(
            data: (accounts) {
              final sourceAccounts = accounts.where((a) => a.id != widget.destAccount.id).toList();
              
              return DropdownButtonFormField<String>(
                initialValue: _selectedSourceAccountId,
                decoration: const InputDecoration(
                  labelText: 'Desde la cuenta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                items: sourceAccounts.map((a) {
                  return DropdownMenuItem(
                    value: a.id,
                    child: Text('${a.name} (S/ ${a.balance.toStringAsFixed(2)})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedSourceAccountId = val);
                },
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Error al cargar cuentas: $e'),
          ),
          const SizedBox(height: 24),
          
          // --- Botón Confirmar ---
          statementAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (info) => ElevatedButton(
              onPressed: (_isLoading || _selectedSourceAccountId == null || currentInputAmount <= 0 || currentInputAmount > (info.totalDebt > 0 ? info.totalDebt : double.infinity)) 
                  ? null 
                  : _submitPayment,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirmar Pago', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
