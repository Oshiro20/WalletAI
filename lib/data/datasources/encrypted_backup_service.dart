import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../database/drift_database.dart';
import 'backup_package_service.dart';

const String _encExtension = '.walletai';

class EncryptResult {
  final bool success;
  final String message;
  final String? filePath;

  const EncryptResult({
    required this.success,
    required this.message,
    this.filePath,
  });

  factory EncryptResult.error(String msg) =>
      EncryptResult(success: false, message: msg);
}

/// Servicio de backup CIFRADO con AES-256-CBC (paquete unificado V2 + compatibilidad V1).
class EncryptedBackupService {
  static Future<EncryptResult> encryptAndSave(
    String password, {
    AppDatabase? activeDb,
  }) async {
    try {
      if (password.length < 4) {
        return EncryptResult.error(
          'La contraseña debe tener al menos 4 caracteres',
        );
      }

      final pkg = await BackupPackageService.buildPackage(
        activeDb: activeDb,
        password: password,
      );

      final targetDir = await BackupPackageService.resolveLocalBackupDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final outPath = p.join(targetDir.path, 'backup_$timestamp$_encExtension');

      await File(outPath).writeAsBytes(pkg.bytes, flush: true);

      return EncryptResult(
        success: true,
        message: '🔒 Backup cifrado completo guardado en:\n$outPath',
        filePath: outPath,
      );
    } catch (e) {
      debugPrint('EncryptedBackupService.encryptAndSave: $e');
      return EncryptResult.error('Error al cifrar: $e');
    }
  }

  static Future<EncryptResult> encryptAndShare(
    String password, {
    AppDatabase? activeDb,
  }) async {
    final result = await encryptAndSave(password, activeDb: activeDb);
    if (!result.success || result.filePath == null) return result;

    try {
      final timestamp = DateTime.now().toIso8601String().substring(0, 10);
      await Share.shareXFiles(
        [XFile(result.filePath!)],
        subject: 'WalletAI Backup Cifrado – $timestamp',
        text:
            '🔒 Backup cifrado completo de WalletAI. Necesitas la contraseña para restaurarlo.',
      );
      return const EncryptResult(
        success: true,
        message: 'Backup cifrado compartido exitosamente',
      );
    } catch (e) {
      return EncryptResult.error('Error al compartir: $e');
    }
  }

  static Future<EncryptResult> decryptAndRestore(
    String filePath,
    String password, {
    WidgetRef? ref,
  }) async {
    try {
      final encFile = File(filePath);
      if (!await encFile.exists()) {
        return EncryptResult.error('El archivo no existe: $filePath');
      }

      final raw = await encFile.readAsBytes();
      final res = await BackupPackageService.restoreFromBytes(
        raw,
        password: password,
        ref: ref,
      );
      return EncryptResult(success: res.success, message: res.message);
    } catch (e) {
      debugPrint('EncryptedBackupService.decryptAndRestore: $e');
      return EncryptResult.error('Error al restaurar: $e');
    }
  }

  static Future<bool> verifyPassword(String filePath, String password) async {
    try {
      final raw = await File(filePath).readAsBytes();
      if (raw.length < kEncMagicV2.length + 32) return false;
      final header = String.fromCharCodes(raw.sublist(0, kEncMagicV2.length));
      if (header != kEncMagicV2 && header != kEncMagicV1) return false;
      final plain = BackupPackageService.decryptBytesWithMagic(raw, password);
      return plain.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
