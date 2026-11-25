import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/learning_rules_table.dart';

part 'learning_rules_dao.g.dart';

@DriftAccessor(tables: [LearningRules])
class LearningRulesDao extends DatabaseAccessor<AppDatabase>
    with _$LearningRulesDaoMixin {
  LearningRulesDao(super.db);

  static String _normalize(String raw) => raw
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll(RegExp(r'\s+'), ' ');

  /// Obtener la regla de clasificación histórica de un producto (insensible a mayúsculas/tildes)
  Future<LearningRule?> getRuleForProduct(String productName) async {
    final exact = await (select(
      learningRules,
    )..where((t) => t.productName.equals(productName))).getSingleOrNull();
    if (exact != null) return exact;

    final target = _normalize(productName);
    if (target.isEmpty) return null;
    final all = await getAllRules();
    for (final rule in all) {
      if (_normalize(rule.productName) == target) {
        return rule;
      }
    }
    return null;
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
