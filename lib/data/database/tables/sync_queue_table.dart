import 'package:drift/drift.dart';

/// Tabla de cola de sincronización
@DataClassName('SyncQueueItem')
class SyncQueue extends Table {
  TextColumn get id => text()();
  TextColumn get operation => text()(); // insert, update, delete
  @override
  String get tableName => 'sync_queue';
  TextColumn get targetTable => text()();
  TextColumn get recordId => text()();
  TextColumn get data => text().nullable()(); // JSON
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
