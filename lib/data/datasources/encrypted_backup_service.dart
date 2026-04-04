import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
// For _dbFileName & _getDbFile pattern

// ─── Constantes ───────────────────────────────────────────────────────────────
const String _encExtension = '.walletai';
const String _magicHeader = 'WALLETAI_ENC_V1'; // 15 bytes

/// Resultado de una operación de cifrado
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

/// Servicio de backup CIFRADO con AES-256-CBC.
///
/// Proceso de cifrado:
///   1. Genera una clave de 32 bytes haciendo SHA-256 de la contraseña + IV (salt).
///   2. Cifra el contenido del .sqlite con AES-256-CBC.
///   3. Escribe el archivo: [magic(15)] [iv(16)] [ciphertext].
///
/// Proceso de descifrado:
///   1. Lee los primeros 15 bytes — valida el header.
///   2. Lee los siguientes 16 bytes — extrae el IV.
///   3. Deriva la clave con la contraseña, descifra el resto.
class EncryptedBackupService {
  static const String _dbFileName = 'finanzas.db';

  // ─── Utilidades internas ────────────────────────────────────────────────────

  static Future<File> _getDbFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _dbFileName));
  }

  /// Deriva una clave AES de 32 bytes desde la contraseña + IV (salt público).
  static enc.Key _deriveKey(String password, Uint8List iv) {
    final passBytes = Uint8List.fromList(password.codeUnits);
    final saltedInput = Uint8List(passBytes.length + iv.length)
      ..setRange(0, passBytes.length, passBytes)
      ..setRange(passBytes.length, passBytes.length + iv.length, iv);
    final hash = sha256.convert(saltedInput);
    return enc.Key(Uint8List.fromList(hash.bytes));
  }

  // ─── Cifrar y guardar localmente ────────────────────────────────────────────

  /// Cifra el backup y lo guarda en Documentos con extensión `.walletai`.
  static Future<EncryptResult> encryptAndSave(String password) async {
    try {
      if (password.length < 4) {
        return EncryptResult.error(
          'La contraseña debe tener al menos 4 caracteres',
        );
      }

      final dbFile = await _getDbFile();
      if (!await dbFile.exists()) {
        return EncryptResult.error('No se encontró la base de datos');
      }

      final plainBytes = await dbFile.readAsBytes();
      final iv = enc.IV.fromSecureRandom(16);
      final key = _deriveKey(password, iv.bytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(plainBytes, iv: iv);

      // Construir archivo: magic + iv + ciphertext
      final header = Uint8List.fromList(_magicHeader.codeUnits);
      final output =
          Uint8List(header.length + iv.bytes.length + encrypted.bytes.length)
            ..setRange(0, header.length, header)
            ..setRange(header.length, header.length + 16, iv.bytes)
            ..setRange(
              header.length + 16,
              header.length + 16 + encrypted.bytes.length,
              encrypted.bytes,
            );

      final docsDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .substring(0, 19);
      final outPath = p.join(docsDir.path, 'backup_$timestamp$_encExtension');

      await File(outPath).writeAsBytes(output);

      return EncryptResult(
        success: true,
        message: '🔒 Backup cifrado guardado exitosamente',
        filePath: outPath,
      );
    } catch (e) {
      debugPrint('EncryptedBackupService.encryptAndSave: $e');
      return EncryptResult.error('Error al cifrar: $e');
    }
  }

  // ─── Cifrar y compartir ─────────────────────────────────────────────────────

  /// Cifra el backup y abre el menú de compartir de Android.
  static Future<EncryptResult> encryptAndShare(String password) async {
    final result = await encryptAndSave(password);
    if (!result.success || result.filePath == null) return result;

    try {
      final timestamp = DateTime.now().toIso8601String().substring(0, 10);
      await Share.shareXFiles(
        [XFile(result.filePath!)],
        subject: 'WalletAI Backup Cifrado – $timestamp',
        text:
            '🔒 Backup cifrado de WalletAI. Necesitas la contraseña para restaurarlo.',
      );
      return const EncryptResult(
        success: true,
        message: 'Backup cifrado compartido exitosamente',
      );
    } catch (e) {
      return EncryptResult.error('Error al compartir: $e');
    }
  }

  // ─── Descifrar y restaurar ──────────────────────────────────────────────────

  /// Restaura un archivo `.walletai` dado su path y la contraseña correcta.
  static Future<EncryptResult> decryptAndRestore(
    String filePath,
    String password,
  ) async {
    try {
      final encFile = File(filePath);
      if (!await encFile.exists()) {
        return EncryptResult.error('El archivo no existe: $filePath');
      }

      final raw = await encFile.readAsBytes();

      // Validar header mágico
      if (raw.length < _magicHeader.length + 16 + 16) {
        return EncryptResult.error('Archivo inválido o corrupto');
      }

      final headerBytes = raw.sublist(0, _magicHeader.length);
      final headerStr = String.fromCharCodes(headerBytes);
      if (headerStr != _magicHeader) {
        return EncryptResult.error(
          'Archivo inválido. Asegúrate de seleccionar un backup .walletai de WalletAI',
        );
      }

      final ivBytes = Uint8List.fromList(
        raw.sublist(_magicHeader.length, _magicHeader.length + 16),
      );
      final iv = enc.IV(ivBytes);
      final key = _deriveKey(password, ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

      final cipherBytes = Uint8List.fromList(
        raw.sublist(_magicHeader.length + 16),
      );
      List<int> plainBytes;
      try {
        plainBytes = encrypter.decryptBytes(enc.Encrypted(cipherBytes), iv: iv);
      } catch (_) {
        return EncryptResult.error(
          '❌ Contraseña incorrecta. No se puede abrir el backup.',
        );
      }

      // Verificar que el resultado parece un SQLite válido
      if (plainBytes.length < 16 ||
          String.fromCharCodes(plainBytes.sublist(0, 6)) != 'SQLite') {
        return EncryptResult.error(
          '❌ Contraseña incorrecta o archivo corrupto.',
        );
      }

      final dbFile = await _getDbFile();

      // Backup de seguridad antes de restaurar
      if (await dbFile.exists()) {
        final dir = await getApplicationDocumentsDirectory();
        await dbFile.copy(p.join(dir.path, 'backup_antes_restaurar.db'));
      }

      await dbFile.writeAsBytes(plainBytes);

      return const EncryptResult(
        success: true,
        message:
            '✅ Restauración exitosa.\nReinicia la app para aplicar los cambios.',
      );
    } catch (e) {
      debugPrint('EncryptedBackupService.decryptAndRestore: $e');
      return EncryptResult.error('Error al restaurar: $e');
    }
  }

  // ─── Verificar contraseña ───────────────────────────────────────────────────

  /// Verifica si un archivo `.walletai` puede abrirse con la contraseña dada,
  /// sin modificar la base de datos. Útil para validación previa.
  static Future<bool> verifyPassword(String filePath, String password) async {
    try {
      final raw = await File(filePath).readAsBytes();
      if (raw.length < _magicHeader.length + 16 + 16) return false;

      final headerStr = String.fromCharCodes(
        raw.sublist(0, _magicHeader.length),
      );
      if (headerStr != _magicHeader) return false;

      final ivBytes = Uint8List.fromList(
        raw.sublist(_magicHeader.length, _magicHeader.length + 16),
      );
      final iv = enc.IV(ivBytes);
      final key = _deriveKey(password, ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final cipherBytes = Uint8List.fromList(
        raw.sublist(_magicHeader.length + 16),
      );

      final plainBytes = encrypter.decryptBytes(
        enc.Encrypted(cipherBytes),
        iv: iv,
      );
      return plainBytes.length >= 6 &&
          String.fromCharCodes(plainBytes.sublist(0, 6)) == 'SQLite';
    } catch (_) {
      return false;
    }
  }
}
