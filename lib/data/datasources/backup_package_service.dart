import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../presentation/providers/dashboard_provider.dart';
import '../../presentation/providers/database_providers.dart';
import '../../presentation/providers/theme_provider.dart';
import '../database/drift_database.dart';

const String kDbFileName = 'finanzas.db';
const String kPkgFormatV2 = 'WALLETAI_PKG_V2';
const String kEncMagicV1 = 'WALLETAI_ENC_V1'; // 15 bytes (legacy SQLite)
const String kEncMagicV2 = 'WALLETAI_ENC_V2'; // 15 bytes (unified package)

const _localOnlyPrefsPrefixes = <String>[
  'walletai_local_',
  'cloud_auth_',
  'auto_sync_last_',
];

class BackupStats {
  final int accountsCount;
  final int categoriesCount;
  final int subcategoriesCount;
  final int transactionsCount;

  const BackupStats({
    this.accountsCount = 0,
    this.categoriesCount = 0,
    this.subcategoriesCount = 0,
    this.transactionsCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'accountsCount': accountsCount,
    'categoriesCount': categoriesCount,
    'subcategoriesCount': subcategoriesCount,
    'transactionsCount': transactionsCount,
  };

  factory BackupStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BackupStats();
    return BackupStats(
      accountsCount: (json['accountsCount'] as num?)?.toInt() ?? 0,
      categoriesCount: (json['categoriesCount'] as num?)?.toInt() ?? 0,
      subcategoriesCount: (json['subcategoriesCount'] as num?)?.toInt() ?? 0,
      transactionsCount: (json['transactionsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class BackupPackageMeta {
  final String format;
  final int schemaVersion;
  final String createdAt;
  final String deviceId;
  final String deviceName;
  final BackupStats stats;

  const BackupPackageMeta({
    required this.format,
    required this.schemaVersion,
    required this.createdAt,
    required this.deviceId,
    required this.deviceName,
    required this.stats,
  });
}

class BackupPackagePayload {
  final Uint8List bytes;
  final String checksum;
  final BackupPackageMeta meta;

  const BackupPackagePayload({
    required this.bytes,
    required this.checksum,
    required this.meta,
  });
}

class BackupPackageResult {
  final bool success;
  final String message;
  final bool requiresPassword;
  final String? filePath;
  final BackupStats? stats;
  final bool restoredPreferences;

  const BackupPackageResult({
    required this.success,
    required this.message,
    this.requiresPassword = false,
    this.filePath,
    this.stats,
    this.restoredPreferences = false,
  });
}

/// Motor unificado de respaldo y restauración de WalletAI:
/// - Fuerza checkpoint + snapshot atómico (VACUUM INTO) antes de leer finanzas.db
/// - Empaqueta la base de datos SQLite + todas las preferencias (tema, dashboard,
///   notificaciones, historial IA, auto-sync)
/// - Cierra Drift, limpia -wal/-shm/-journal y recarga todos los providers en caliente
class BackupPackageService {
  static const _deviceIdKey = 'walletai_local_device_id';
  static const _customLocalDirKey = 'walletai_local_backup_dir';

  @visibleForTesting
  static Directory? testDocumentsDirOverride;

  @visibleForTesting
  static Directory? testTempDirOverride;

  static Future<Directory> _docsDir() async =>
      testDocumentsDirOverride ?? await getApplicationDocumentsDirectory();

  static Future<Directory> _tempDir() async =>
      testTempDirOverride ?? await getTemporaryDirectory();

  static Future<File> getDatabaseFile() async {
    final dir = await _docsDir();
    return File(p.join(dir.path, kDbFileName));
  }

  static Future<({String deviceId, String deviceName})>
  getOrCreateDeviceIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdKey, id);
    }
    String host = 'Android';
    try {
      final os = Platform.operatingSystem;
      final localHost = Platform.localHostname;
      host = localHost.isNotEmpty && localHost != 'localhost'
          ? '$os ($localHost)'
          : os.toUpperCase();
    } catch (_) {}
    return (deviceId: id, deviceName: host);
  }

  static Future<String?> getCustomLocalBackupDir() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customLocalDirKey);
  }

  static Future<void> setCustomLocalBackupDir(String? dirPath) async {
    final prefs = await SharedPreferences.getInstance();
    if (dirPath == null || dirPath.trim().isEmpty) {
      await prefs.remove(_customLocalDirKey);
    } else {
      await prefs.setString(_customLocalDirKey, dirPath.trim());
    }
  }

  /// Devuelve el directorio local persistente preferido (carpeta elegida por el usuario,
  /// Download/WalletAI si es escribible, o AppDocs/WalletAI_Backups como respaldo).
  static Future<Directory> resolveLocalBackupDirectory() async {
    final customPath = await getCustomLocalBackupDir();
    if (customPath != null && customPath.isNotEmpty) {
      try {
        final customDir = Directory(customPath);
        if (await customDir.exists()) {
          return customDir;
        }
        await customDir.create(recursive: true);
        return customDir;
      } catch (e) {
        debugPrint('BackupPackageService custom dir unavailable: $e');
      }
    }

    if (Platform.isAndroid) {
      const publicCandidates = [
        '/storage/emulated/0/Download/WalletAI',
        '/storage/emulated/0/Documents/WalletAI',
      ];
      for (final candidate in publicCandidates) {
        try {
          final dir = Directory(candidate);
          await dir.create(recursive: true);
          final probe = File(p.join(dir.path, '.probe_write'));
          await probe.writeAsString('ok');
          await probe.delete();
          return dir;
        } catch (_) {
          // Intentar siguiente ubicación si scoped storage bloquea escritura directa
        }
      }
    }

    final docsDir = await _docsDir();
    final fallbackDir = Directory(p.join(docsDir.path, 'WalletAI_Backups'));
    await fallbackDir.create(recursive: true);
    return fallbackDir;
  }

  static enc.Key _deriveKey(String password, Uint8List iv) {
    final passBytes = Uint8List.fromList(utf8.encode(password));
    final saltedInput = Uint8List(passBytes.length + iv.length)
      ..setRange(0, passBytes.length, passBytes)
      ..setRange(passBytes.length, passBytes.length + iv.length, iv);
    final hash = sha256.convert(saltedInput);
    return enc.Key(Uint8List.fromList(hash.bytes));
  }

  static Uint8List encryptBytesWithMagic(
    Uint8List plainBytes,
    String password, {
    String magic = kEncMagicV2,
  }) {
    final iv = enc.IV.fromSecureRandom(16);
    final key = _deriveKey(password, iv.bytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

    final header = Uint8List.fromList(magic.codeUnits);
    return Uint8List(header.length + iv.bytes.length + encrypted.bytes.length)
      ..setRange(0, header.length, header)
      ..setRange(header.length, header.length + 16, iv.bytes)
      ..setRange(
        header.length + 16,
        header.length + 16 + encrypted.bytes.length,
        encrypted.bytes,
      );
  }

  static Uint8List decryptBytesWithMagic(Uint8List raw, String password) {
    final ivBytes = Uint8List.fromList(
      raw.sublist(kEncMagicV2.length, kEncMagicV2.length + 16),
    );
    final iv = enc.IV(ivBytes);
    final key = _deriveKey(password, ivBytes);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final cipherBytes = Uint8List.fromList(
      raw.sublist(kEncMagicV2.length + 16),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv),
    );
  }

  static bool isValidSqliteBytes(List<int> bytes) {
    return bytes.length >= 16 &&
        String.fromCharCodes(bytes.sublist(0, 6)) == 'SQLite';
  }

  static bool _isGzip(List<int> bytes) {
    return bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B;
  }

  /// Obtiene un snapshot atómico de SQLite ejecutando checkpoint + VACUUM INTO
  /// para asegurar que TODAS las cuentas, montos, cortes y categorías recién
  /// guardadas estén volcadas antes de copiar.
  static Future<Uint8List> captureAtomicDatabaseBytes({
    AppDatabase? activeDb,
  }) async {
    if (activeDb != null) {
      final tempDir = await _tempDir();
      final tempPath = p.join(
        tempDir.path,
        'snapshot_${DateTime.now().microsecondsSinceEpoch}.db',
      );
      try {
        await activeDb.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');
        final escaped = tempPath.replaceAll("'", "''");
        await activeDb.customStatement("VACUUM INTO '$escaped';");
        final snapshotFile = File(tempPath);
        if (await snapshotFile.exists()) {
          final bytes = await snapshotFile.readAsBytes();
          await snapshotFile.delete().catchError((_) => snapshotFile);
          if (isValidSqliteBytes(bytes)) {
            return bytes;
          }
        }
      } catch (e) {
        debugPrint('BackupPackageService.captureAtomicDatabaseBytes fallback: $e');
        try {
          await File(tempPath).delete();
        } catch (_) {}
      }
    }

    final dbFile = await getDatabaseFile();
    if (!await dbFile.exists()) {
      throw StateError('No se encontró la base de datos local.');
    }
    return dbFile.readAsBytes();
  }

  static Future<BackupStats> _collectStats(AppDatabase? activeDb) async {
    if (activeDb == null) return const BackupStats();
    try {
      final accounts = await activeDb.accountsDao.getAllAccounts();
      final categories = await activeDb.categoriesDao.getAllCategories();
      final subcategories = await activeDb.subcategoriesDao
          .getAllSubcategories();
      final txs = await activeDb.transactionsDao.getAllTransactions();
      return BackupStats(
        accountsCount: accounts.length,
        categoriesCount: categories.length,
        subcategoriesCount: subcategories.length,
        transactionsCount: txs.length,
      );
    } catch (e) {
      debugPrint('BackupPackageService._collectStats: $e');
      return const BackupStats();
    }
  }

  static Future<Map<String, dynamic>> exportAppPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final exported = <String, dynamic>{};

    for (final key in prefs.getKeys()) {
      if (_localOnlyPrefsPrefixes.any((prefix) => key.startsWith(prefix))) {
        continue;
      }
      final val = prefs.get(key);
      if (val is bool) {
        exported[key] = {'t': 'b', 'v': val};
      } else if (val is int) {
        exported[key] = {'t': 'i', 'v': val};
      } else if (val is double) {
        exported[key] = {'t': 'd', 'v': val};
      } else if (val is String) {
        exported[key] = {'t': 's', 'v': val};
      } else if (val is List<String>) {
        exported[key] = {'t': 'l', 'v': val};
      }
    }
    return exported;
  }

  static Future<void> importAppPreferences(
    Map<String, dynamic> rawPrefs,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    // Limpiar solo claves sincronizables para no dejar ajustes huérfanos viejos,
    // preservando la sesión de nube e identidad del dispositivo.
    for (final existingKey in prefs.getKeys().toList()) {
      if (_localOnlyPrefsPrefixes.any((prefix) => existingKey.startsWith(prefix))) {
        continue;
      }
      await prefs.remove(existingKey);
    }

    for (final entry in rawPrefs.entries) {
      if (_localOnlyPrefsPrefixes.any((prefix) => entry.key.startsWith(prefix))) {
        continue;
      }
      final value = entry.value;
      if (value is Map<String, dynamic>) {
        final type = value['t'];
        final inner = value['v'];
        switch (type) {
          case 'b':
            if (inner is bool) await prefs.setBool(entry.key, inner);
            break;
          case 'i':
            if (inner is num) await prefs.setInt(entry.key, inner.toInt());
            break;
          case 'd':
            if (inner is num) await prefs.setDouble(entry.key, inner.toDouble());
            break;
          case 's':
            if (inner is String) await prefs.setString(entry.key, inner);
            break;
          case 'l':
            if (inner is List) {
              await prefs.setStringList(
                entry.key,
                inner.map((e) => e.toString()).toList(),
              );
            }
            break;
        }
      }
    }
  }

  /// Construye un paquete unificado WALLETAI_PKG_V2 comprimido (gzip),
  /// opcionalmente cifrado con AES-256-CBC (WALLETAI_ENC_V2).
  static Future<BackupPackagePayload> buildPackage({
    AppDatabase? activeDb,
    String? password,
  }) async {
    final identity = await getOrCreateDeviceIdentity();
    final dbBytes = await captureAtomicDatabaseBytes(activeDb: activeDb);
    final stats = await _collectStats(activeDb);
    final preferences = await exportAppPreferences();
    final nowIso = DateTime.now().toIso8601String();

    final packageJson = {
      'format': kPkgFormatV2,
      'schemaVersion': activeDb?.schemaVersion ?? 15,
      'createdAt': nowIso,
      'deviceId': identity.deviceId,
      'deviceName': identity.deviceName,
      'stats': stats.toJson(),
      'dbGzipBase64': base64Encode(gzip.encode(dbBytes)),
      'preferences': preferences,
    };

    final compressedPkg = Uint8List.fromList(
      gzip.encode(utf8.encode(jsonEncode(packageJson))),
    );

    final finalBytes = (password != null && password.isNotEmpty)
        ? encryptBytesWithMagic(compressedPkg, password, magic: kEncMagicV2)
        : compressedPkg;

    final checksum = sha256.convert(finalBytes).toString();
    return BackupPackagePayload(
      bytes: finalBytes,
      checksum: checksum,
      meta: BackupPackageMeta(
        format: kPkgFormatV2,
        schemaVersion: activeDb?.schemaVersion ?? 15,
        createdAt: nowIso,
        deviceId: identity.deviceId,
        deviceName: identity.deviceName,
        stats: stats,
      ),
    );
  }

  /// Desempaqueta y restaura cualquiera de los formatos soportados:
  /// - WALLETAI_ENC_V2 (paquete unificado cifrado)
  /// - WALLETAI_PKG_V2 (paquete unificado gzip/JSON sin cifrar)
  /// - WALLETAI_ENC_V1 (legado cifrado .walletai)
  /// - SQLite crudo (.db)
  static Future<BackupPackageResult> restoreFromBytes(
    Uint8List rawBytes, {
    String? password,
    WidgetRef? ref,
  }) async {
    try {
      Uint8List workingBytes = rawBytes;
      Map<String, dynamic>? prefsToRestore;
      BackupStats? stats;

      final header = rawBytes.length >= kEncMagicV2.length
          ? String.fromCharCodes(rawBytes.sublist(0, kEncMagicV2.length))
          : '';

      if (header == kEncMagicV2 || header == kEncMagicV1) {
        if (password == null || password.isEmpty) {
          return const BackupPackageResult(
            success: false,
            requiresPassword: true,
            message: 'Este respaldo está cifrado. Ingresa la contraseña.',
          );
        }
        try {
          workingBytes = decryptBytesWithMagic(rawBytes, password);
        } catch (_) {
          return const BackupPackageResult(
            success: false,
            message: '❌ Contraseña incorrecta o archivo corrupto.',
          );
        }
      }

      if (_isGzip(workingBytes)) {
        workingBytes = Uint8List.fromList(gzip.decode(workingBytes));
      }

      Uint8List sqliteBytes;
      if (isValidSqliteBytes(workingBytes)) {
        sqliteBytes = workingBytes;
      } else {
        // Intentar interpretar como JSON WALLETAI_PKG_V2
        final decoded = jsonDecode(utf8.decode(workingBytes));
        if (decoded is! Map<String, dynamic> ||
            decoded['format'] != kPkgFormatV2) {
          return const BackupPackageResult(
            success: false,
            message: 'Archivo inválido. No es un respaldo compatible de WalletAI.',
          );
        }
        final dbCompressed = base64Decode(decoded['dbGzipBase64'] as String);
        sqliteBytes = Uint8List.fromList(gzip.decode(dbCompressed));
        if (!isValidSqliteBytes(sqliteBytes)) {
          return const BackupPackageResult(
            success: false,
            message: 'La base de datos dentro del paquete está dañada.',
          );
        }
        final rawPrefs = decoded['preferences'];
        if (rawPrefs is Map<String, dynamic>) {
          prefsToRestore = rawPrefs;
        }
        final rawStats = decoded['stats'];
        if (rawStats is Map<String, dynamic>) {
          stats = BackupStats.fromJson(rawStats);
        }
      }

      final dbFile = await getDatabaseFile();

      // Respaldo de emergencia antes de reemplazar
      if (await dbFile.exists()) {
        final docsDir = await _docsDir();
        await dbFile.copy(p.join(docsDir.path, 'backup_antes_restaurar.db'));
      }

      // Cerrar Drift antes de tocar finanzas.db en disco
      if (ref != null) {
        try {
          await ref.read(databaseProvider).close();
        } catch (e) {
          debugPrint('BackupPackageService close active db: $e');
        }
      }

      // Borrar residuos de SQLite WAL/SHM/Journal para evitar mezcla de datos viejos
      for (final suffix in ['-wal', '-shm', '-journal']) {
        final auxFile = File('${dbFile.path}$suffix');
        if (await auxFile.exists()) {
          await auxFile.delete().catchError((_) => auxFile);
        }
      }

      await dbFile.writeAsBytes(sqliteBytes, flush: true);

      bool restoredPrefs = false;
      if (prefsToRestore != null) {
        await importAppPreferences(prefsToRestore);
        restoredPrefs = true;
      }

      if (ref != null) {
        await ref.read(themeProvider.notifier).reload();
        await ref.read(dashboardLayoutProvider.notifier).reload();
        ref.read(dbGenerationProvider.notifier).state++;
      }

      final detail = stats != null
          ? '\n(${stats.accountsCount} cuentas, ${stats.categoriesCount} categorías, ${stats.transactionsCount} movimientos)'
          : '';
      return BackupPackageResult(
        success: true,
        stats: stats,
        restoredPreferences: restoredPrefs,
        message: ref != null
            ? '✅ Restauración aplicada y recargada.$detail'
            : '✅ Restauración exitosa.$detail Reinicia la app para aplicar los cambios.',
      );
    } catch (e) {
      debugPrint('BackupPackageService.restoreFromBytes: $e');
      return BackupPackageResult(
        success: false,
        message: 'Error al restaurar: $e',
      );
    }
  }
}
