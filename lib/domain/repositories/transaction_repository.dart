import '../../data/database/drift_database.dart'; // Ensure Companion is available

abstract class TransactionRepository {
  Future<void> addTransaction({
    required TransactionsCompanion transaction,
    required String accountId,
    double amount,
    String type,
    String? destinationAccountId, // For transfers
    // Recurring Payment (optional)
    dynamic recurringPayment, // Using dynamic to avoid circular import or verbose import of Companion
  });

  Future<void> updateTransaction(Transaction transaction);

  Future<void> deleteTransaction(String id);

  Stream<List<Transaction>> watchAllTransactions();
  
  Stream<List<Transaction>> watchFilteredTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? accountId,
    String? categoryId,
  });
}
