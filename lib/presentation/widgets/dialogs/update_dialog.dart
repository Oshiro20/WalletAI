import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/app_colors.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  final GithubRelease release;

  const UpdateDialog({
    super.key,
    required this.release,
  });

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  double _progress = 0;
  bool _isDownloading = false;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(updateServiceProvider);
      await service.downloadAndInstall(
        url: widget.release.apkUrl,
        fileName: widget.release.fileName,
        onProgress: (p) {
          setState(() => _progress = p);
        },
      );
      // Una vez que se abre el instalador, el diálogo puede cerrarse
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = 'Error al descargar la actualización. Reintenta más tarde.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Nueva versión!',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Versión ${widget.release.tagName}',
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.primaryLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (widget.release.body.isNotEmpty) ...[
              Text(
                'Novedades:',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.release.body,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.onSurface.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_isDownloading) ...[
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Descargando... ${(_progress * 100).toInt()}%',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ] else if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.expense,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (!_isDownloading)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Después',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _startUpdate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Actualizar ahora',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Función auxiliar para mostrar el diálogo
Future<void> showUpdateDialog(BuildContext context, GithubRelease release) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => UpdateDialog(release: release),
  );
}
