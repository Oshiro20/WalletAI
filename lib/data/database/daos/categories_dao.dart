import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/categories_table.dart';
import '../tables/subcategories_table.dart';

part 'categories_dao.g.dart';

@DriftAccessor(tables: [Categories, Subcategories])
class CategoriesDao extends DatabaseAccessor<AppDatabase> with _$CategoriesDaoMixin {
  CategoriesDao(super.db);

  /// Obtener todas las categorías
  Future<List<Category>> getAllCategories() {
    return (select(categories)
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  /// Obtener categorías por tipo (income, expense)
  Future<List<Category>> getCategoriesByType(String type) {
    return (select(categories)
          ..where((c) => c.type.equals(type))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .get();
  }

  /// Obtener categoría por ID
  Future<Category?> getCategoryById(String id) {
    return (select(categories)..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  /// Crear categoría
  Future<int> createCategory(CategoriesCompanion category) {
    return attachedDatabase.transaction(() async {
      final id = await into(categories).insert(category);
      
      // Sync Queue
      final insertedRow = await (select(categories)..where((c) => c.id.equals(category.id.value))).getSingle();
      await into(attachedDatabase.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'insert',
          recordId: insertedRow.id,
          targetTable: 'categories',
          data: Value(jsonEncode(insertedRow.toJson())),
          createdAt: DateTime.now(),
        ),
      );
      
      return id;
    });
  }

  /// Actualizar categoría
  Future<bool> updateCategory(Category category) {
    return attachedDatabase.transaction(() async {
      final result = await update(categories).replace(category);
      
      if (result) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'update',
            recordId: category.id,
            targetTable: 'categories',
            data: Value(jsonEncode(category.toJson())),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar categoría (solo si no es del sistema)
  Future<int> deleteCategory(String categoryId) {
    return attachedDatabase.transaction(() async {
      final result = await (delete(categories)
            ..where((c) => c.id.equals(categoryId) & c.isSystem.equals(false)))
          .go();
      
      if (result > 0) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: categoryId,
            targetTable: 'categories',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar TODAS las categorías (excepto sistema)
  Future<int> deleteAllCategories() {
    return attachedDatabase.transaction(() async {
      final rows = await (select(categories)..where((c) => c.isSystem.equals(false))).get();
      final result = await (delete(categories)..where((c) => c.isSystem.equals(false))).go();

      for (final row in rows) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: row.id,
            targetTable: 'categories',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar TODAS las subcategorías
  Future<int> deleteAllSubcategories() {
     return delete(subcategories).go();
     // Subcategorias no se sincronizan aun en syncQueue segun plan anterior, o si?
     // Revisando plan: "Support for Subcategories" fase 13.5. 
     // El syncQueueDao para subcategorias no parece estar implementado explicitamente en el plan original de sync.
     // Por simplicidad, asumimos borrado local. Si se require sync, se debe agregar.
  }

  /// Obtener subcategorías de una categoría
  Future<List<Subcategory>> getSubcategories(String categoryId) {
    return (select(subcategories)
          ..where((s) => s.categoryId.equals(categoryId))
          ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
        .get();
  }

  /// Crear subcategoría
  Future<int> createSubcategory(SubcategoriesCompanion subcategory) {
    return into(subcategories).insert(subcategory);
  }

  /// Actualizar subcategoría
  Future<bool> updateSubcategory(Subcategory subcategory) {
    return update(subcategories).replace(subcategory);
  }

  /// Eliminar subcategoría
  Future<int> deleteSubcategory(String subcategoryId) {
    return (delete(subcategories)..where((s) => s.id.equals(subcategoryId))).go();
  }

  /// Stream de categorías por tipo
  Stream<List<Category>> watchCategoriesByType(String type) {
    return (select(categories)
          ..where((c) => c.type.equals(type))
          ..orderBy([(c) => OrderingTerm(expression: c.sortOrder)]))
        .watch();
  }

  /// Stream de subcategorías
  Stream<List<Subcategory>> watchSubcategories(String categoryId) {
    return (select(subcategories)
          ..where((s) => s.categoryId.equals(categoryId))
          ..orderBy([(s) => OrderingTerm(expression: s.sortOrder)]))
        .watch();
  }
}
