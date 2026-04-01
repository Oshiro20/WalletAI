import 'package:drift/drift.dart';

@DataClassName('Travel')
class Travels extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // Ej: "Viaje a Colombia"
  RealColumn get budget => real().withDefault(const Constant(0.0))();
  TextColumn get baseCurrency => text().withDefault(const Constant('PEN'))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  
  @override
  Set<Column> get primaryKey => {id};
}
