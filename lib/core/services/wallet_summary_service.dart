import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:package_info_plus/package_info_plus.dart';
import '../../data/database/drift_database.dart';

/// Exporta un resumen mínimo de WalletAI para que MyLifeOS lo consuma.
/// Escribe [wallet_summary.json] en getApplicationDocumentsDirectory().
class WalletSummaryService {
  final AppDatabase _db;

  WalletSummaryService(this._db);

  /// Genera y escribe el resumen del mes actual.
  Future<void> exportSummary() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final income = await _db.transactionsDao.getTotalIncome(startOfMonth, endOfMonth);
      final expenses = await _db.transactionsDao.getTotalExpenses(startOfMonth, endOfMonth);
      final balance = income - expenses;
      final packageInfo = await PackageInfo.fromPlatform();

      final summary = {
        'version': packageInfo.version,
        'build': packageInfo.buildNumber,
        'exportedAt': now.toIso8601String(),
        'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
        'balance': balance,
        'income': income,
        'expenses': expenses,
        'currency': 'PEN', // ajusta según tu configuración
      };

      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'wallet_summary.json'));
      await file.writeAsString(jsonEncode(summary));
    } catch (_) {
      // Silencioso — no interrumpir el flujo principal de WalletAI
    }
  }
}
