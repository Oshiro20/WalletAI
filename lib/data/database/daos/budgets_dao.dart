import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/budgets_table.dart';

part 'budgets_dao.g.dart';

@DriftAccessor(tables: [Budgets])
class BudgetsDao extends DatabaseAccessor<AppDatabase> with _$BudgetsDaoMixin {
  BudgetsDao(super.db);

  /// Obtener todos los presupuestos activos
  Future<List<Budget>> getActiveBudgets() {
    return (select(budgets)..where((b) => b.isActive.equals(true))).get();
  }

  /// Obtener presupuesto por categoría
  Future<Budget?> getBudgetByCategory(String categoryId) {
    return (select(budgets)..where(
          (b) => b.categoryId.equals(categoryId) & b.isActive.equals(true),
        ))
        .getSingleOrNull();
  }

  /// Crear presupuesto
  Future<int> createBudget(BudgetsCompanion budget) {
    return into(budgets).insert(budget);
  }

  /// Actualizar presupuesto
  Future<bool> updateBudget(Budget budget) {
    return update(budgets).replace(budget);
  }

  /// Eliminar presupuesto
  Future<int> deleteBudget(String budgetId) {
    return (delete(budgets)..where((b) => b.id.equals(budgetId))).go();
  }

  /// Stream de presupuestos activos
  Stream<List<Budget>> watchActiveBudgets() {
    return (select(budgets)..where((b) => b.isActive.equals(true))).watch();
  }
}
