import 'package:drift/drift.dart';

/// Tabla de adjuntos (fotos de boletas, PDFs, etc.)
@DataClassName('Attachment')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text()();
  TextColumn get filePath => text()();
  TextColumn get fileType => text()(); // image/jpeg, application/pdf
  IntColumn get fileSize => integer()(); // bytes
  DateTimeColumn get createdAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}
