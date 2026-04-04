import 'package:drift/drift.dart';

/// Tabla de etiquetas
@DataClassName('Tag')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 30)();
  TextColumn get color => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {name},
  ];
}
