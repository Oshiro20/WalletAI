import '../../domain/repositories/transaction_repository.dart';
import '../database/drift_database.dart';

import '../../data/datasources/currency_service.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final AppDatabase _db;
  final CurrencyService _currencyService = CurrencyService();

  TransactionRepositoryImpl(this._db);

  @override
  Future<void> addTransaction({
    required TransactionsCompanion transaction,
    required String accountId,
    double amount = 0.0,
    String type = 'expense', // expense, income, transfer
    String? destinationAccountId,
    dynamic recurringPayment, // Expecting RecurringPaymentsCompanion
    dynamic creditInstallment, // Expecting CreditInstallmentsCompanion
  }) async {
    // Obtenemos las tarifas de red ANTES de bloquear la BD (evita el congelamiento)
    final rates = await _currencyService.getRatesBasePEN();

    return _db.transaction(() async {
      // 0. Insert Recurring Payment if exists
      if (recurringPayment != null &&
          recurringPayment is RecurringPaymentsCompanion) {
        await _db.recurringPaymentsDao.createRecurringPayment(recurringPayment);
      }

      // 0b. Insert Credit Installment plan atomically if exists
      if (creditInstallment != null &&
          creditInstallment is CreditInstallmentsCompanion) {
        await _db.creditInstallmentsDao.insertInstallment(creditInstallment);
      }

      // 1. Insert Transaction
      await _db.transactionsDao.createTransaction(transaction);

      final txCurrency = transaction.currency.present
          ? transaction.currency.value
          : 'PEN';

      // 2. Update Source Account Balance (en la moneda propia de la cuenta origen)
      final sourceAccount = await _db.accountsDao.getAccountById(accountId);
      if (sourceAccount != null) {
        final amountInSourceCurrency = _convertCurrency(
          amount,
          txCurrency,
          sourceAccount.currency,
          rates,
        );
        double newBalance = sourceAccount.balance;

        if (type == 'income') {
          newBalance += amountInSourceCurrency;
        } else {
          // Expense or Transfer (money leaves source)
          newBalance -= amountInSourceCurrency;
        }
        await _db.accountsDao.updateBalance(accountId, newBalance);
      }

      // 3. Update Destination Account Balance (en la moneda de la cuenta destino)
      if (type == 'transfer' && destinationAccountId != null) {
        final destAccount = await _db.accountsDao.getAccountById(
          destinationAccountId,
        );
        if (destAccount != null) {
          final amountInDestCurrency = _convertCurrency(
            amount,
            txCurrency,
            destAccount.currency,
            rates,
          );
          final newDestBalance = destAccount.balance + amountInDestCurrency;
          await _db.accountsDao.updateBalance(
            destinationAccountId,
            newDestBalance,
          );
        }
      }
    });
  }

  double _convertToPen(
    double amount,
    String currency,
    Map<String, double> rates,
  ) {
    if (currency == 'PEN') return amount;
    if (!rates.containsKey(currency)) return amount;
    final rate = rates[currency]!;
    if (rate == 0) return amount;
    return amount / rate;
  }

  double _convertCurrency(
    double amount,
    String fromCurrency,
    String toCurrency,
    Map<String, double> rates,
  ) {
    if (fromCurrency == toCurrency) return amount;
    final amountInPen = _convertToPen(amount, fromCurrency, rates);
    if (toCurrency == 'PEN') return amountInPen;
    final targetRate = rates[toCurrency];
    if (targetRate == null || targetRate == 0) return amountInPen;
    return amountInPen * targetRate;
  }

  @override
  Future<void> updateTransaction(Transaction transaction) async {
    // Obtenemos las tarifas locales/red ANTES del lock
    final rates = await _currencyService.getRatesBasePEN();

    return _db.transaction(() async {
      // 1. Fetch OLD transaction
      final oldTransaction = await _db.transactionsDao.getTransactionById(
        transaction.id,
      );
      if (oldTransaction == null) return; // Should not happen

      // 2. Revert OLD balance effect (en moneda de cuenta origen)
      final oldAccount = await _db.accountsDao.getAccountById(
        oldTransaction.accountId,
      );
      if (oldAccount != null) {
        final oldAmountInSource = _convertCurrency(
          oldTransaction.amount,
          oldTransaction.currency,
          oldAccount.currency,
          rates,
        );
        double revertedBalance = oldAccount.balance;
        if (oldTransaction.type == 'income') {
          revertedBalance -= oldAmountInSource;
        } else {
          revertedBalance += oldAmountInSource;
        }
        await _db.accountsDao.updateBalance(
          oldTransaction.accountId,
          revertedBalance,
        );
      }

      // Revert transfer destination if applicable
      if (oldTransaction.type == 'transfer' &&
          oldTransaction.destinationAccountId != null) {
        final oldDest = await _db.accountsDao.getAccountById(
          oldTransaction.destinationAccountId!,
        );
        if (oldDest != null) {
          final oldAmountInDest = _convertCurrency(
            oldTransaction.amount,
            oldTransaction.currency,
            oldDest.currency,
            rates,
          );
          await _db.accountsDao.updateBalance(
            oldTransaction.destinationAccountId!,
            oldDest.balance - oldAmountInDest,
          );
        }
      }

      // 3. Apply NEW balance effect
      final freshAccount = await _db.accountsDao.getAccountById(
        transaction.accountId,
      );
      if (freshAccount != null) {
        final newAmountInSource = _convertCurrency(
          transaction.amount,
          transaction.currency,
          freshAccount.currency,
          rates,
        );
        double newBalance = freshAccount.balance;
        if (transaction.type == 'income') {
          newBalance += newAmountInSource;
        } else {
          newBalance -= newAmountInSource;
        }
        await _db.accountsDao.updateBalance(
          transaction.accountId,
          newBalance,
        );
      }

      // Apply to new destination if transfer
      if (transaction.type == 'transfer' &&
          transaction.destinationAccountId != null) {
        final freshDest = await _db.accountsDao.getAccountById(
          transaction.destinationAccountId!,
        );
        if (freshDest != null) {
          final newAmountInDest = _convertCurrency(
            transaction.amount,
            transaction.currency,
            freshDest.currency,
            rates,
          );
          await _db.accountsDao.updateBalance(
            transaction.destinationAccountId!,
            freshDest.balance + newAmountInDest,
          );
        }
      }

      // 4. Update Transaction in DB
      await _db.transactionsDao.updateTransaction(transaction);
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    // Obtenemos las tasas ANTES de iniciar la transacción SQLite para evitar locks
    final rates = await _currencyService.getRatesBasePEN();

    return _db.transaction(() async {
      // 1. Fetch transaction to know amount/account
      final transaction = await _db.transactionsDao.getTransactionById(id);
      if (transaction == null) return;

      // 2. Revert Balance Update en la moneda de cada cuenta
      final account = await _db.accountsDao.getAccountById(transaction.accountId);
      if (account != null) {
        final amountInSource = _convertCurrency(
          transaction.amount,
          transaction.currency,
          account.currency,
          rates,
        );
        double newBalance = account.balance;

        if (transaction.type == 'income') {
          newBalance -= amountInSource;
        } else {
          newBalance += amountInSource;
        }
        await _db.accountsDao.updateBalance(transaction.accountId, newBalance);
      }

      // Handle transfer destination reversal
      if (transaction.type == 'transfer' &&
          transaction.destinationAccountId != null) {
        final destAccount = await _db.accountsDao.getAccountById(
          transaction.destinationAccountId!,
        );
        if (destAccount != null) {
          final amountInDest = _convertCurrency(
            transaction.amount,
            transaction.currency,
            destAccount.currency,
            rates,
          );
          final newDestBalance = destAccount.balance - amountInDest;
          await _db.accountsDao.updateBalance(
            transaction.destinationAccountId!,
            newDestBalance,
          );
        }
      }

      // 3. Eliminar plan de cuotas solo si la transacción borrada fue la compra original
      if (transaction.creditInstallmentId != null) {
        final inst = await _db.creditInstallmentsDao.getInstallmentById(
          transaction.creditInstallmentId!,
        );
        if (inst != null &&
            (inst.transactionId == transaction.id ||
                transaction.type == 'expense')) {
          await _db.creditInstallmentsDao.deleteInstallment(inst.id);
        }
      }

      // 4. Delete Transaction
      await _db.transactionsDao.deleteTransaction(id);
    });
  }

  @override
  Stream<List<Transaction>> watchAllTransactions() {
    return _db.transactionsDao.watchAllTransactions();
  }

  @override
  Stream<List<Transaction>> watchFilteredTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? accountId,
    String? categoryId,
  }) {
    return _db.transactionsDao.watchFilteredTransactions(
      startDate: startDate,
      endDate: endDate,
      type: type,
      accountId: accountId,
      categoryId: categoryId,
    );
  }
}
