import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/transactions_table.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionsDao extends DatabaseAccessor<AppDatabase> with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// Obtener todas las transacciones
  Future<List<Transaction>> getAllTransactions({int limit = 100}) {
    return (select(transactions)
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  /// Obtener transacción por ID
  Future<Transaction?> getTransactionById(String id) {
    return (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Obtener transacciones por cuenta
  Future<List<Transaction>> getTransactionsByAccount(String accountId, {int limit = 100}) {
    return (select(transactions)
          ..where((t) => t.accountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  /// Obtener transacciones por tipo (income, expense, transfer)
  Future<List<Transaction>> getTransactionsByType(String type, {int limit = 100}) {
    return (select(transactions)
          ..where((t) => t.type.equals(type))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  /// Obtener transacciones por categoría
  Future<List<Transaction>> getTransactionsByCategory(String categoryId, {int limit = 100}) {
    return (select(transactions)
          ..where((t) => t.categoryId.equals(categoryId))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
          ..limit(limit))
        .get();
  }

  /// Obtener transacciones por rango de fechas
  Future<List<Transaction>> getTransactionsByDateRange(DateTime start, DateTime end) {
    return (select(transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .get();
  }

  /// Crear transacción
  Future<int> createTransaction(TransactionsCompanion entry) {
    return attachedDatabase.transaction(() async {
      final id = await into(transactions).insert(entry);
      
      // Sync Queue
      final insertedRow = await (select(transactions)..where((t) => t.id.equals(entry.id.value))).getSingle();
      await into(attachedDatabase.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'insert',
          recordId: insertedRow.id,
          targetTable: 'transactions',
          data: Value(jsonEncode(insertedRow.toJson())),
          createdAt: DateTime.now(),
        ),
      );
      
      return id;
    });
  }

  /// Actualizar transacción
  Future<bool> updateTransaction(Transaction entry) {
    return attachedDatabase.transaction(() async {
      final result = await update(transactions).replace(entry);
      
      if (result) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'update',
            recordId: entry.id,
            targetTable: 'transactions',
            data: Value(jsonEncode(entry.toJson())),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar transacción
  Future<int> deleteTransaction(String transactionId) {
    return attachedDatabase.transaction(() async {
      final result = await (delete(transactions)..where((t) => t.id.equals(transactionId))).go();
      
      if (result > 0) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: transactionId,
            targetTable: 'transactions',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar TODAS las transacciones
  Future<int> deleteAllTransactions() {
    return attachedDatabase.transaction(() async {
      final ids = await (select(transactions).map((t) => t.id)).get();
      final result = await delete(transactions).go();

      for (final id in ids) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: id,
            targetTable: 'transactions',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Obtener total de ingresos en un período
  Future<double> getTotalIncome(DateTime start, DateTime end) async {
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        transactions.type.equals('income') &
            transactions.date.isBiggerOrEqualValue(start) &
            transactions.date.isSmallerOrEqualValue(end),
      );

    final result = await query.getSingleOrNull();
    return result?.read(transactions.amount.sum()) ?? 0.0;
  }

  /// Obtener total de gastos en un período
  Future<double> getTotalExpenses(DateTime start, DateTime end) async {
    final query = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        transactions.type.equals('expense') &
            transactions.date.isBiggerOrEqualValue(start) &
            transactions.date.isSmallerOrEqualValue(end),
      );

    final result = await query.getSingleOrNull();
    return result?.read(transactions.amount.sum()) ?? 0.0;
  }

  /// Obtener balance (ingresos - gastos) en un período
  Future<double> getBalance(DateTime start, DateTime end) async {
    final income = await getTotalIncome(start, end);
    final expenses = await getTotalExpenses(start, end);
    return income - expenses;
  }

  /// Obtener gastos por categoría en un período
  Future<Map<String, double>> getExpensesByCategory(DateTime start, DateTime end) async {
    final query = selectOnly(transactions)
      ..addColumns([transactions.categoryId, transactions.amount.sum()])
      ..where(
        transactions.type.equals('expense') &
            transactions.date.isBiggerOrEqualValue(start) &
            transactions.date.isSmallerOrEqualValue(end) &
            transactions.categoryId.isNotNull(),
      )
      ..groupBy([transactions.categoryId]);

    final results = await query.get();
    final Map<String, double> expensesByCategory = {};

    for (final row in results) {
      final categoryId = row.read(transactions.categoryId);
      final total = row.read(transactions.amount.sum()) ?? 0.0;
      if (categoryId != null) {
        expensesByCategory[categoryId] = total;
      }
    }

    return expensesByCategory;
  }

  /// Stream de transacciones (para UI reactiva)
  Stream<List<Transaction>> watchAllTransactions({int limit = 100}) {
    return (select(transactions)
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
          ..limit(limit))
        .watch();
  }

  /// Stream de transacciones por cuenta
  Stream<List<Transaction>> watchTransactionsByAccount(String accountId) {
    return (select(transactions)
          ..where((t) => t.accountId.equals(accountId) | t.destinationAccountId.equals(accountId))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Stream de transacciones del mes actual
  Stream<List<Transaction>> watchCurrentMonthTransactions() {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return (select(transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(startOfMonth) & t.date.isSmallerOrEqualValue(endOfMonth))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Stream de transacciones filtradas
  Stream<List<Transaction>> watchFilteredTransactions({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? accountId,
    String? categoryId,
  }) {
    return (select(transactions)
          ..where((t) {
            Expression<bool> predicate = const Constant(true);
            if (startDate != null) {
              predicate = predicate & t.date.isBiggerOrEqualValue(startDate);
            }
            if (endDate != null) {
              predicate = predicate & t.date.isSmallerOrEqualValue(endDate);
            }
            if (type != null) {
              predicate = predicate & t.type.equals(type);
            }
            if (accountId != null) {
              // Si es transferencia, la cuenta puede ser origen o destino
              predicate = predicate & (t.accountId.equals(accountId) | t.destinationAccountId.equals(accountId));
            }
            if (categoryId != null) {
              predicate = predicate & t.categoryId.equals(categoryId);
            }
            return predicate;
          })
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)]))
        .watch();
  }
  /// Stream de gastos por categoría en un período
  Stream<Map<String, double>> watchExpensesByCategory(DateTime start, DateTime end) {
    final query = selectOnly(transactions)
      ..addColumns([transactions.categoryId, transactions.amount.sum()])
      ..where(
        transactions.type.equals('expense') &
            transactions.date.isBiggerOrEqualValue(start) &
            transactions.date.isSmallerOrEqualValue(end) &
            transactions.categoryId.isNotNull(),
      )
      ..groupBy([transactions.categoryId]);

    return query.watch().map((rows) {
      final Map<String, double> expensesByCategory = {};
      for (final row in rows) {
        final categoryId = row.read(transactions.categoryId);
        final total = row.read(transactions.amount.sum()) ?? 0.0;
        if (categoryId != null) {
          expensesByCategory[categoryId] = total;
        }
      }
      return expensesByCategory;
    });
  }

  /// Stream de ingresos por categoría en un período
  Stream<Map<String, double>> watchIncomeByCategory(DateTime start, DateTime end) {
    final query = selectOnly(transactions)
      ..addColumns([transactions.categoryId, transactions.amount.sum()])
      ..where(
        transactions.type.equals('income') &
            transactions.date.isBiggerOrEqualValue(start) &
            transactions.date.isSmallerOrEqualValue(end) &
            transactions.categoryId.isNotNull(),
      )
      ..groupBy([transactions.categoryId]);

    return query.watch().map((rows) {
      final Map<String, double> incomeByCategory = {};
      for (final row in rows) {
        final categoryId = row.read(transactions.categoryId);
        final total = row.read(transactions.amount.sum()) ?? 0.0;
        if (categoryId != null) {
          incomeByCategory[categoryId] = total;
        }
      }
      return incomeByCategory;
    });
  }

  /// Stream de actividad diaria (ingresos y gastos)
  Stream<Map<DateTime, Map<String, double>>> watchDailyTotals(DateTime start, DateTime end) {
    // Agrupar por día requiere una expresión custom en SQLite, pero drift lo facilita en Dart
    // Consultamos todas las transacciones del rango y las agrupamos en memoria para simplificar
    // compatibilidad entre plataformas (SQLite vs Postgres etc)
    
    return (select(transactions)
          ..where((t) => t.date.isBiggerOrEqualValue(start) & t.date.isSmallerOrEqualValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.asc)]))
        .watch()
        .map((transactionList) {
      final Map<DateTime, Map<String, double>> dailyTotals = {};

      for (var t in transactionList) {
        // Normalizar fecha (solo año, mes, día)
        final date = DateTime(t.date.year, t.date.month, t.date.day);
        
        if (!dailyTotals.containsKey(date)) {
          dailyTotals[date] = {'income': 0.0, 'expense': 0.0};
        }

        if (t.type == 'income') {
          dailyTotals[date]!['income'] = (dailyTotals[date]!['income'] ?? 0) + t.amount;
        } else if (t.type == 'expense') {
          dailyTotals[date]!['expense'] = (dailyTotals[date]!['expense'] ?? 0) + t.amount;
        }
      }
      return dailyTotals;
    });
  }
  /// Stream de gastos por subcategoría en un período para una categoría específica
  Stream<Map<String, double>> watchExpensesBySubcategory(String categoryId, DateTime start, DateTime end) {
    final query = selectOnly(transactions)
      ..addColumns([transactions.subcategoryId, transactions.amount.sum()])
      ..where(
        transactions.type.equals('expense') &
        transactions.categoryId.equals(categoryId) &
        transactions.date.isBiggerOrEqualValue(start) &
        transactions.date.isSmallerOrEqualValue(end) &
        transactions.subcategoryId.isNotNull(),
      )
      ..groupBy([transactions.subcategoryId]);

    return query.watch().map((rows) {
      final Map<String, double> expensesBySubcategory = {};
      for (final row in rows) {
        final subId = row.read(transactions.subcategoryId);
        final total = row.read(transactions.amount.sum()) ?? 0.0;
        if (subId != null) {
          expensesBySubcategory[subId] = total;
        }
      }
      return expensesBySubcategory;
    });
  }
}
