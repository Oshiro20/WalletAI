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
    final assets = json['assets'] as List<dynamic>;
    // Buscamos el primer asset que termine en .apk
    final apkAsset = assets.firstWhere(
      (asset) => asset['name'].toString().endsWith('.apk'),
      orElse: () =>
          throw Exception('No se encontró un archivo APK en el release.'),
    );

    return GithubRelease(
      tagName: json['tag_name'],
      body: json['body'] ?? '',
      apkUrl: apkAsset['browser_download_url'],
      fileName: apkAsset['name'],
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

        // Comparamos versiones. Ejemplo: v1.1.0 vs 1.1.0
        // Limpiamos el tag_name de posibles prefijos 'v'
        final latestVersion = release.tagName.replaceAll('v', '');
        final currentVersion = packageInfo.version;

        if (_isVersionGreater(latestVersion, currentVersion)) {
          return release;
        }
      }
    } catch (e) {
      // Silenciamos errores de red o API para no interrumpir al usuario
      _logger.e('Error al verificar actualización: $e');
    }

    return null;
  }

  /// Compara dos hilos de versión (semanticos)
  bool _isVersionGreater(String latest, String current) {
    List<int> latestParts = latest.split('.').map(int.parse).toList();
    List<int> currentParts = current.split('.').map(int.parse).toList();

    for (var i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
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
