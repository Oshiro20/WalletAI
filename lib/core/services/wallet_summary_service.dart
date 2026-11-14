import '../../data/database/drift_database.dart';
import 'ecosystem_sync_service.dart';

/// Exporta el resumen de WalletAI para el ecosistema (local + nube Render si hay sesión).
class WalletSummaryService {
  final AppDatabase _db;

  WalletSummaryService(this._db);

  /// Genera, guarda localmente y publica en Render el resumen enriquecido del mes actual.
  Future<void> exportSummary() async {
    await EcosystemSyncService.publishSummary(_db);
  }
}
