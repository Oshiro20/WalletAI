import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../database/drift_database.dart';
import 'backup_package_service.dart';

class CloudBackupMetadata {
  final bool exists;
  final String? deviceId;
  final String? deviceName;
  final int schemaVersion;
  final int accountsCount;
  final int transactionsCount;
  final int categoriesCount;
  final String? checksum;
  final int sizeBytes;
  final String? updatedAt;

  const CloudBackupMetadata({
    required this.exists,
    this.deviceId,
    this.deviceName,
    this.schemaVersion = 15,
    this.accountsCount = 0,
    this.transactionsCount = 0,
    this.categoriesCount = 0,
    this.checksum,
    this.sizeBytes = 0,
    this.updatedAt,
  });

  factory CloudBackupMetadata.fromJson(Map<String, dynamic>? json) {
    if (json == null || json['exists'] != true) {
      return const CloudBackupMetadata(exists: false);
    }
    return CloudBackupMetadata(
      exists: true,
      deviceId: json['deviceId'] as String?,
      deviceName: json['deviceName'] as String?,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 15,
      accountsCount: (json['accountsCount'] as num?)?.toInt() ?? 0,
      transactionsCount: (json['transactionsCount'] as num?)?.toInt() ?? 0,
      categoriesCount: (json['categoriesCount'] as num?)?.toInt() ?? 0,
      checksum: json['checksum'] as String?,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] as String?,
    );
  }
}

class CloudOperationResult {
  final bool success;
  final String message;
  final bool hasConflict;
  final bool dbNotConfigured;
  final CloudBackupMetadata? serverBackup;
  final BackupPackageResult? restoreResult;

  const CloudOperationResult({
    required this.success,
    required this.message,
    this.hasConflict = false,
    this.dbNotConfigured = false,
    this.serverBackup,
    this.restoreResult,
  });
}

/// Servicio de Cuenta en la Nube (Usuario/Contraseña) + Bóveda Unificada en Backend.
class CloudAccountService {
  static const _tokenKey = 'cloud_auth_token';
  static const _usernameKey = 'cloud_auth_username';
  static const _serverUpdatedAtKey = 'cloud_auth_server_updated_at';
  static const _lastSyncedIsoKey = 'cloud_auth_last_synced_iso';

  static String get _baseUrl => AppConfig.apiBaseUrl;

  static Future<
    ({
      String? token,
      String? username,
      String? serverUpdatedAt,
      String? lastSyncedAt,
    })
  >
  getSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      token: prefs.getString(_tokenKey),
      username: prefs.getString(_usernameKey),
      serverUpdatedAt: prefs.getString(_serverUpdatedAtKey),
      lastSyncedAt: prefs.getString(_lastSyncedIsoKey),
    );
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_serverUpdatedAtKey);
    await prefs.remove(_lastSyncedIsoKey);
  }

  static Future<
    ({
      bool success,
      String message,
      CloudBackupMetadata? latestBackup,
      bool dbNotConfigured,
    })
  >
  authenticate({
    required bool isRegister,
    required String username,
    required String password,
  }) async {
    try {
      final identity = await BackupPackageService.getOrCreateDeviceIdentity();
      final endpoint = isRegister ? 'auth/register' : 'auth/login';
      final response = await http
          .post(
            Uri.parse('$_baseUrl/$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username.trim(),
              'password': password,
              'deviceId': identity.deviceId,
              'deviceName': identity.deviceName,
            }),
          )
          .timeout(const Duration(seconds: 35));

      final body = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;

      if (response.statusCode == 503 &&
          body['error'] == 'CLOUD_DB_NOT_CONFIGURED') {
        return (
          success: false,
          message:
              'La nube aún requiere configurar PostgreSQL (DATABASE_URL) en Render.',
          latestBackup: null,
          dbNotConfigured: true,
        );
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, body['token'] as String);
        await prefs.setString(
          _usernameKey,
          (body['user'] as Map<String, dynamic>)['username'] as String,
        );
        final latest = CloudBackupMetadata.fromJson(
          body['latestBackup'] as Map<String, dynamic>?,
        );
        return (
          success: true,
          message: isRegister
              ? '✅ Cuenta creada en la nube'
              : '✅ Sesión iniciada en la nube',
          latestBackup: latest,
          dbNotConfigured: false,
        );
      }

      return (
        success: false,
        message: (body['error'] ?? 'Error HTTP ${response.statusCode}')
            .toString(),
        latestBackup: null,
        dbNotConfigured: false,
      );
    } catch (e) {
      return (
        success: false,
        message: 'Error de conexión con la nube: $e',
        latestBackup: null,
        dbNotConfigured: false,
      );
    }
  }

  static Future<
    ({
      bool success,
      String message,
      CloudBackupMetadata? latestBackup,
      bool dbNotConfigured,
    })
  >
  fetchStatus() async {
    final session = await getSessionInfo();
    if (session.token == null || session.token!.isEmpty) {
      return (
        success: false,
        message: 'No hay sesión activa en la nube.',
        latestBackup: null,
        dbNotConfigured: false,
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/backup/status'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 30));

      final body = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      if (response.statusCode == 401) {
        await signOut();
        return (
          success: false,
          message: 'Sesión expirada. Inicia sesión nuevamente.',
          latestBackup: null,
          dbNotConfigured: false,
        );
      }
      if (response.statusCode == 503 &&
          body['error'] == 'CLOUD_DB_NOT_CONFIGURED') {
        return (
          success: false,
          message:
              'La nube aún requiere configurar PostgreSQL (DATABASE_URL) en Render.',
          latestBackup: null,
          dbNotConfigured: true,
        );
      }
      if (response.statusCode == 200) {
        return (
          success: true,
          message: 'OK',
          latestBackup: CloudBackupMetadata.fromJson(
            body['latestBackup'] as Map<String, dynamic>?,
          ),
          dbNotConfigured: false,
        );
      }
      return (
        success: false,
        message: (body['error'] ?? 'HTTP ${response.statusCode}').toString(),
        latestBackup: null,
        dbNotConfigured: false,
      );
    } catch (e) {
      return (
        success: false,
        message: 'No se pudo consultar la nube: $e',
        latestBackup: null,
        dbNotConfigured: false,
      );
    }
  }

  static Future<CloudOperationResult> uploadUnifiedBackup({
    AppDatabase? activeDb,
    bool force = false,
  }) async {
    final session = await getSessionInfo();
    if (session.token == null || session.token!.isEmpty) {
      return const CloudOperationResult(
        success: false,
        message: 'Inicia sesión con tu usuario y contraseña primero.',
      );
    }

    try {
      final package = await BackupPackageService.buildPackage(
        activeDb: activeDb,
      );
      final response = await http
          .post(
            Uri.parse('$_baseUrl/backup/upload'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${session.token}',
            },
            body: jsonEncode({
              'deviceId': package.meta.deviceId,
              'deviceName': package.meta.deviceName,
              'schemaVersion': package.meta.schemaVersion,
              'accountsCount': package.meta.stats.accountsCount,
              'transactionsCount': package.meta.stats.transactionsCount,
              'categoriesCount': package.meta.stats.categoriesCount,
              'checksum': package.checksum,
              'payloadBase64': base64Encode(package.bytes),
              'baseUpdatedAt': session.serverUpdatedAt,
              'force': force,
            }),
          )
          .timeout(const Duration(seconds: 60));

      final body = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;

      if (response.statusCode == 401) {
        await signOut();
        return const CloudOperationResult(
          success: false,
          message: 'Tu sesión expiró. Vuelve a iniciar sesión.',
        );
      }
      if (response.statusCode == 503 &&
          body['error'] == 'CLOUD_DB_NOT_CONFIGURED') {
        return const CloudOperationResult(
          success: false,
          dbNotConfigured: true,
          message:
              'La nube aún requiere configurar PostgreSQL (DATABASE_URL) en Render.',
        );
      }
      if (response.statusCode == 409 &&
          body['error'] == 'CONFLICT_NEWER_BACKUP') {
        return CloudOperationResult(
          success: false,
          hasConflict: true,
          serverBackup: CloudBackupMetadata.fromJson(
            body['latestBackup'] as Map<String, dynamic>?,
          ),
          message:
              (body['message'] ??
                      'Otro dispositivo guardó una copia más reciente.')
                  .toString(),
        );
      }
      if (response.statusCode == 200) {
        final latest = CloudBackupMetadata.fromJson(
          body['latestBackup'] as Map<String, dynamic>?,
        );
        final prefs = await SharedPreferences.getInstance();
        if (latest.updatedAt != null) {
          await prefs.setString(_serverUpdatedAtKey, latest.updatedAt!);
        }
        await prefs.setString(
          _lastSyncedIsoKey,
          DateTime.now().toIso8601String(),
        );
        return CloudOperationResult(
          success: true,
          serverBackup: latest,
          message:
              '☁️ Copia subida a tu cuenta (${package.meta.stats.accountsCount} cuentas, ${package.meta.stats.transactionsCount} movimientos).',
        );
      }
      return CloudOperationResult(
        success: false,
        message: (body['error'] ?? 'HTTP ${response.statusCode}').toString(),
      );
    } catch (e) {
      return CloudOperationResult(
        success: false,
        message: 'Error subiendo respaldo a la nube: $e',
      );
    }
  }

  static Future<CloudOperationResult> downloadAndRestore({
    WidgetRef? ref,
  }) async {
    final session = await getSessionInfo();
    if (session.token == null || session.token!.isEmpty) {
      return const CloudOperationResult(
        success: false,
        message: 'Inicia sesión con tu usuario y contraseña primero.',
      );
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/backup/download'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          )
          .timeout(const Duration(seconds: 60));

      final body = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;

      if (response.statusCode == 401) {
        await signOut();
        return const CloudOperationResult(
          success: false,
          message: 'Tu sesión expiró. Vuelve a iniciar sesión.',
        );
      }
      if (response.statusCode != 200) {
        return CloudOperationResult(
          success: false,
          message: (body['error'] ?? 'HTTP ${response.statusCode}').toString(),
        );
      }

      final latest = CloudBackupMetadata.fromJson(
        body['latestBackup'] as Map<String, dynamic>?,
      );
      final bytes = Uint8List.fromList(
        base64Decode(body['payloadBase64'] as String),
      );
      final actualChecksum = sha256.convert(bytes).toString();
      if (latest.checksum != null &&
          latest.checksum!.isNotEmpty &&
          actualChecksum != latest.checksum) {
        return const CloudOperationResult(
          success: false,
          message:
              'El archivo descargado no coincide con la verificación SHA-256.',
        );
      }

      final restoreRes = await BackupPackageService.restoreFromBytes(
        bytes,
        ref: ref,
      );
      if (restoreRes.success) {
        final prefs = await SharedPreferences.getInstance();
        if (latest.updatedAt != null) {
          await prefs.setString(_serverUpdatedAtKey, latest.updatedAt!);
        }
        await prefs.setString(
          _lastSyncedIsoKey,
          DateTime.now().toIso8601String(),
        );
      }

      return CloudOperationResult(
        success: restoreRes.success,
        message: restoreRes.message,
        serverBackup: latest,
        restoreResult: restoreRes,
      );
    } catch (e) {
      return CloudOperationResult(
        success: false,
        message: 'Error descargando respaldo: $e',
      );
    }
  }
}
