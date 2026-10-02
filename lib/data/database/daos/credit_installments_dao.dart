import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/credit_installments_table.dart';

part 'credit_installments_dao.g.dart';

@DriftAccessor(tables: [CreditInstallments])
class CreditInstallmentsDao extends DatabaseAccessor<AppDatabase>
    with _$CreditInstallmentsDaoMixin {
  CreditInstallmentsDao(super.db);

  /// Obtener todas las compras en cuotas
  Future<List<CreditInstallment>> getAllInstallments() =>
      select(creditInstallments).get();

  /// Observar cuotas activas de una cuenta (tarjeta) específica
  Stream<List<CreditInstallment>> watchInstallmentsByAccount(String accountId) {
    return (select(creditInstallments)
          ..where((c) => c.accountId.equals(accountId))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .watch();
  }

  /// Observar todas las cuotas activas del sistema
  Stream<List<CreditInstallment>> watchActiveInstallments() {
    return (select(creditInstallments)
          ..where((c) => c.status.equals('active'))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .watch();
  }

  /// Obtener cuota por ID
  Future<CreditInstallment?> getInstallmentById(String id) {
    return (select(creditInstallments)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insertar una nueva compra en cuotas
  Future<int> insertInstallment(CreditInstallmentsCompanion installment) =>
      into(creditInstallments).insert(installment);

  /// Actualizar compra en cuotas
  Future<bool> updateInstallment(CreditInstallmentsCompanion installment) =>
      update(creditInstallments).replace(installment);

  /// Eliminar compra en cuotas
  Future<int> deleteInstallment(String id) {
    return (delete(creditInstallments)..where((c) => c.id.equals(id))).go();
  }

  /// Incrementar cuotas pagadas
  Future<void> incrementPaidInstallments(String id) async {
    final item = await getInstallmentById(id);
    if (item == null) return;

    final newPaid = item.paidInstallments + 1;
    final isFinished = newPaid >= item.totalInstallments;

    await (update(creditInstallments)..where((c) => c.id.equals(id))).write(
      CreditInstallmentsCompanion(
        paidInstallments: Value(newPaid),
        status: Value(isFinished ? 'completed' : 'active'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
