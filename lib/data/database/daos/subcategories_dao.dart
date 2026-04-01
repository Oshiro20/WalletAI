import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/subcategories_table.dart';

part 'subcategories_dao.g.dart';

@DriftAccessor(tables: [Subcategories])
class SubcategoriesDao extends DatabaseAccessor<AppDatabase> with _$SubcategoriesDaoMixin {
  SubcategoriesDao(super.db);

  /// Obtener todas las subcategorías
  Future<List<Subcategory>> getAllSubcategories() => select(subcategories).get();

  /// Obtener subcategorías por categoría
  Future<List<Subcategory>> getSubcategoriesByCategoryId(String categoryId) {
    return (select(subcategories)
          ..where((t) => t.categoryId.equals(categoryId))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .get();
  }

  /// Stream de subcategorías por categoría
  Stream<List<Subcategory>> watchSubcategoriesByCategoryId(String categoryId) {
    return (select(subcategories)
          ..where((t) => t.categoryId.equals(categoryId))
          ..orderBy([(t) => OrderingTerm(expression: t.sortOrder)]))
        .watch();
  }

  /// Stream de todas las subcategorías
  Stream<List<Subcategory>> watchAllSubcategories() {
    return (select(subcategories)
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .watch();
  }

  /// Crear subcategoría
  Future<int> createSubcategory(SubcategoriesCompanion subcategory) {
    return attachedDatabase.transaction(() async {
      final id = await into(subcategories).insert(subcategory);
      
      // Sync Queue
      final insertedRow = await (select(subcategories)..where((s) => s.id.equals(subcategory.id.value))).getSingle();
      await into(attachedDatabase.syncQueue).insert(
        SyncQueueCompanion.insert(
          id: const Uuid().v4(),
          operation: 'insert',
          recordId: insertedRow.id,
          targetTable: 'subcategories',
          data: Value(jsonEncode(insertedRow.toJson())),
          createdAt: DateTime.now(),
        ),
      );
      
      return id;
    });
  }

  /// Insertar múltiples subcategorías (para seed)
  Future<void> insertAll(List<SubcategoriesCompanion> list) async {
    await batch((batch) {
      batch.insertAll(subcategories, list);
    });
  }

  /// Actualizar subcategoría
  Future<bool> updateSubcategory(Subcategory subcategory) {
    return attachedDatabase.transaction(() async {
      final result = await update(subcategories).replace(subcategory);
      
      if (result) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'update',
            recordId: subcategory.id,
            targetTable: 'subcategories',
            data: Value(jsonEncode(subcategory.toJson())),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }

  /// Eliminar subcategoría
  Future<int> deleteSubcategory(String subcategoryId) {
    return attachedDatabase.transaction(() async {
      final result = await (delete(subcategories)..where((s) => s.id.equals(subcategoryId))).go();
      
      if (result > 0) {
        await into(attachedDatabase.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: const Uuid().v4(),
            operation: 'delete',
            recordId: subcategoryId,
            targetTable: 'subcategories',
            data: const Value(null),
            createdAt: DateTime.now(),
          ),
        );
      }
      return result;
    });
  }
}
