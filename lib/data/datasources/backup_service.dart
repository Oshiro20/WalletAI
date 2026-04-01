import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// Nombre del archivo de base de datos SQLite de Drift
const _dbFileName = 'finanzas.db';


/// Folder de Drive donde se guardan los backups
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

/// Servicio de copia de seguridad: Local, Google Drive y compartir
class BackupService {
  // ─── Google Sign In ────────────────────────────────────────────────────────
  static final _googleSignIn = GoogleSignIn(
    scopes: [
      drive.DriveApi.driveFileScope,
      'email',
      'https://www.googleapis.com/auth/userinfo.profile',
    ],
  );

  static GoogleSignInAccount? _currentUser;

  // ─── Obtener ruta de la base de datos ─────────────────────────────────────
  static Future<File> _getDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _dbFileName));
  }

  // ─── BACKUP LOCAL ─────────────────────────────────────────────────────────

  /// Copia el archivo .db a la carpeta de Documentos del usuario
  static Future<BackupResult> backupLocally() async {
    try {
      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) {
        return const BackupResult(
            success: false, message: 'No se encontró la base de datos');
      }

      final docsDir = await getApplicationDocumentsDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final backupPath =
          p.join(docsDir.path, 'backup_financiero_$timestamp.db');

      await dbFile.copy(backupPath);

      return BackupResult(
        success: true,
        message: 'Backup guardado en:\n$backupPath',
        filePath: backupPath,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Error: $e');
    }
  }

  /// Comparte el archivo .db vía cualquier app (WhatsApp, email, Terabox…)
  static Future<BackupResult> shareBackup() async {
    try {
      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) {
        return const BackupResult(
            success: false, message: 'No se encontró la base de datos');
      }

      // Copiar a un nombre legible antes de compartir
      final tempDir = await getTemporaryDirectory();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 10);
      final shareFile = File(p.join(tempDir.path, 'backup_financiero_$timestamp.db'));
      await dbFile.copy(shareFile.path);

      await Share.shareXFiles(
        [XFile(shareFile.path)],
        subject: 'Backup Control Financiero – $timestamp',
        text:
            'Copia de seguridad de tu aplicativo de control financiero. Guárdala en un lugar seguro.',
      );

      return const BackupResult(
          success: true, message: 'Backup compartido exitosamente');
    } catch (e) {
      return BackupResult(success: false, message: 'Error al compartir: $e');
    }
  }

  /// Restaurar desde un archivo .db local seleccionado
  static Future<BackupResult> restoreFromLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        return const BackupResult(success: false, message: 'Sin archivo seleccionado');
      }

      final selectedFile = File(result.files.single.path!);

      // Validar que sea un archivo SQLite
      final bytes = await selectedFile.readAsBytes();
      if (bytes.length < 16 || String.fromCharCodes(bytes.sublist(0, 6)) != 'SQLite') {
        return const BackupResult(
            success: false, message: 'Archivo inválido. No es un backup compatible.');
      }

      final dbFile = await _getDbFile();

      // Crear un backup de seguridad antes de restaurar
      if (await dbFile.exists()) {
        final dir = await getApplicationDocumentsDirectory();
        await dbFile.copy(p.join(dir.path, 'backup_antes_restaurar.db'));
      }

      await selectedFile.copy(dbFile.path);

      return const BackupResult(
        success: true,
        message:
            '✅ Restauración exitosa.\n\nReinicia la app para aplicar los cambios.',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Error al restaurar: $e');
    }
  }

  // ─── GOOGLE DRIVE ─────────────────────────────────────────────────────────

  /// Iniciar sesión con Google
  static Future<GoogleSignInAccount?> signInWithGoogle() async {
    try {
      _currentUser = await _googleSignIn.signIn();
      return _currentUser;
    } catch (e) {
      debugPrint('Error al iniciar sesión con Google: $e');
      rethrow;
    }
  }

  /// Cerrar sesión de Google
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

  /// Obtener cliente HTTP autenticado para Drive API
  static Future<drive.DriveApi?> _getDriveApi() async {
    final user = _currentUser ?? await _googleSignIn.signInSilently();
    if (user == null) return null;

    final headers = await user.authHeaders;
    final client = _GoogleAuthClient(headers);
    return drive.DriveApi(client);
  }

  /// Obtener o crear carpeta de backups en Drive
  static Future<String?> _getOrCreateDriveFolder(drive.DriveApi driveApi) async {
    // Buscar carpeta existente
    final query =
        "name='$_driveFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false";
    final list = await driveApi.files.list(q: query, spaces: 'drive');

    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id;
    }

    // Crear carpeta
    final folder = drive.File()
      ..name = _driveFolderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await driveApi.files.create(folder);
    return created.id;
  }

  /// Subir backup a Google Drive
  static Future<BackupResult> backupToDrive() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return const BackupResult(
            success: false,
            message: 'Debes iniciar sesión con Google primero');
      }

      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) {
        return const BackupResult(
            success: false, message: 'No se encontró la base de datos');
      }

      final folderId = await _getOrCreateDriveFolder(driveApi);
      final fileBytes = await dbFile.readAsBytes();
      final timestamp =
          DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
      final fileName = 'backup_financiero_$timestamp.db';

      final driveFile = drive.File()
        ..name = fileName
        ..parents = folderId != null ? [folderId] : null;

      final media = drive.Media(
        Stream.value(fileBytes),
        fileBytes.length,
        contentType: 'application/octet-stream',
      );

      await driveApi.files.create(driveFile, uploadMedia: media);

      return BackupResult(
        success: true,
        message:
            '☁️ Backup subido a Google Drive\nCarpeta: $_driveFolderName\nArchivo: $fileName',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Error al subir a Drive: $e');
    }
  }

  /// Listar backups disponibles en Google Drive
  static Future<List<drive.File>> listDriveBackups() async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) return [];

      final folderId = await _getOrCreateDriveFolder(driveApi);
      if (folderId == null) return [];

      final query =
          "'$folderId' in parents and name contains 'backup_financiero' and trashed=false";
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

  /// Restaurar desde Google Drive
  static Future<BackupResult> restoreFromDrive(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return const BackupResult(
            success: false, message: 'Debes iniciar sesión con Google');
      }

      final response = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
      }

      final dbFile = await _getDbFile();

      // Backup de seguridad antes de restaurar
      if (await dbFile.exists()) {
        final dir = await getApplicationDocumentsDirectory();
        await dbFile.copy(p.join(dir.path, 'backup_antes_restaurar.db'));
      }

      await dbFile.writeAsBytes(bytes);

      return const BackupResult(
        success: true,
        message:
            '✅ Restauración desde Drive exitosa.\n\nReinicia la app para aplicar los cambios.',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Error al restaurar: $e');
    }
  }

  /// Eliminar un backup de Drive
  static Future<BackupResult> deleteDriveBackup(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      if (driveApi == null) {
        return const BackupResult(
            success: false, message: 'Debes iniciar sesión');
      }
      await driveApi.files.delete(fileId);
      return const BackupResult(success: true, message: 'Backup eliminado');
    } catch (e) {
      return BackupResult(success: false, message: 'Error: $e');
    }
  }
}

/// Cliente HTTP autenticado para Google APIs
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
