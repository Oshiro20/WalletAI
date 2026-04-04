import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/recurring_payments_table.dart';

part 'recurring_payments_dao.g.dart';

@DriftAccessor(tables: [RecurringPayments])
class RecurringPaymentsDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringPaymentsDaoMixin {
  RecurringPaymentsDao(super.db);

  /// Obtener todos los pagos recurrentes activos
  Future<List<RecurringPayment>> getAllRecurringPayments() {
    return (select(recurringPayments)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.nextDueDate)]))
        .get();
  }

  /// Obtener pagos recurrentes próximos (ej. próximos 7 días)
  Future<List<RecurringPayment>> getUpcomingPayments(int daysAhead) {
    final limitDate = DateTime.now().add(Duration(days: daysAhead));
    return (select(recurringPayments)
          ..where(
            (t) =>
                t.isActive.equals(true) &
                t.nextDueDate.isSmallerOrEqualValue(limitDate),
          )
          ..orderBy([(t) => OrderingTerm(expression: t.nextDueDate)]))
        .get();
  }

  /// Crear pago recurrente
  Future<int> createRecurringPayment(RecurringPaymentsCompanion payment) {
    return attachedDatabase.transaction(() async {
      final id = await into(recurringPayments).insert(payment);

      // Sync Queue
      final insertedRow = await (select(
        recurringPayments,
      )..where((t) => t.id.equals(payment.id.value))).getSingle();
      await into(attachedDatabase.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'insert',
          recordId: insertedRow.id,
          targetTable: 'recurring_payments',
          data: Value(jsonEncode(insertedRow.toJson())),
          createdAt: DateTime.now(),
        ),
      );

      return id;
    });
  }

  /// Actualizar pago recurrente
  Future<bool> updateRecurringPayment(RecurringPayment payment) {
    return attachedDatabase.transaction(() async {
      final result = await update(recurringPayments).replace(payment);

      if (result) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'update',
            recordId: payment.id,
            targetTable: 'recurring_payments',
            data: Value(jsonEncode(payment.toJson())),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Desactivar pago recurrente
  Future<void> deactivateRecurringPayment(String id) {
    return attachedDatabase.transaction(() async {
      final result =
          await (update(recurringPayments)..where((t) => t.id.equals(id)))
              .write(RecurringPaymentsCompanion(isActive: const Value(false)));

      if (result > 0) {
        final updatedRow = await (select(
          recurringPayments,
        )..where((t) => t.id.equals(id))).getSingle();
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'update',
            recordId: id,
            targetTable: 'recurring_payments',
            data: Value(jsonEncode(updatedRow.toJson())),
            createdAt: DateTime.now(),
          ),
        );
      }
    });
  }

  /// Eliminar pago recurrente
  Future<int> deleteRecurringPayment(String id) {
    return attachedDatabase.transaction(() async {
      final result = await (delete(
        recurringPayments,
      )..where((t) => t.id.equals(id))).go();

      if (result > 0) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: id,
            targetTable: 'recurring_payments',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar TODOS los pagos recurrentes
  Future<int> deleteAllRecurringPayments() {
    return attachedDatabase.transaction(() async {
      final ids = await (select(recurringPayments).map((t) => t.id)).get();
      final result = await delete(recurringPayments).go();

      for (final id in ids) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: id,
            targetTable: 'recurring_payments',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Stream de pagos recurrentes
  Stream<List<RecurringPayment>> watchAllRecurringPayments() {
    return (select(recurringPayments)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.nextDueDate)]))
        .watch();
  }
}
