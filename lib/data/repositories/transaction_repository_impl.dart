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
  }) async {
    // Obtenemos las tarifas de red ANTES de bloquear la BD (evita el congelamiento)
    final rates = await _currencyService.getRatesBasePEN();

    return _db.transaction(() async {
      // 0. Insert Recurring Payment if exists
      if (recurringPayment != null &&
          recurringPayment is RecurringPaymentsCompanion) {
        await _db.recurringPaymentsDao.createRecurringPayment(recurringPayment);
      }

      // 1. Insert Transaction
      await _db.transactionsDao.createTransaction(transaction);

      // 2. Update Source Account Balance
      // Nota: Asumimos que las cuentas están en PEN (moneda base) por ahora.
      // Convertimos el monto de la transacción a PEN antes de descontar.

      double amountInPen = amount;
      // transaction.currency es Value<String> en el companion.
      if (transaction.currency.present) {
        amountInPen = _convertToPen(amount, transaction.currency.value, rates);
      } else {
        // Fallback or default assumption (PEN) if not present
      }

      final sourceAccount = await _db.accountsDao.getAccountById(accountId);
      if (sourceAccount != null) {
        double newBalance = sourceAccount.balance;

        if (type == 'income') {
          newBalance += amountInPen;
        } else {
          // Expense or Transfer (money leaves source)
          newBalance -= amountInPen;
        }
        await _db.accountsDao.updateBalance(accountId, newBalance);
      }

      // 3. Update Destination Account Balance (if transfer)
      if (type == 'transfer' && destinationAccountId != null) {
        final destAccount = await _db.accountsDao.getAccountById(
          destinationAccountId,
        );
        if (destAccount != null) {
          // Money enters destination
          final newDestBalance = destAccount.balance + amountInPen;
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

      // 2. Revert OLD balance effect
      double oldAmountInPen = oldTransaction.amount;
      oldAmountInPen = _convertToPen(
        oldTransaction.amount,
        oldTransaction.currency,
        rates,
      );

      final oldAccount = await _db.accountsDao.getAccountById(
        oldTransaction.accountId,
      );
      if (oldAccount != null) {
        double revertedBalance = oldAccount.balance;
        if (oldTransaction.type == 'income') {
          revertedBalance -= oldAmountInPen;
        } else {
          revertedBalance += oldAmountInPen;
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
          await _db.accountsDao.updateBalance(
            oldTransaction.destinationAccountId!,
            oldDest.balance - oldAmountInPen,
          );
        }
      }

      // 3. Apply NEW balance effect
      // Note: Transaction object passed here is the NEW one.
      double newAmountInPen = transaction.amount;
      newAmountInPen = _convertToPen(
        transaction.amount,
        transaction.currency,
        rates,
      );

      final newAccount = await _db.accountsDao.getAccountById(
        transaction.accountId,
      );
      if (newAccount != null) {
        // We need to re-fetch balance because we just updated it (maybe)
        // Actually, inside a transaction, we should get the latest.
        // But getAccountById fetches snapshot.
        // If accountId is same as oldTransaction.accountId, we must be careful.
        // The safest way is to fetch again.

        final freshAccount = await _db.accountsDao.getAccountById(
          transaction.accountId,
        );
        if (freshAccount != null) {
          double newBalance = freshAccount.balance;
          if (transaction.type == 'income') {
            newBalance += newAmountInPen;
          } else {
            newBalance -= newAmountInPen;
          }
          await _db.accountsDao.updateBalance(
            transaction.accountId,
            newBalance,
          );
        }
      }

      // Apply to new destination if transfer
      if (transaction.type == 'transfer' &&
          transaction.destinationAccountId != null) {
        final freshDest = await _db.accountsDao.getAccountById(
          transaction.destinationAccountId!,
        );
        if (freshDest != null) {
          await _db.accountsDao.updateBalance(
            transaction.destinationAccountId!,
            freshDest.balance + newAmountInPen,
          );
        }
      }

      // 4. Update Transaction in DB
      await _db.transactionsDao.updateTransaction(transaction);
    });
  }

  @override
  Future<void> deleteTransaction(String id) async {
    // 1. Fetch transaction to know amount/account
    final transaction = await _db.transactionsDao.getTransactionById(id);
    if (transaction == null) return;

    // 2. Revert Balance Update
    // HOTFIX: Hardcoded rates to prevent DB lock/crash (Network call removed)
    final rates = {'USD': 3.75, 'EUR': 4.10, 'PEN': 1.0};
    double amountInPen = transaction.amount;
    try {
      amountInPen = _convertToPen(
        transaction.amount,
        transaction.currency,
        rates,
      );
    } catch (e) {
      amountInPen = transaction.amount;
    }

    final accountId = transaction.accountId;
    final account = await _db.accountsDao.getAccountById(accountId);

    if (account != null) {
      double newBalance = account.balance;

      if (transaction.type == 'income') {
        newBalance -= amountInPen;
      } else {
        newBalance += amountInPen;
      }
      await _db.accountsDao.updateBalance(accountId, newBalance);
    }

    // Handle transfer destination reversal
    if (transaction.type == 'transfer' &&
        transaction.destinationAccountId != null) {
      final destAccount = await _db.accountsDao.getAccountById(
        transaction.destinationAccountId!,
      );
      if (destAccount != null) {
        final newDestBalance = destAccount.balance - amountInPen;
        await _db.accountsDao.updateBalance(
          transaction.destinationAccountId!,
          newDestBalance,
        );
      }
    }

    // 3. Delete Transaction
    await _db.transactionsDao.deleteTransaction(id);
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
