import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../presentation/providers/database_providers.dart';
import '../database/drift_database.dart';
import '../database/daos/transactions_dao.dart';
import '../database/daos/recurring_payments_dao.dart';

class RecurrenceService {
  final Ref ref;

  RecurrenceService(this.ref);

  /// Verificar y procesar pagos vencidos
  Future<void> checkDuePayments() async {
    final dao = ref.read(recurringPaymentsDaoProvider);
    final transactionsDao = ref.read(transactionsDaoProvider);
    final now = DateTime.now();

    // Obtener pagos activos que vencen hoy o antes
    final duePayments = await (dao.select(dao.recurringPayments)
      ..where((t) => 
        t.isActive.equals(true) & 
        t.nextDueDate.isSmallerOrEqualValue(now)
      ))
      .get();

    for (final payment in duePayments) {
      await _processPayment(payment, transactionsDao, dao);
    }
  }

  /// Procesar un pago individual
  Future<void> _processPayment(
    RecurringPayment payment, 
    TransactionsDao transactionsDao,
    RecurringPaymentsDao recurringDao,
  ) async {
    // 1. Crear transacción
    await transactionsDao.createTransaction(
      TransactionsCompanion.insert(
        id: const Uuid().v4(),
        amount: payment.amount,
        type: 'expense', // Asumimos gasto por ahora, idealmente agregar campo 'type' a RecurringPayments
        categoryId: Value(payment.categoryId),
        accountId: payment.accountId,

        date: DateTime.now(),
        description: Value('Pago recurrente: ${payment.name}'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // 2. Calcular próxima fecha de vencimiento
    final nextDate = _calculateNextDate(payment.nextDueDate, payment.frequency);

    // 3. Actualizar pago recurrente
    await recurringDao.updateRecurringPayment(
      payment.copyWith(nextDueDate: nextDate),
    );
  }

  DateTime _calculateNextDate(DateTime current, String frequency) {
    switch (frequency) {
      case 'daily':
        return current.add(const Duration(days: 1));
      case 'weekly':
        return current.add(const Duration(days: 7));
      case 'monthly':
        // Manejo básico de meses (puede requerir lógica más robusta para días 31)
        return DateTime(current.year, current.month + 1, current.day);
      case 'yearly':
        return DateTime(current.year + 1, current.month, current.day);
      default:
        return current.add(const Duration(days: 1));
    }
  }
}

final recurrenceServiceProvider = Provider((ref) => RecurrenceService(ref));
