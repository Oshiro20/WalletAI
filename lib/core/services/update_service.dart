import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:open_filex/open_filex.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Modelo simplificado para el lanzamiento de GitHub
class GithubRelease {
  final String tagName;
  final String body;
  final String apkUrl;
  final String fileName;

  GithubRelease({
    required this.tagName,
    required this.body,
    required this.apkUrl,
    required this.fileName,
  });

  factory GithubRelease.fromJson(Map<String, dynamic> json) {
    final assets = (json['assets'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final apks = assets
        .where(
          (asset) =>
              (asset['name']?.toString().toLowerCase() ?? '').endsWith('.apk'),
        )
        .toList();
    if (apks.isEmpty) {
      throw Exception('No se encontró un archivo APK en el release.');
    }

    // Preferir APK universal o arm64 antes que builds armeabi/x86
    final abiHint = Platform.version.toLowerCase();
    final preferArm64 =
        !abiHint.contains('arm_x64') &&
        (abiHint.contains('arm64') || abiHint.contains('aarch64'));
    final apkAsset = apks.firstWhere(
      (a) {
        final name = a['name'].toString().toLowerCase();
        if (preferArm64 && name.contains('arm64')) return true;
        return !name.contains('armeabi') &&
            !name.contains('x86') &&
            !name.contains('arm64');
      },
      orElse: () => apks.first,
    );

    return GithubRelease(
      tagName: json['tag_name']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      apkUrl: apkAsset['browser_download_url']?.toString() ?? '',
      fileName: apkAsset['name']?.toString() ?? 'WalletAI-update.apk',
    );
  }
}

class UpdateService {
  final Dio _dio = Dio();
  final _logger = Logger();
  final String repoPath = 'Oshiro20/WalletAI';

  /// Verifica si hay una nueva versión disponible
  Future<GithubRelease?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$repoPath/releases/latest',
      );

      if (response.statusCode == 200) {
        final release = GithubRelease.fromJson(response.data);
        final packageInfo = await PackageInfo.fromPlatform();

        if (isVersionGreater(release.tagName, packageInfo.version)) {
          return release;
        }
      }
    } catch (e) {
      // Silenciamos errores de red o API para no interrumpir al usuario
      _logger.e('Error al verificar actualización: $e');
    }

    return null;
  }

  /// Compara dos versiones semánticas soportando prefijo 'v' y sufijos +build / -pre.
  static bool isVersionGreater(String latest, String current) {
    List<int> parse(String raw) {
      final clean = raw.trim().replaceFirst(
        RegExp(r'^v', caseSensitive: false),
        '',
      );
      final base = clean.split('+').first.split('-').first;
      return base.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    }

    final latestParts = parse(latest);
    final currentParts = parse(current);
    final maxLen = math.max(latestParts.length, currentParts.length);

    for (var i = 0; i < maxLen; i++) {
      final l = i < latestParts.length ? latestParts[i] : 0;
      final c = i < currentParts.length ? currentParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  /// Descarga e instala el APK
  Future<void> downloadAndInstall({
    required String url,
    required String fileName,
    required Function(double) onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = p.join(tempDir.path, fileName);

      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      // Abrir el instalador
      await OpenFilex.open(savePath);
    } catch (e) {
      _logger.e('Error durante descarga/instalación: $e');
      rethrow;
    }
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
