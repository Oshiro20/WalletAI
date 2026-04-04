import 'package:drift/drift.dart';

/// Tabla de pagos recurrentes
@DataClassName('RecurringPayment')
class RecurringPayments extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  RealColumn get amount => real()();
  TextColumn get accountId => text()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get frequency => text()(); // daily, weekly, monthly, yearly
  DateTimeColumn get nextDueDate => dateTime()();
  IntColumn get reminderDays => integer().withDefault(const Constant(3))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
