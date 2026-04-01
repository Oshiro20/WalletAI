import 'package:drift/drift.dart';

/// Tabla de categorías
@DataClassName('Category')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()(); // income, expense
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  /// Alias separados por coma para reconocimiento de voz (ej: "angie,novia,pareja")
  /// Opcional, no se muestra en la UI principal
  TextColumn get aliases => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}
