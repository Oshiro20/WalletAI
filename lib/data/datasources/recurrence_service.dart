import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/utils/credit_card_calculator.dart';
import '../../presentation/providers/database_providers.dart';
import '../../presentation/providers/transaction_repository_provider.dart';
import '../database/drift_database.dart';
import '../database/daos/recurring_payments_dao.dart';
import 'notification_service.dart';

class RecurrenceService {
  final Ref ref;
  bool _isRunning = false;

  RecurrenceService(this.ref);

  /// Verificar y procesar pagos vencidos. Retorna los nombres aplicados.
  Future<List<String>> checkDuePayments() async {
    if (_isRunning) return const [];
    _isRunning = true;
    final executed = <String>[];
    try {
      final dao = ref.read(recurringPaymentsDaoProvider);
      final now = DateTime.now();

      // Obtener pagos activos que vencen hoy o antes
      final duePayments =
          await (dao.select(dao.recurringPayments)..where(
                (t) =>
                    t.isActive.equals(true) &
                    t.nextDueDate.isSmallerOrEqualValue(now),
              ))
              .get();

      for (final payment in duePayments) {
        await _processPayment(payment, dao);
        executed.add('${payment.name} (S/ ${payment.amount.toStringAsFixed(2)})');
      }

      if (executed.isNotEmpty) {
        await NotificationService().notifyRecurringExecuted(executed);
      }
    } finally {
      _isRunning = false;
    }
    return executed;
  }

  /// Procesar un pago individual actualizando saldos mediante TransactionRepository
  Future<void> _processPayment(
    RecurringPayment payment,
    RecurringPaymentsDao recurringDao,
  ) async {
    final db = ref.read(databaseProvider);
    final repository = ref.read(transactionRepositoryProvider);
    final account = await db.accountsDao.getAccountById(payment.accountId);
    final currency = account?.currency ?? 'PEN';

    // Detectar si la categoría corresponde a un ingreso o gasto
    String txType = 'expense';
    if (payment.categoryId != null) {
      final cat = await (db.select(db.categories)
            ..where((c) => c.id.equals(payment.categoryId!)))
          .getSingleOrNull();
      if (cat != null && cat.type == 'income') {
        txType = 'income';
      }
    }

    final now = DateTime.now();
    // 1. Crear transacción y actualizar saldo de cuenta atómicamente
    await repository.addTransaction(
      transaction: TransactionsCompanion.insert(
        id: const Uuid().v4(),
        amount: payment.amount,
        type: txType,
        categoryId: Value(payment.categoryId),
        accountId: payment.accountId,
        date: now,
        description: Value('Pago recurrente: ${payment.name}'),
        currency: Value(currency),
        isRecurring: const Value(true),
        recurringPaymentId: Value(payment.id),
        createdAt: now,
        updatedAt: now,
      ),
      accountId: payment.accountId,
      amount: payment.amount,
      type: txType,
    );

    // 2. Calcular próxima fecha de vencimiento (segura para fin de mes)
    var nextDate = _calculateNextDate(payment.nextDueDate, payment.frequency);
    while (!nextDate.isAfter(now)) {
      nextDate = _calculateNextDate(nextDate, payment.frequency);
    }

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
        return CreditCardCalculator.addMonthsToDay(current, 1, current.day);
      case 'yearly':
        return CreditCardCalculator.addMonthsToDay(current, 12, current.day);
      default:
        return current.add(const Duration(days: 1));
    }
  }
}

final recurrenceServiceProvider = Provider((ref) => RecurrenceService(ref));
