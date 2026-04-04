import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/learning_rules_table.dart';

part 'learning_rules_dao.g.dart';

@DriftAccessor(tables: [LearningRules])
class LearningRulesDao extends DatabaseAccessor<AppDatabase>
    with _$LearningRulesDaoMixin {
  LearningRulesDao(super.db);

  /// Obtener la regla de clasificación histórica de un producto por su nombre
  Future<LearningRule?> getRuleForProduct(String productName) {
    return (select(
      learningRules,
    )..where((t) => t.productName.equals(productName))).getSingleOrNull();
  }

  /// Registrar o actualizar una regla de aprendizaje
  Future<void> saveRule(String productName, String categoryId) async {
    final existingRule = await getRuleForProduct(productName);
    if (existingRule != null) {
      // Si el usuario vuelve a clasificarlo, se actualiza el count y la fecha
      // Si cambió de categoría, la sobrescribimos y reseteamos el count (u optamos por solo actualizar).
      // Optaremos por actualizar la categoría siempre al último deseo del usuario.
      int newUsageCount = existingRule.categoryId == categoryId
          ? existingRule.usageCount + 1
          : 1;

      await update(learningRules).replace(
        existingRule.copyWith(
          categoryId: categoryId,
          usageCount: newUsageCount,
          lastUsed: DateTime.now(),
        ),
      );
    } else {
      await into(learningRules).insert(
        LearningRulesCompanion.insert(
          productName: productName,
          categoryId: categoryId,
          usageCount: const Value(1),
          lastUsed: DateTime.now(),
        ),
      );
    }
  }

  /// Obtener todas las reglas (para debug o ajustes)
  Future<List<LearningRule>> getAllRules() {
    return (select(
      learningRules,
    )..orderBy([(t) => OrderingTerm.desc(t.lastUsed)])).get();
  }

  /// Eliminar una regla
  Future<void> deleteRule(String productName) {
    return (delete(
      learningRules,
    )..where((t) => t.productName.equals(productName))).go();
  }
}
