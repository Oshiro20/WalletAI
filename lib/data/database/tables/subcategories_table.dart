import 'package:drift/drift.dart';

/// Tabla de subcategorías
@DataClassName('Subcategory')
class Subcategories extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}
