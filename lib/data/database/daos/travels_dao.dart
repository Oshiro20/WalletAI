import 'package:drift/drift.dart';
import '../drift_database.dart';
import '../tables/travels_table.dart';

part 'travels_dao.g.dart';

@DriftAccessor(tables: [Travels])
class TravelsDao extends DatabaseAccessor<AppDatabase> with _$TravelsDaoMixin {
  TravelsDao(super.db);

  /// Obtener todos los viajes
  Future<List<Travel>> getAllTravels() => select(travels).get();

  /// Observar todos los viajes (Stream)
  Stream<List<Travel>> watchAllTravels() {
    return (select(travels)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  /// Observar el viaje activo actualmente (si lo hay)
  Stream<Travel?> watchActiveTravel() {
    return (select(travels)..where((t) => t.isActive.equals(true))..limit(1)).watchSingleOrNull();
  }

  /// Obtener un viaje específico
  Future<Travel?> getTravelById(String id) {
    return (select(travels)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insertar un nuevo viaje
  Future<int> insertTravel(TravelsCompanion travel) => into(travels).insert(travel);

  /// Actualizar un viaje
  Future<bool> updateTravel(TravelsCompanion travel) => update(travels).replace(travel);

  /// Eliminar un viaje
  Future<int> deleteTravel(String id) {
    return (delete(travels)..where((t) => t.id.equals(id))).go();
  }

  /// Activar un viaje (y desactivar los demás)
  Future<void> setActiveTravel(String id) async {
    return transaction(() async {
      // 1. Desactivar todos
      await update(travels).write(const TravelsCompanion(isActive: Value(false)));
      // 2. Activar el seleccionado
      await (update(travels)..where((t) => t.id.equals(id)))
          .write(const TravelsCompanion(isActive: Value(true)));
    });
  }

  /// Desactivar todos los viajes
  Future<void> deactivateAllTravels() async {
    await update(travels).write(const TravelsCompanion(isActive: Value(false)));
  }
}
