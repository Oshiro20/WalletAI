import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/savings_goals_table.dart';

part 'savings_goals_dao.g.dart';

@DriftAccessor(tables: [SavingsGoals])
class SavingsGoalsDao extends DatabaseAccessor<AppDatabase> with _$SavingsGoalsDaoMixin {
  SavingsGoalsDao(super.db);

  /// Obtener todas las metas de ahorro
  Future<List<SavingsGoal>> getAllGoals() {
    return select(savingsGoals).get();
  }

  /// Obtener metas activas (no completadas)
  Future<List<SavingsGoal>> getActiveGoals() {
    return (select(savingsGoals)..where((g) => g.isCompleted.equals(false))).get();
  }

  /// Obtener meta por ID
  Future<SavingsGoal?> getGoalById(String id) {
    return (select(savingsGoals)..where((g) => g.id.equals(id))).getSingleOrNull();
  }

  /// Crear meta
  Future<int> createGoal(SavingsGoalsCompanion goal) {
    return into(savingsGoals).insert(goal);
  }

  /// Actualizar meta
  Future<bool> updateGoal(SavingsGoal goal) {
    return update(savingsGoals).replace(goal);
  }

  /// Actualizar progreso de meta
  Future<int> updateGoalProgress(String goalId, double newAmount) {
    return (update(savingsGoals)..where((g) => g.id.equals(goalId)))
        .write(SavingsGoalsCompanion(
      currentAmount: Value(newAmount),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Marcar meta como completada
  Future<int> completeGoal(String goalId) {
    return (update(savingsGoals)..where((g) => g.id.equals(goalId)))
        .write(SavingsGoalsCompanion(
      isCompleted: const Value(true),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// Eliminar meta
  Future<int> deleteGoal(String goalId) {
    return (delete(savingsGoals)..where((g) => g.id.equals(goalId))).go();
  }

  /// Stream de metas activas
  Stream<List<SavingsGoal>> watchActiveGoals() {
    return (select(savingsGoals)..where((g) => g.isCompleted.equals(false))).watch();
  }
}
