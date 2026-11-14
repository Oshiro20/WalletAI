import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../data/database/drift_database.dart';
import '../../data/datasources/cloud_account_service.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../config/app_config.dart';
import 'mylifeos_integration_service.dart';

/// Servicio unificado de sincronización de ecosistema (WalletAI <-> MyLifeOS).
///
/// Reemplaza las exportaciones duplicadas y agrega:
/// 1. Resumen enriquecido (totales, categorías, gastos semanales y últimos movimientos).
/// 2. Publicación segura al backend en Render (`/api/ecosystem/summary`).
/// 3. Importación de gastos pendientes enviados desde MyLifeOS (`/api/ecosystem/pending-transactions`).
/// 4. Receptor nativo de deep links (`walletai://...`) desde Android.
class EcosystemSyncService {
  static const _channel = MethodChannel('walletai/deep_links');
  static bool _channelRegistered = false;

  /// Registra el listener nativo para deep links `walletai://...`.
  static void initDeepLinkListener({
    required AppDatabase db,
    required GoRouter router,
    VoidCallback? onSynced,
  }) {
    if (_channelRegistered) return;
    _channelRegistered = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewIntentLink') {
        final raw = call.arguments as String?;
        if (raw != null && raw.isNotEmpty) {
          await handleDeepLink(
            Uri.parse(raw),
            db: db,
            router: router,
            onSynced: onSynced,
          );
        }
      }
    });

    Future.microtask(() async {
      try {
        final initial = await _channel.invokeMethod<String>('getInitialLink');
        if (initial != null && initial.isNotEmpty) {
          await handleDeepLink(
            Uri.parse(initial),
            db: db,
            router: router,
            onSynced: onSynced,
          );
        }
      } catch (e) {
        debugPrint('[EcosystemSync] getInitialLink skipped: $e');
      }
    });
  }

  /// Procesa un URI entrante `walletai://...`.
  static Future<void> handleDeepLink(
    Uri uri, {
    required AppDatabase db,
    required GoRouter router,
    VoidCallback? onSynced,
  }) async {
    debugPrint('[EcosystemSync] Deep link recibido: $uri');
    final params = uri.queryParameters;

    final projectId = params['projectId'];
    if (projectId != null && projectId.isNotEmpty) {
      await MyLifeOSIntegrationService.setMyLifeOSProjectId(projectId);
    }

    final contextParam = params['context'];
    final host = uri.host;

    if (host == 'quick-expense' ||
        contextParam == 'quick-expense' ||
        contextParam == 'expense') {
      final amount = double.tryParse(params['amount'] ?? '');
      router.push(
        '/transactions/create',
        extra: {
          'type': params['type'] ?? 'expense',
          if (amount != null) 'amount': amount,
          if (params['description'] != null)
            'description': params['description'],
          if (params['productName'] != null)
            'productName': params['productName'],
        },
      );
      return;
    }

    if (contextParam == 'scan-receipt' || host == 'scan-receipt') {
      router.push('/scan-receipt');
      return;
    }

    // Por defecto o context=sync: importar pendientes y publicar resumen actualizado
    await importAllPendingTransactions(db);
    await publishSummary(db);
    onSynced?.call();
  }

  /// Construye un resumen mensual completo y enriquecido directamente desde Drift.
  static Future<Map<String, dynamic>> buildRichSummary(AppDatabase db) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final income = await db.transactionsDao.getTotalIncome(
      startOfMonth,
      endOfMonth,
    );
    final expenses = await db.transactionsDao.getTotalExpenses(
      startOfMonth,
      endOfMonth,
    );
    final balance = income - expenses;

    final categories = await db.categoriesDao.getAllCategories();
    final categoryMap = {for (final c in categories) c.id: c};

    // Gastos por categoría del mes
    final catTotals = await db.transactionsDao.getExpensesByCategory(
      startOfMonth,
      endOfMonth,
    );
    final byCategory = catTotals.entries.map((entry) {
      final cat = categoryMap[entry.key];
      final pct = expenses > 0 ? (entry.value / expenses) * 100.0 : 0.0;
      return {
        'id': entry.key,
        'name': cat?.name ?? 'Otros',
        'icon': cat?.icon ?? '💸',
        'amount': entry.value,
        'percentage': double.parse(pct.toStringAsFixed(1)),
      };
    }).toList()
      ..sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
      );

    // Gastos diarios de la semana actual (Lunes=0 .. Domingo=6)
    final todayStart = DateTime(now.year, now.month, now.day);
    final monday = todayStart.subtract(Duration(days: now.weekday - 1));
    final sundayEnd = monday.add(
      const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
    );
    final weekTxs = await db.transactionsDao.getTransactionsByDateRange(
      monday,
      sundayEnd,
    );
    final weeklyExpenses = List<double>.filled(7, 0.0);
    for (final tx in weekTxs) {
      if (tx.type == 'expense') {
        final idx = (tx.date.weekday - 1).clamp(0, 6);
        weeklyExpenses[idx] += tx.amount;
      }
    }

    // Últimos movimientos del mes para análisis IA en MyLifeOS
    final monthTxs = await db.transactionsDao.getTransactionsByDateRange(
      startOfMonth,
      endOfMonth,
    );
    final recentTransactions = monthTxs
        .where((tx) => tx.type == 'expense' || tx.type == 'income')
        .take(15)
        .map((tx) {
          final cat = tx.categoryId != null
              ? categoryMap[tx.categoryId]
              : null;
          return {
            'id': tx.id,
            'name':
                tx.description?.trim().isNotEmpty == true
                    ? tx.description!
                    : (tx.productName?.trim().isNotEmpty == true
                          ? tx.productName!
                          : (cat?.name ?? 'Movimiento')),
            'category': cat?.name ?? 'General',
            'amount': tx.type == 'expense' ? -tx.amount : tx.amount,
            'type': tx.type,
            'currency': tx.currency,
            'date': tx.date.toIso8601String().split('T').first,
          };
        })
        .toList();

    String version = AppConfig.appVersion;
    String build = '0';
    try {
      final info = await PackageInfo.fromPlatform();
      version = info.version;
      build = info.buildNumber;
    } catch (_) {}

    final projectId = await MyLifeOSIntegrationService.getMyLifeOSProjectId();

    return {
      'version': version,
      'build': build,
      'exportedAt': now.toIso8601String(),
      'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      'balance': balance,
      'income': income,
      'expenses': expenses,
      'currency': 'PEN',
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      'byCategory': byCategory,
      'weeklyExpenses': weeklyExpenses,
      'recentTransactions': recentTransactions,
      'metadata': {
        'walletai_version': version,
        'sync_enabled': true,
        'source': 'WalletAI',
      },
    };
  }

  /// Exporta localmente y, si hay sesión en la nube, publica al backend Render.
  static Future<bool> publishSummary(AppDatabase db) async {
    try {
      final summary = await buildRichSummary(db);

      // Mantener escritura local para compatibilidad / caché interno
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(p.join(dir.path, 'wallet_summary.json'));
        await file.writeAsString(jsonEncode(summary));
      } catch (_) {}

      final session = await CloudAccountService.getSessionInfo();
      final token = session.token;
      if (token == null || token.isEmpty) {
        return false;
      }

      final response = await http
          .put(
            Uri.parse('${AppConfig.apiBaseUrl}/ecosystem/summary'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(summary),
          )
          .timeout(const Duration(seconds: 20));

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[EcosystemSync] publishSummary error: $e');
      return false;
    }
  }

  /// Obtiene transacciones pendientes enviadas desde MyLifeOS.
  static Future<List<Map<String, dynamic>>> fetchPendingTransactions() async {
    try {
      final session = await CloudAccountService.getSessionInfo();
      final token = session.token;
      if (token == null || token.isEmpty) return [];

      final response = await http
          .get(
            Uri.parse('${AppConfig.apiBaseUrl}/ecosystem/pending-transactions'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];
      final decoded =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final items = decoded['items'] as List<dynamic>? ?? [];
      return items.whereType<Map<String, dynamic>>().toList();
    } catch (e) {
      debugPrint('[EcosystemSync] fetchPendingTransactions error: $e');
      return [];
    }
  }

  /// Importa todas las transacciones pendientes de MyLifeOS a Drift y las confirma.
  static Future<int> importAllPendingTransactions(AppDatabase db) async {
    final session = await CloudAccountService.getSessionInfo();
    final token = session.token;
    if (token == null || token.isEmpty) return 0;

    final pending = await fetchPendingTransactions();
    if (pending.isEmpty) return 0;

    final accounts = await db.accountsDao.getAllAccounts();
    if (accounts.isEmpty) return 0;

    final defaultAccount = accounts.firstWhere(
      (a) => a.type == 'cash' || a.type == 'wallet' || a.type == 'bank',
      orElse: () => accounts.first,
    );
    final expenseCategories = await db.categoriesDao.getCategoriesByType(
      'expense',
    );
    final repo = TransactionRepositoryImpl(db);

    int imported = 0;
    for (final item in pending) {
      try {
        final id = item['id']?.toString();
        final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
        if (id == null || amount <= 0) continue;

        final type = item['type'] == 'income' ? 'income' : 'expense';
        final hint = item['categoryHint']?.toString() ?? 'Alimentación';
        final matchedCat =
            await db.categoriesDao.findCategoryByName(hint) ??
            (expenseCategories.isNotEmpty ? expenseCategories.first : null);
        final txDate =
            DateTime.tryParse(item['date']?.toString() ?? '') ?? DateTime.now();
        final now = DateTime.now();

        final txId = const Uuid().v4();
        await repo.addTransaction(
          transaction: TransactionsCompanion.insert(
            id: txId,
            accountId: defaultAccount.id,
            type: type,
            currency: drift.Value(item['currency']?.toString() ?? 'PEN'),
            amount: amount,
            categoryId: drift.Value(matchedCat?.id),
            description: drift.Value(
              item['description']?.toString() ?? 'Compra desde MyLifeOS',
            ),
            notes: drift.Value('Importado desde MyLifeOS ($id)'),
            date: txDate,
            createdAt: now,
            updatedAt: now,
          ),
          accountId: defaultAccount.id,
          amount: amount,
          type: type,
        );

        await http
            .post(
              Uri.parse(
                '${AppConfig.apiBaseUrl}/ecosystem/pending-transactions/$id/ack',
              ),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 15));

        imported++;
      } catch (e) {
        debugPrint('[EcosystemSync] Error importando tx pendiente: $e');
      }
    }

    if (imported > 0) {
      await publishSummary(db);
    }

    return imported;
  }
}
