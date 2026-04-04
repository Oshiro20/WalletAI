import 'package:drift/drift.dart';

/// Tabla de presupuestos
@DataClassName('Budget')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  RealColumn get amount => real()();
  TextColumn get period => text()(); // monthly, weekly, yearly
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
