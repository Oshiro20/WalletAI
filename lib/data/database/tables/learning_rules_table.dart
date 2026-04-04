import 'package:drift/drift.dart';

/// Tabla para el aprendizaje persistente de categorías por producto
@DataClassName('LearningRule')
class LearningRules extends Table {
  TextColumn get productName => text()(); // Nombre normalizado del producto
  TextColumn get categoryId =>
      text()(); // Categoría asignada/corregida por el usuario
  IntColumn get usageCount =>
      integer().withDefault(const Constant(1))(); // Veces que se usó
  DateTimeColumn get lastUsed =>
      dateTime()(); // Última vez que se usó esta regla

  @override
  Set<Column> get primaryKey => {productName};
}
