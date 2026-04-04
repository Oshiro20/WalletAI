import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de integración con MyLifeOS.
///
/// Exporta un resumen financiero (wallet_summary.json) que MyLifeOS puede leer,
/// y procesa solicitudes de sincronización entrantes.
class MyLifeOSIntegrationService {
  static const _myLifeOSProjectIdKey = 'mylifeos_project_id';
  static const _walletSummaryFileName = 'wallet_summary.json';
  static const _syncRequestFileName = 'wallet_sync_request.json';

  final GetMonthlySummary getMonthlySummary;

  MyLifeOSIntegrationService({required this.getMonthlySummary});

  /// Lee el Project ID configurado por MyLifeOS en SharedPreferences.
  /// MyLifeOS escribe esta clave cuando configura la integración.
  static Future<String?> getMyLifeOSProjectId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_myLifeOSProjectIdKey);
    } catch (e) {
      debugPrint('[MyLifeOSIntegration] Error reading projectId: $e');
      return null;
    }
  }

  /// Establece el Project ID de MyLifeOS (para testing o configuración manual).
  static Future<void> setMyLifeOSProjectId(String projectId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_myLifeOSProjectIdKey, projectId);
      debugPrint('[MyLifeOSIntegration] ProjectId establecido: $projectId');
    } catch (e) {
      debugPrint('[MyLifeOSIntegration] Error setting projectId: $e');
    }
  }

  /// Exporta el resumen financiero a wallet_summary.json en el directorio
  /// de documentos compartido donde MyLifeOS puede leerlo.
  Future<void> exportWalletSummary() async {
    try {
      final projectId = await getMyLifeOSProjectId();
      final summary = await getMonthlySummary();

      final data = {
        'version': '1.2.0',
        'month': summary['month'] ?? _currentMonthLabel(),
        'balance': summary['balance'] ?? 0.0,
        'income': summary['income'] ?? 0.0,
        'expenses': summary['expenses'] ?? 0.0,
        'currency': summary['currency'] ?? 'PEN',
        'exportedAt': DateTime.now().toIso8601String(),
        if (projectId != null) 'projectId': projectId,
        'metadata': {
          'walletai_version': '1.2.0',
          'sync_enabled': true,
          'source': 'WalletAI',
        },
      };

      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/$_walletSummaryFileName');
      await file.writeAsString(jsonEncode(data));
      debugPrint('[MyLifeOSIntegration] Resumen exportado: ${file.path}');
    } catch (e) {
      debugPrint('[MyLifeOSIntegration] Error exporting summary: $e');
    }
  }

  /// Procesa solicitudes de sincronización de MyLifeOS.
  /// MyLifeOS crea wallet_sync_request.json y abre WalletAI.
  /// Este método lee la solicitud y re-exporta el resumen.
  Future<void> processSyncRequest() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final syncFile = File('${docDir.path}/$_syncRequestFileName');

      if (!await syncFile.exists()) return;

      final content = await syncFile.readAsString();
      final request = jsonDecode(content) as Map<String, dynamic>;

      // Extraer projectId de la solicitud y guardarlo
      final requestId = request['projectId'] as String?;
      if (requestId != null && requestId.isNotEmpty) {
        await setMyLifeOSProjectId(requestId);
        debugPrint('[MyLifeOSIntegration] ProjectId desde sync: $requestId');
      }

      // Re-exportar el resumen actualizado
      await exportWalletSummary();

      // Crear respuesta
      final response = {
        'type': 'sync_response',
        'status': 'success',
        'projectId': requestId,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final responseFile = File('${docDir.path}/wallet_sync_response.json');
      await responseFile.writeAsString(jsonEncode(response));

      debugPrint('[MyLifeOSIntegration] Sync procesada exitosamente');
    } catch (e) {
      debugPrint('[MyLifeOSIntegration] Error processing sync: $e');
    }
  }

  /// Genera el label del mes actual (ej: "2026-04").
  static String _currentMonthLabel() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}

/// Tipo de función para obtener el resumen mensual.
/// Debe retornar un mapa con: balance, income, expenses, currency, month.
typedef GetMonthlySummary = Future<Map<String, dynamic>> Function();
