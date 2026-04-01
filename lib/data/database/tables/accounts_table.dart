import 'package:drift/drift.dart';

/// Tabla de cuentas financieras
@DataClassName('Account')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get type => text()(); // wallet, bank, cash, investment, credit_card, savings
  TextColumn get institution => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  RealColumn get creditLimit => real().nullable()(); // para tarjetas de crédito
  IntColumn get closingDay => integer().nullable()(); // día de corte (1-31)
  IntColumn get paymentDueDay => integer().nullable()(); // día de pago (1-31)
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}
