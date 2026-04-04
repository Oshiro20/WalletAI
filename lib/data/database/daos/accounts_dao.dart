import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  /// Obtener todas las cuentas activas
  Future<List<Account>> getAllAccounts() {
    return (select(accounts)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
        .get();
  }

  /// Obtener cuenta por ID
  Future<Account?> getAccountById(String id) {
    return (select(accounts)..where((a) => a.id.equals(id))).getSingleOrNull();
  }

  /// Obtener cuentas por tipo
  Future<List<Account>> getAccountsByType(String type) {
    return (select(accounts)
          ..where((a) => a.type.equals(type) & a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
        .get();
  }

  /// Crear cuenta
  Future<int> createAccount(AccountsCompanion account) {
    return attachedDatabase.transaction(() async {
      final id = await into(accounts).insert(account);

      // Sync Queue
      final insertedRow = await (select(
        accounts,
      )..where((a) => a.id.equals(account.id.value))).getSingle();
      await into(attachedDatabase.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'insert',
          recordId: insertedRow.id,
          targetTable: 'accounts',
          data: Value(jsonEncode(insertedRow.toJson())),
          createdAt: DateTime.now(),
        ),
      );

      return id;
    });
  }

  /// Actualizar cuenta
  Future<bool> updateAccount(Account account) {
    return attachedDatabase.transaction(() async {
      final result = await update(accounts).replace(account);

      if (result) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'update',
            recordId: account.id,
            targetTable: 'accounts',
            data: Value(jsonEncode(account.toJson())),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Actualizar saldo de cuenta
  Future<int> updateBalance(String accountId, double newBalance) {
    return attachedDatabase.transaction(() async {
      final result =
          await (update(accounts)..where((a) => a.id.equals(accountId))).write(
            AccountsCompanion(
              balance: Value(newBalance),
              updatedAt: Value(DateTime.now()),
            ),
          );

      if (result > 0) {
        final updatedRow = await (select(
          accounts,
        )..where((a) => a.id.equals(accountId))).getSingle();
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'update',
            recordId: accountId,
            targetTable: 'accounts',
            data: Value(jsonEncode(updatedRow.toJson())),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  // Alias for compatibility with ExcelService
  Future<int> updateAccountBalance(String accountId, double newBalance) =>
      updateBalance(accountId, newBalance);

  /// Soft delete (marcar como inactiva)
  Future<int> deactivateAccount(String accountId) {
    return attachedDatabase.transaction(() async {
      final result =
          await (update(accounts)..where((a) => a.id.equals(accountId))).write(
            AccountsCompanion(
              isActive: const Value(false),
              updatedAt: Value(DateTime.now()),
            ),
          );

      if (result > 0) {
        final updatedRow = await (select(
          accounts,
        )..where((a) => a.id.equals(accountId))).getSingle();
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'update',
            recordId: accountId,
            targetTable: 'accounts',
            data: Value(jsonEncode(updatedRow.toJson())),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar cuenta permanentemente
  Future<int> deleteAccount(String accountId) {
    return attachedDatabase.transaction(() async {
      // 1. Borrar transacciones vinculadas (como origen o destino)
      await (delete(attachedDatabase.transactions)..where(
            (t) =>
                t.accountId.equals(accountId) |
                t.destinationAccountId.equals(accountId),
          ))
          .go();

      // 2. Borrar pagos recurrentes vinculados
      await (delete(
        attachedDatabase.recurringPayments,
      )..where((r) => r.accountId.equals(accountId))).go();

      // 3. Borrar la cuenta
      final result = await (delete(
        accounts,
      )..where((a) => a.id.equals(accountId))).go();

      if (result > 0) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: accountId,
            targetTable: 'accounts',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar TODAS las cuentas
  Future<int> deleteAllAccounts() {
    return attachedDatabase.transaction(() async {
      // 1. Borrar todas las transacciones
      await delete(attachedDatabase.transactions).go();

      // 2. Borrar todos los pagos recurrentes
      await delete(attachedDatabase.recurringPayments).go();

      // 3. Borrar las cuentas
      final ids = await (select(accounts).map((a) => a.id)).get();
      final result = await delete(accounts).go();

      for (final id in ids) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: id,
            targetTable: 'accounts',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Obtener balance total de todas las cuentas
  Future<double> getTotalBalance() async {
    final query = selectOnly(accounts)
      ..addColumns([accounts.balance.sum()])
      ..where(accounts.isActive.equals(true));

    final result = await query.getSingleOrNull();
    return result?.read(accounts.balance.sum()) ?? 0.0;
  }

  /// Obtener balance por tipo de cuenta
  Future<double> getBalanceByType(String type) async {
    final query = selectOnly(accounts)
      ..addColumns([accounts.balance.sum()])
      ..where(accounts.type.equals(type) & accounts.isActive.equals(true));

    final result = await query.getSingleOrNull();
    return result?.read(accounts.balance.sum()) ?? 0.0;
  }

  /// Stream de todas las cuentas (para UI reactiva)
  Stream<List<Account>> watchAllAccounts() {
    return (select(accounts)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm(expression: a.sortOrder)]))
        .watch();
  }

  /// Stream de cuenta específica
  Stream<Account?> watchAccount(String accountId) {
    return (select(
      accounts,
    )..where((a) => a.id.equals(accountId))).watchSingleOrNull();
  }
}
