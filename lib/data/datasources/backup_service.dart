import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/drift_database.dart';
import 'backup_package_service.dart';

/// Carpeta de Drive donde se guardan los backups
const _driveFolderName = 'Control Financiero Backups';

class BackupResult {
  final bool success;
  final String message;
  final String? filePath;

  const BackupResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

/// Servicio de copia de seguridad unificado: Local, Compartir y Google Drive.
class BackupService {
  static final _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  static GoogleSignInAccount? _currentUser;

  static String _timestampName() {
    return DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .substring(0, 19);
  }

  // ─── BACKUP LOCAL UNIFICADO ────────────────────────────────────────────────

  /// Crea un paquete unificado (.wbackup = SQLite limpio + preferencias) en carpeta persistente
  static Future<BackupResult> backupLocally({AppDatabase? activeDb}) async {
    try {
      final pkg = await BackupPackageService.buildPackage(activeDb: activeDb);
      final targetDir = await BackupPackageService.resolveLocalBackupDirectory();
      final fileName = 'backup_financiero_${_timestampName()}.wbackup';
      final backupPath = p.join(targetDir.path, fileName);

      await File(backupPath).writeAsBytes(pkg.bytes, flush: true);

      return BackupResult(
        success: true,
        message:
            '✅ Backup completo guardado (${pkg.meta.stats.accountsCount} cuentas, '
            '${pkg.meta.stats.categoriesCount} categorías, '
            '${pkg.meta.stats.transactionsCount} movimientos):\n$backupPath',
        filePath: backupPath,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Error: $e');
    }
  }

  /// Permite al usuario elegir exactamente dónde guardar (Descargas, Documentos, etc.) vía SAF
  static Future<BackupResult> exportWithFilePicker({
    AppDatabase? activeDb,
  }) async {
    try {
      final pkg = await BackupPackageService.buildPackage(activeDb: activeDb);
      final fileName = 'backup_walletai_${_timestampName()}.wbackup';

      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar copia de seguridad completa',
        fileName: fileName,
        bytes: pkg.bytes,
      );

      if (savedPath == null) {
        return const BackupResult(
          success: false,
          message: 'Exportación cancelada',
        );
      }

      return BackupResult(
        success: true,
        message:
            '✅ Copia exportada con cuentas, categorías, movimientos y ajustes.',
        filePath: savedPath,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Error al exportar: $e');
    }
  }

  /// Comparte el paquete unificado (.wbackup) vía WhatsApp, Email, TeraBox, etc.
  static Future<BackupResult> shareBackup({AppDatabase? activeDb}) async {
    try {
      final pkg = await BackupPackageService.buildPackage(activeDb: activeDb);
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final shareFile = File(
        p.join(tempDir.path, 'backup_walletai_$dateStr.wbackup'),
      );
      await shareFile.writeAsBytes(pkg.bytes, flush: true);

      await Share.shareXFiles(
        [XFile(shareFile.path)],
        subject: 'Backup WalletAI – $dateStr',
        text:
            'Copia de seguridad completa de WalletAI (cuentas, categorías, movimientos y configuración).',
      );

      return const BackupResult(
        success: true,
        message: 'Backup compartido exitosamente',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Error al compartir: $e');
    }
  }

  /// Restaura desde archivo local (.wbackup, .walletai o .db legado)
  static Future<BackupResult> restoreFromLocalFile({
    WidgetRef? ref,
    Future<String?> Function()? promptPassword,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return const BackupResult(
          success: false,
          message: 'Sin archivo seleccionado',
        );
      }

      final bytes = await File(result.files.single.path!).readAsBytes();
      var res = await BackupPackageService.restoreFromBytes(bytes, ref: ref);

      if (!res.success && res.requiresPassword && promptPassword != null) {
        final pass = await promptPassword();
        if (pass == null || pass.isEmpty) {
          return const BackupResult(
            success: false,
            message: 'Restauración cancelada (requiere contraseña).',
          );
        }
        res = await BackupPackageService.restoreFromBytes(
          bytes,
          password: pass,
          ref: ref,
        );
      }

      return BackupResult(success: res.success, message: res.message);
    } catch (e) {
      return BackupResult(success: false, message: 'Error al restaurar: $e');
    }
  }

  // ─── GOOGLE DRIVE ─────────────────────────────────────────────────────────

  static Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      debugPrint('Error al iniciar sesión con Google: $e');
      rethrow;
    }
  }

  static Future<void> signOutGoogle() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  static Future<GoogleSignInAccount?> getSignedInUser() async {
    try {
      _currentUser = await _googleSignIn.signInSilently();
    } catch (e) {
      debugPrint('Error al iniciar sesión silenciosamente: $e');
      _currentUser = _googleSignIn.currentUser;
    }
    return _currentUser;
  }

  static Future<drive.DriveApi?> _getDriveApi() async {
    final user = _currentUser ?? await _googleSignIn.signInSilently();
    if (user == null) return null;

    final headers = await user.authHeaders;
    final client = _GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  static Future<String?> _getOrCreateDriveFolder(
    drive.DriveApi driveApi,
  ) async {
    final query =
        "name='$_driveFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final list = await driveApi.files.list(q: query, spaces: 'drive');

    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id;
    }

    final folder = drive.File()
      ..name = _driveFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await driveApi.files.create(folder);
    return created.id;
  }

  /// Sube el paquete unificado (.wbackup) a Google Drive
  static Future<BackupResult> backupToDrive({AppDatabase? activeDb}) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return const BackupResult(
          success: false,
          message: 'Debes iniciar sesión con Google primero',
        );
      }

      final pkg = await BackupPackageService.buildPackage(activeDb: activeDb);
      final folderId = await _getOrCreateDriveFolder(driveApi);
      final fileName = 'backup_financiero_${_timestampName()}.wbackup';

      final driveFile = drive.File()
        ..name = fileName
        ..parents = folderId != null ? [folderId] : null;

      final media = drive.Media(
        Stream.value(pkg.bytes),
        pkg.bytes.length,
        contentType: 'application/octet-stream',
      );

      await driveApi.files.create(driveFile, uploadMedia: media);

      return BackupResult(
        success: true,
        message:
            '☁️ Backup completo subido a Drive (${pkg.meta.stats.accountsCount} cuentas, '
            '${pkg.meta.stats.transactionsCount} movimientos)\nArchivo: $fileName',
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Error al subir a Drive: $e',
      );
    }
  }

  /// Lista backups disponibles en Drive (soporta .wbackup nuevo y .db legado)
  static Future<List<drive.File>> listDriveBackups() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return [];

      final folderId = await _getOrCreateDriveFolder(driveApi);
      if (folderId == null) return [];

      final query =
          "'$folderId' in parents and (name contains 'backup_financiero' or name contains 'backup_walletai') and trashed=false";
      final list = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        orderBy: 'createdTime desc',
        $fields: 'files(id,name,createdTime,size)',
      );

      return list.files ?? [];
    } catch (e) {
      debugPrint('Error listando backups de Drive: $e');
      return [];
    }
  }

  /// Descarga y restaura desde Google Drive en caliente
  static Future<BackupResult> restoreFromDrive(
    String fileId, {
    WidgetRef? ref,
    Future<String?> Function()? promptPassword,
  }) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return const BackupResult(
          success: false,
          message: 'Debes iniciar sesión con Google',
        );
      }

      final response =
          await driveApi.files.get(
                fileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }

      final rawBytes = Uint8List.fromList(bytes);
      var res = await BackupPackageService.restoreFromBytes(rawBytes, ref: ref);

      if (!res.success && res.requiresPassword && promptPassword != null) {
        final pass = await promptPassword();
        if (pass != null && pass.isNotEmpty) {
          res = await BackupPackageService.restoreFromBytes(
            rawBytes,
            password: pass,
            ref: ref,
          );
        }
      }

      return BackupResult(success: res.success, message: res.message);
    } catch (e) {
      return BackupResult(success: false, message: 'Error al restaurar: $e');
    }
  }

  static Future<BackupResult> deleteDriveBackup(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return const BackupResult(
          success: false,
          message: 'Debes iniciar sesión',
        );
      }
      await driveApi.files.delete(fileId);
      return const BackupResult(success: true, message: 'Backup eliminado');
    } catch (e) {
      return BackupResult(success: false, message: 'Error: $e');
    }
  }
}

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
