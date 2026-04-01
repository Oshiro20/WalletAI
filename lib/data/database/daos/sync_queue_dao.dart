import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/sync_queue_table.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase> with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Agregar item a la cola
  Future<int> addToQueue(SyncQueueCompanion item) {
    return into(syncQueue).insert(item);
  }

  /// Obtener items pendientes de sincronización
  Future<List<SyncQueueItem>> getPendingItems() {
    return (select(syncQueue)
          ..where((t) => t.synced.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
  }

  /// Marcar item como sincronizado
  Future<int> markAsSynced(String id) {
    return (update(syncQueue)..where((t) => t.id.equals(id))).write(
      SyncQueueCompanion(
        synced: const Value(true),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Eliminar items sincronizados antiguos (limpieza)
  Future<int> clearSyncedItems() {
    return (delete(syncQueue)..where((t) => t.synced.equals(true))).go();
  }
}
