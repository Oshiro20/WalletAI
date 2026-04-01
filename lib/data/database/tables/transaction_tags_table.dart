import 'package:drift/drift.dart';

/// Tabla de relación transacciones-etiquetas
@DataClassName('TransactionTag')
class TransactionTags extends Table {
  TextColumn get transactionId => text()();
  TextColumn get tagId => text()();
  
  @override
  Set<Column> get primaryKey => {transactionId, tagId};
}
