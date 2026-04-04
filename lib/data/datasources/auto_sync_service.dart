import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'backup_service.dart';

const String simplePeriodicTask = "simplePeriodicTask";
const String syncTaskKey = "com.walletai.sync_task";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == syncTaskKey) {
        // Verificar si hay usuario logueado (silenciosamente)
        final user = await BackupService.getSignedInUser();
        if (user != null) {
          // Intentar backup
          final result = await BackupService.backupToDrive();
          if (result.success) {
            debugPrint("AutoSync: Éxito - ${result.message}");
          } else {
            debugPrint("AutoSync: Falló - ${result.message}");
            return Future.value(false); // Reintentar si falló
          }
        } else {
          debugPrint("AutoSync: No hay usuario logueado. Omitiendo.");
        }
      }
    } catch (e) {
      debugPrint("AutoSync: Error crítico - $e");
      return Future.value(false);
    }
    return Future.value(true);
  });
}

class AutoSyncService {
  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  Future<void> registerPeriodicTask({
    Duration frequency = const Duration(hours: 24),
  }) async {
    // Cancelar tarea previa para asegurar nueva frecuencia
    await cancelTask();

    await Workmanager().registerPeriodicTask(
      syncTaskKey,
      syncTaskKey,
      frequency: frequency,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
    );
    debugPrint(
      "AutoSync: Tarea registrada con frecuencia ${frequency.inHours} horas",
    );
  }

  Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName(syncTaskKey);
    debugPrint("AutoSync: Tarea cancelada");
  }
}
