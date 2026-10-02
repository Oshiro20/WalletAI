import 'package:drift/drift.dart';

/// Tabla para seguimiento de compras financiadas en cuotas con tarjeta de crédito
@DataClassName('CreditInstallment')
class CreditInstallments extends Table {
  TextColumn get id => text()();
  TextColumn get accountId => text()(); // ID de la tarjeta de crédito
  TextColumn get transactionId => text().nullable()(); // Transacción origen
  TextColumn get title => text().withLength(min: 1, max: 200)(); // Concepto o producto
  RealColumn get totalAmount => real()(); // Monto total financiado
  IntColumn get totalInstallments => integer()(); // Número total de cuotas (ej. 12)
  IntColumn get paidInstallments => integer().withDefault(const Constant(0))(); // Cuotas pagadas
  RealColumn get monthlyPayment => real()(); // Monto de la cuota mensual fija
  BoolColumn get hasInterest => boolean().withDefault(const Constant(false))(); // ¿Tiene intereses?
  RealColumn get tea => real().nullable()(); // Tasa Efectiva Anual pactada (%)
  RealColumn get totalInterest => real().withDefault(const Constant(0))(); // Interés total a pagar
  DateTimeColumn get purchaseDate => dateTime()(); // Fecha de compra
  DateTimeColumn get firstDueDate => dateTime()(); // Fecha de vencimiento de la primera cuota
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, completed, cancelled
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
