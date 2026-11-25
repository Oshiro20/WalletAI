import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../database/drift_database.dart';
import 'backup_service.dart';
import 'cloud_account_service.dart';
import 'notification_service.dart';

const String syncTaskKey = 'com.walletai.autosync.backup';
const String alertsTaskKey = 'com.walletai.background.alerts';
const String kAutoSyncEnabledKey = 'auto_sync_enabled';
const String kAutoSyncFrequencyKey = 'auto_sync_frequency';
const String kAutoSyncDestinationKey = 'auto_sync_destination';
const String kAutoSyncLastStatusKey = 'auto_sync_last_status';
const String kAutoSyncLastTimeKey = 'auto_sync_last_time';

/// Destinos válidos para respaldo automático:
/// - `cloud`: Cuenta WalletAI (Usuario/Contraseña)
/// - `drive`: Google Drive
/// - `local`: Carpeta Local persistente
/// - `cloud_and_local`: Nube WalletAI + Local
/// - `drive_and_local`: Google Drive + Local
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();

    if (task == alertsTaskKey) {
      AppDatabase? bgDb;
      try {
        bgDb = AppDatabase();
        final notificationService = NotificationService();
        await notificationService.initialize();
        await notificationService.rescheduleIfEnabled();

        final accounts = await bgDb.accountsDao.getAllAccounts();
        await notificationService.checkCreditCardDueDates(
          accounts,
          transactionsDao: bgDb.transactionsDao,
        );

        final recurring = await bgDb.recurringPaymentsDao
            .getAllRecurringPayments();
        await notificationService.scheduleRecurringPaymentReminders(recurring);

        debugPrint('[BackgroundAlerts] Alertas financieras sincronizadas OK');
        return Future.value(true);
      } catch (e) {
        debugPrint('[BackgroundAlerts] Error: $e');
        return Future.value(false);
      } finally {
        await bgDb?.close();
      }
    }

    if (task != syncTaskKey) return Future.value(true);

    AppDatabase? bgDb;
    try {
      final prefs = await SharedPreferences.getInstance();
      final destination = prefs.getString(kAutoSyncDestinationKey) ?? 'drive';
      bgDb = AppDatabase();

      final outcomes = <String>[];
      bool allOk = true;

      if (destination == 'cloud' || destination == 'cloud_and_local') {
        final res = await CloudAccountService.uploadUnifiedBackup(
          activeDb: bgDb,
        );
        if (!res.success) allOk = false;
        outcomes.add(res.hasConflict ? 'Conflicto en nube' : res.message);
      }

      if (destination == 'drive' || destination == 'drive_and_local') {
        final user = await BackupService.getSignedInUser();
        if (user != null) {
          final res = await BackupService.backupToDrive(activeDb: bgDb);
          if (!res.success) allOk = false;
          outcomes.add(res.success ? 'Drive OK' : res.message);
        } else {
          allOk = false;
          outcomes.add('Drive sin sesión activa');
        }
      }

      if (destination == 'local' ||
          destination == 'cloud_and_local' ||
          destination == 'drive_and_local') {
        final res = await BackupService.backupLocally(activeDb: bgDb);
        if (!res.success) allOk = false;
        outcomes.add(res.success ? 'Local OK' : res.message);
      }

      await prefs.setString(
        kAutoSyncLastTimeKey,
        DateTime.now().toIso8601String(),
      );
      await prefs.setString(
        kAutoSyncLastStatusKey,
        outcomes.isEmpty ? 'Sin destino' : outcomes.join(' | '),
      );

      debugPrint('AutoSync [$destination]: $outcomes');
      return Future.value(allOk);
    } catch (e) {
      debugPrint('AutoSync error: $e');
      return Future.value(false);
    } finally {
      await bgDb?.close();
    }
  });
}

class AutoSyncService {
  static final AutoSyncService _instance = AutoSyncService._internal();
  factory AutoSyncService() => _instance;
  AutoSyncService._internal();

  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// Registra una tarea periódica ligera cada 12h para revisar tarjetas por vencer
  /// y pagos recurrentes incluso cuando el usuario no abre WalletAI.
  Future<void> registerBackgroundAlertsTask() async {
    await Workmanager().registerPeriodicTask(
      'wallet_ai_background_alerts_id',
      alertsTaskKey,
      frequency: const Duration(hours: 12),
      constraints: Constraints(networkType: NetworkType.notRequired),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> registerPeriodicTask({
    Duration frequency = const Duration(hours: 24),
    String destination = 'cloud',
  }) async {
    final requiresNetwork = destination != 'local';
    await Workmanager().registerPeriodicTask(
      'wallet_ai_auto_backup_id',
      syncTaskKey,
      frequency: frequency,
      constraints: Constraints(
        networkType: requiresNetwork
            ? NetworkType.connected
            : NetworkType.notRequired,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName('wallet_ai_auto_backup_id');
  }
}
