import 'package:drift/drift.dart';

/// Tabla de transacciones
@DataClassName('Transaction')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()();
  TextColumn get destinationAccountId => text().nullable()(); // para transferencias
  TextColumn get type => text()(); // 'income', 'expense', 'transfer'
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  RealColumn get amount => real()();
  TextColumn get categoryId => text().nullable()();
  TextColumn get subcategoryId => text().nullable()();
  TextColumn get productName => text().nullable()(); // nombre del producto/item comprado
  TextColumn get description => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get recurringPaymentId => text().nullable()();
  TextColumn get contextId => text().nullable()(); // para modo viaje
  RealColumn get quantity => real().nullable()(); // cantidad (ej: 1, 1.5, 4)
  TextColumn get unit => text().nullable()(); // unidad (ej: KG, UND, LTR)
  // ── GPS ──────────────────────────────────────────────────────────────
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get locationName => text().nullable()();
  // ─────────────────────────────────────────────────────────────────────
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}

