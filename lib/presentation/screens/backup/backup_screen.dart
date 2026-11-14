import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/auto_sync_service.dart';
import '../../../data/datasources/backup_package_service.dart';
import '../../../data/datasources/backup_service.dart';
import '../../../data/datasources/cloud_account_service.dart';
import '../../../data/datasources/encrypted_backup_service.dart';
import '../../providers/database_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  // Google Drive
  GoogleSignInAccount? _googleUser;
  List<drive.File> _driveBackups = [];
  bool _loadingDrive = false;

  // Cuenta Nube WalletAI (Opción A)
  String? _cloudUsername;
  String? _cloudLastSyncedAt;
  CloudBackupMetadata? _cloudBackupMeta;
  bool _loadingCloudStatus = false;

  // Auto-Sync & Local
  bool _isLoading = false;
  bool _autoSyncEnabled = false;
  String _autoSyncFrequency = 'daily';
  String _autoSyncDestination = 'cloud';
  String? _autoSyncLastStatus;
  String? _autoSyncLastTime;
  String? _customLocalDir;

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    await Future.wait([
      _checkGoogleSession(),
      _loadCloudSession(),
      _loadAutoSyncPrefs(),
      _loadLocalDirPref(),
    ]);
  }

  Future<void> _loadLocalDirPref() async {
    final customDir = await BackupPackageService.getCustomLocalBackupDir();
    if (mounted) {
      setState(() => _customLocalDir = customDir);
    }
  }

  Future<void> _loadAutoSyncPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoSyncEnabled = prefs.getBool(kAutoSyncEnabledKey) ?? false;
      _autoSyncFrequency = prefs.getString(kAutoSyncFrequencyKey) ?? 'daily';
      _autoSyncDestination =
          prefs.getString(kAutoSyncDestinationKey) ?? 'cloud';
      _autoSyncLastStatus = prefs.getString(kAutoSyncLastStatusKey);
      _autoSyncLastTime = prefs.getString(kAutoSyncLastTimeKey);
    });
  }

  Future<void> _loadCloudSession() async {
    final session = await CloudAccountService.getSessionInfo();
    if (!mounted) return;
    setState(() {
      _cloudUsername = session.username;
      _cloudLastSyncedAt = session.lastSyncedAt;
    });
    if (session.token != null && session.token!.isNotEmpty) {
      await _refreshCloudStatus();
    }
  }

  Future<void> _refreshCloudStatus() async {
    if (!mounted) return;
    setState(() => _loadingCloudStatus = true);
    final res = await CloudAccountService.fetchStatus();
    if (!mounted) return;
    setState(() {
      _loadingCloudStatus = false;
      if (res.success) {
        _cloudBackupMeta = res.latestBackup;
      }
    });
  }

  String _formatIsoDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Duration _frequencyToDuration(String freq) {
    switch (freq) {
      case '12h':
        return const Duration(hours: 12);
      case 'weekly':
        return const Duration(days: 7);
      default:
        return const Duration(hours: 24);
    }
  }

  Future<void> _updateAutoSync({
    required bool enabled,
    required String frequency,
    required String destination,
  }) async {
    setState(() {
      _autoSyncEnabled = enabled;
      _autoSyncFrequency = frequency;
      _autoSyncDestination = destination;
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kAutoSyncEnabledKey, enabled);
    await prefs.setString(kAutoSyncFrequencyKey, frequency);
    await prefs.setString(kAutoSyncDestinationKey, destination);

    final service = AutoSyncService();
    if (enabled) {
      final needsDrive =
          destination == 'drive' || destination == 'drive_and_local';
      final needsCloud =
          destination == 'cloud' || destination == 'cloud_and_local';

      if (needsDrive && _googleUser == null) {
        await _signInGoogle();
        if (_googleUser == null) {
          await prefs.setBool(kAutoSyncEnabledKey, false);
          if (mounted) {
            setState(() {
              _autoSyncEnabled = false;
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (needsCloud && _cloudUsername == null) {
        await prefs.setBool(kAutoSyncEnabledKey, false);
        if (mounted) {
          setState(() {
            _autoSyncEnabled = false;
            _isLoading = false;
          });
          _showResult(
            const BackupResult(
              success: false,
              message:
                  'Inicia sesión primero con tu Cuenta WalletAI para activar el respaldo automático en la nube.',
            ),
          );
        }
        return;
      }

      await service.registerPeriodicTask(
        frequency: _frequencyToDuration(frequency),
        destination: destination,
      );
      _showResult(
        const BackupResult(
          success: true,
          message: '✅ Respaldo automático configurado',
        ),
      );
    } else {
      await service.cancelTask();
      _showResult(
        const BackupResult(
          success: true,
          message: 'Respaldo automático desactivado',
        ),
      );
    }
  }

  void _showResult(BackupResult result) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? Colors.green.shade600
            : Colors.red.shade600,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  // ─── CUENTA NUBE WALLETAI (OPCIÓN A) ─────────────────────────────────────

  Future<void> _openCloudAuthDialog({required bool isRegister}) async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool obscure = true;
    String? errorMsg;
    bool submitting = false;

    final result =
        await showDialog<
          ({
            bool success,
            String message,
            CloudBackupMetadata? latestBackup,
            String username,
          })
        >(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDialogState) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.account_circle_outlined),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      isRegister
                          ? 'Crear cuenta WalletAI'
                          : 'Iniciar sesión WalletAI',
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRegister
                        ? 'Crea un usuario y contraseña para respaldar tus finanzas y recuperarlas en otro celular.'
                        : 'Ingresa tus credenciales para sincronizar o restaurar tu copia de seguridad.',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: userCtrl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Usuario o correo',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passCtrl,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      hintText: 'Mínimo 6 caracteres',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final u = userCtrl.text.trim();
                          final p = passCtrl.text;
                          if (u.length < 3 || p.length < 6) {
                            setDialogState(() {
                              errorMsg =
                                  'Usuario mínimo 3 caracteres y contraseña mínimo 6.';
                            });
                            return;
                          }
                          setDialogState(() {
                            submitting = true;
                            errorMsg = null;
                          });
                          final authRes =
                              await CloudAccountService.authenticate(
                                isRegister: isRegister,
                                username: u,
                                password: p,
                              );
                          if (!ctx.mounted) return;
                          if (authRes.success) {
                            Navigator.pop(ctx, (
                              success: true,
                              message: authRes.message,
                              latestBackup: authRes.latestBackup,
                              username: u.toLowerCase(),
                            ));
                          } else {
                            setDialogState(() {
                              submitting = false;
                              errorMsg = authRes.message;
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(isRegister ? 'Registrar' : 'Entrar'),
                ),
              ],
            ),
          ),
        );

    if (result == null || !result.success || !mounted) return;

    await _loadCloudSession();
    _showResult(BackupResult(success: true, message: result.message));

    // Detectar si existe copia previa en la nube (útil al iniciar sesión en nuevo celular)
    final backup = result.latestBackup;
    if (backup != null && backup.exists && mounted) {
      final restoreNow = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.cloud_download, color: Colors.blue),
              SizedBox(width: 8),
              Flexible(child: Text('Copia de seguridad encontrada')),
            ],
          ),
          content: Text(
            'Se encontró un respaldo en tu cuenta (${result.username}):\n\n'
            '• Dispositivo origen: ${backup.deviceName ?? "Otro equipo"}\n'
            '• Fecha: ${_formatIsoDate(backup.updatedAt)}\n'
            '• Contenido: ${backup.accountsCount} cuentas, '
            '${backup.categoriesCount} categorías, '
            '${backup.transactionsCount} movimientos.\n\n'
            '¿Deseas restaurarlo ahora en este dispositivo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Más tarde'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restaurar ahora'),
            ),
          ],
        ),
      );

      if (restoreNow == true && mounted) {
        await _restoreFromCloudAccount(skipConfirm: true);
      }
    }
  }

  Future<void> _uploadToCloudAccount({bool force = false}) async {
    setState(() => _isLoading = true);
    final activeDb = ref.read(databaseProvider);
    final res = await CloudAccountService.uploadUnifiedBackup(
      activeDb: activeDb,
      force: force,
    );

    if (!mounted) return;
    if (res.hasConflict && res.serverBackup != null) {
      setState(() => _isLoading = false);
      final b = res.serverBackup!;
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.sync_problem, color: Colors.orange),
              SizedBox(width: 8),
              Flexible(child: Text('Conflicto entre dispositivos')),
            ],
          ),
          content: Text(
            'Otro dispositivo (${b.deviceName ?? "Otro equipo"}) guardó un respaldo más reciente el ${_formatIsoDate(b.updatedAt)} '
            '(${b.accountsCount} cuentas, ${b.transactionsCount} movimientos).\n\n'
            'Si sobrescribes con este equipo, los cambios del otro dispositivo podrían perderse.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'download'),
              child: const Text('Descargar nube'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, 'force'),
              child: const Text('Sobrescribir nube'),
            ),
          ],
        ),
      );
      if (action == 'download') {
        await _restoreFromCloudAccount(skipConfirm: true);
      } else if (action == 'force') {
        await _uploadToCloudAccount(force: true);
      }
      return;
    }

    await _loadCloudSession();
    _showResult(BackupResult(success: res.success, message: res.message));
  }

  Future<void> _restoreFromCloudAccount({bool skipConfirm = false}) async {
    if (!skipConfirm) {
      final confirm = await _showRestoreConfirmDialog(
        fileName: 'Respaldo en Nube (${_cloudUsername ?? ""})',
      );
      if (!confirm) return;
    }
    setState(() => _isLoading = true);
    final res = await CloudAccountService.downloadAndRestore(ref: ref);
    if (!mounted) return;
    await _loadCloudSession();
    await _loadAutoSyncPrefs();
    _showResult(BackupResult(success: res.success, message: res.message));
  }

  Future<void> _signOutCloud() async {
    await CloudAccountService.signOut();
    if (!mounted) return;
    setState(() {
      _cloudUsername = null;
      _cloudLastSyncedAt = null;
      _cloudBackupMeta = null;
    });
  }

  // ─── ENCRYPTED ────────────────────────────────────────────────────────────

  Future<void> _encryptAndSave() async {
    final password = await _showPasswordDialog(
      title: 'Nueva contraseña de cifrado',
    );
    if (password == null) return;
    setState(() => _isLoading = true);
    final result = await EncryptedBackupService.encryptAndSave(
      password,
      activeDb: ref.read(databaseProvider),
    );
    _showResult(BackupResult(success: result.success, message: result.message));
  }

  Future<void> _encryptAndShare() async {
    final password = await _showPasswordDialog(
      title: 'Nueva contraseña de cifrado',
    );
    if (password == null) return;
    setState(() => _isLoading = true);
    final result = await EncryptedBackupService.encryptAndShare(
      password,
      activeDb: ref.read(databaseProvider),
    );
    _showResult(BackupResult(success: result.success, message: result.message));
  }

  Future<void> _restoreEncrypted() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (picked == null || picked.files.single.path == null) return;
    final filePath = picked.files.single.path!;

    final password = await _showPasswordDialog(
      title: 'Contraseña del backup cifrado',
      hint: 'Ingresa la contraseña con la que se cifró el backup',
      confirmMode: false,
    );
    if (password == null) return;

    final confirm = await _showRestoreConfirmDialog(
      fileName: picked.files.single.name,
    );
    if (!confirm) return;

    setState(() => _isLoading = true);
    final result = await EncryptedBackupService.decryptAndRestore(
      filePath,
      password,
      ref: ref,
    );
    await _loadAutoSyncPrefs();
    _showResult(BackupResult(success: result.success, message: result.message));
  }

  Future<String?> _showPasswordDialog({
    required String title,
    String? hint,
    bool confirmMode = true,
  }) async {
    final controller1 = TextEditingController();
    final controller2 = TextEditingController();
    bool visible1 = false;
    bool visible2 = false;
    String? error;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.lock_outline),
              const SizedBox(width: 8),
              Flexible(
                child: Text(title, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hint != null) ...[
                Text(
                  hint,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller1,
                obscureText: !visible1,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  hintText: 'Mínimo 4 caracteres',
                  errorText: error,
                  prefixIcon: const Icon(Icons.password),
                  suffixIcon: IconButton(
                    icon: Icon(
                      visible1 ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setDialogState(() => visible1 = !visible1),
                  ),
                ),
              ),
              if (confirmMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: controller2,
                  obscureText: !visible2,
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.password),
                    suffixIcon: IconButton(
                      icon: Icon(
                        visible2 ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () =>
                          setDialogState(() => visible2 = !visible2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final pass = controller1.text.trim();
                if (pass.length < 4) {
                  setDialogState(() => error = 'Mínimo 4 caracteres');
                  return;
                }
                if (confirmMode && pass != controller2.text.trim()) {
                  setDialogState(() => error = 'Las contraseñas no coinciden');
                  return;
                }
                Navigator.pop(ctx, pass);
              },
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── LOCAL ────────────────────────────────────────────────────────────────

  Future<void> _backupLocally() async {
    setState(() => _isLoading = true);
    final result = await BackupService.backupLocally(
      activeDb: ref.read(databaseProvider),
    );
    _showResult(result);
  }

  Future<void> _exportWithPicker() async {
    setState(() => _isLoading = true);
    final result = await BackupService.exportWithFilePicker(
      activeDb: ref.read(databaseProvider),
    );
    _showResult(result);
  }

  Future<void> _pickLocalDirectory() async {
    final selected = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Elige carpeta para backups automáticos',
    );
    if (selected == null) return;
    await BackupPackageService.setCustomLocalBackupDir(selected);
    await _loadLocalDirPref();
    _showResult(
      BackupResult(
        success: true,
        message: 'Carpeta local configurada:\n$selected',
      ),
    );
  }

  Future<void> _shareBackup() async {
    setState(() => _isLoading = true);
    final result = await BackupService.shareBackup(
      activeDb: ref.read(databaseProvider),
    );
    _showResult(result);
  }

  Future<void> _restoreLocal() async {
    final confirm = await _showRestoreConfirmDialog();
    if (!confirm) return;
    setState(() => _isLoading = true);
    final result = await BackupService.restoreFromLocalFile(
      ref: ref,
      promptPassword: () => _showPasswordDialog(
        title: 'Contraseña del respaldo',
        confirmMode: false,
      ),
    );
    await _loadAutoSyncPrefs();
    _showResult(result);
  }

  // ─── GOOGLE DRIVE ─────────────────────────────────────────────────────────

  Future<void> _checkGoogleSession() async {
    try {
      final user = await BackupService.getSignedInUser();
      if (mounted) {
        setState(() => _googleUser = user);
        if (user != null) _loadDriveBackups();
      }
    } catch (e) {
      debugPrint('Check session error: $e');
    }
  }

  Future<void> _loadDriveBackups() async {
    setState(() => _loadingDrive = true);
    final backups = await BackupService.listDriveBackups();
    if (mounted) {
      setState(() {
        _driveBackups = backups;
        _loadingDrive = false;
      });
    }
  }

  Future<void> _signInGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await BackupService.signInWithGoogle();
      if (!mounted) return;
      setState(() {
        _googleUser = user;
        _isLoading = false;
      });
      if (user != null) {
        _loadDriveBackups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inicio de sesión cancelado por el usuario'),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final isDevError =
          e.code == 'sign_in_failed' && (e.message?.contains('10') ?? false);
      final msg = isDevError
          ? 'Google Sign-In rechazado (código 10: OAuth/SHA-1). Registra el paquete com.finanzas.aplicativo_gastos y el SHA-1 release en Google Cloud Console.'
          : 'Error Google Sign-In (${e.code}): ${e.message ?? e}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de Google Sign-In: $e'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _signOutGoogle() async {
    await BackupService.signOutGoogle();
    if (!mounted) return;
    setState(() {
      _googleUser = null;
      _driveBackups = [];
    });
  }

  Future<void> _backupToDrive() async {
    setState(() => _isLoading = true);
    final result = await BackupService.backupToDrive(
      activeDb: ref.read(databaseProvider),
    );
    _showResult(result);
    if (result.success) _loadDriveBackups();
  }

  Future<void> _restoreFromDrive(drive.File file) async {
    final confirm = await _showRestoreConfirmDialog(fileName: file.name);
    if (!confirm) return;
    setState(() => _isLoading = true);
    final result = await BackupService.restoreFromDrive(
      file.id!,
      ref: ref,
      promptPassword: () => _showPasswordDialog(
        title: 'Contraseña del respaldo en Drive',
        confirmMode: false,
      ),
    );
    await _loadAutoSyncPrefs();
    _showResult(result);
  }

  Future<void> _deleteDriveBackup(drive.File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar backup'),
        content: Text(
          '¿Eliminar "${file.name}"?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isLoading = true);
    final result = await BackupService.deleteDriveBackup(file.id!);
    _showResult(result);
    if (result.success) _loadDriveBackups();
  }

  Future<bool> _showRestoreConfirmDialog({String? fileName}) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Flexible(child: Text('Confirmar restauración')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fileName != null)
                  Text(
                    'Origen: $fileName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Se restaurarán tus cuentas, saldos, fechas de corte, categorías, subcategorías, transacciones y configuración de la app.\n\n'
                  'Antes se creará un respaldo de seguridad automático.',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Restaurar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Copias de Seguridad'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Banner informativo ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.shield, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Respaldo unificado v2: incluye cuentas, montos, cortes, categorías/subcategorías ampliadas, movimientos y preferencias de la app.',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── CUENTA WALLETAI EN LA NUBE (OPCIÓN A) ───────────────────────
          _SectionHeader(
            icon: Icons.cloud_sync,
            title: 'Cuenta WalletAI (Nube Multi-dispositivo)',
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _cloudUsername == null
                ? Column(
                    children: [
                      _ActionTile(
                        icon: Icons.login,
                        iconColor: cs.primary,
                        title: 'Iniciar sesión con usuario y contraseña',
                        subtitle:
                            'Detecta y restaura tu copia al cambiar de celular',
                        onTap: _isLoading
                            ? null
                            : () => _openCloudAuthDialog(isRegister: false),
                      ),
                      const Divider(height: 1, indent: 56),
                      _ActionTile(
                        icon: Icons.person_add_alt_1,
                        iconColor: Colors.teal,
                        title: 'Crear cuenta nueva en la nube',
                        subtitle:
                            'Guarda una copia unificada protegida para tus equipos',
                        onTap: _isLoading
                            ? null
                            : () => _openCloudAuthDialog(isRegister: true),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: cs.primaryContainer,
                          child: Icon(Icons.person, color: cs.primary),
                        ),
                        title: Text(
                          _cloudUsername!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _loadingCloudStatus
                              ? 'Consultando respaldo en la nube...'
                              : (_cloudBackupMeta?.exists == true
                                    ? 'Última copia: ${_formatIsoDate(_cloudBackupMeta!.updatedAt)} (${_cloudBackupMeta!.deviceName ?? "Equipo"})\n'
                                          '${_cloudBackupMeta!.accountsCount} cuentas • ${_cloudBackupMeta!.transactionsCount} movs'
                                    : (_cloudLastSyncedAt != null
                                          ? 'Última sincronización local: ${_formatIsoDate(_cloudLastSyncedAt)}'
                                          : 'Sin respaldo subido aún en la nube')),
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          tooltip: 'Cerrar sesión',
                          onPressed: _signOutCloud,
                        ),
                      ),
                      const Divider(height: 1, indent: 56),
                      _ActionTile(
                        icon: Icons.cloud_upload,
                        iconColor: Colors.blue,
                        title: 'Subir copia ahora a mi cuenta',
                        subtitle:
                            'Con detección de conflictos si usas dos celulares',
                        onTap: _isLoading
                            ? null
                            : () => _uploadToCloudAccount(),
                      ),
                      const Divider(height: 1, indent: 56),
                      _ActionTile(
                        icon: Icons.cloud_download,
                        iconColor: Colors.green,
                        title: 'Restaurar desde mi cuenta',
                        subtitle:
                            'Descarga cuentas, categorías, saldos y ajustes',
                        onTap: (_isLoading || _cloudBackupMeta?.exists != true)
                            ? null
                            : () => _restoreFromCloudAccount(),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ─── RESPALDO AUTOMÁTICO CONFIGURABLE ────────────────────────────
          _SectionHeader(
            icon: Icons.schedule,
            title: 'Respaldo Automático por Destino',
          ),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(Icons.sync, color: Colors.blue.shade700),
                  title: const Text(
                    'Activar respaldo automático',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    _autoSyncEnabled
                        ? 'Activo ($_autoSyncFrequency → $_autoSyncDestination)'
                        : 'Desactivado',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _autoSyncEnabled,
                  onChanged: _isLoading
                      ? null
                      : (val) => _updateAutoSync(
                          enabled: val,
                          frequency: _autoSyncFrequency,
                          destination: _autoSyncDestination,
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _autoSyncDestination,
                        decoration: const InputDecoration(
                          labelText: 'Destino automático',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'cloud',
                            child: Text('Cuenta WalletAI (Nube)'),
                          ),
                          DropdownMenuItem(
                            value: 'drive',
                            child: Text('Google Drive'),
                          ),
                          DropdownMenuItem(
                            value: 'local',
                            child: Text('Carpeta Local persistente'),
                          ),
                          DropdownMenuItem(
                            value: 'cloud_and_local',
                            child: Text('Cuenta WalletAI + Local'),
                          ),
                          DropdownMenuItem(
                            value: 'drive_and_local',
                            child: Text('Google Drive + Local'),
                          ),
                        ],
                        onChanged: _isLoading
                            ? null
                            : (val) {
                                if (val != null) {
                                  _updateAutoSync(
                                    enabled: _autoSyncEnabled,
                                    frequency: _autoSyncFrequency,
                                    destination: val,
                                  );
                                }
                              },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _autoSyncFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frecuencia',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '12h',
                            child: Text('Cada 12 horas'),
                          ),
                          DropdownMenuItem(
                            value: 'daily',
                            child: Text('Diario (24h)'),
                          ),
                          DropdownMenuItem(
                            value: 'weekly',
                            child: Text('Semanal (7 días)'),
                          ),
                        ],
                        onChanged: _isLoading
                            ? null
                            : (val) {
                                if (val != null) {
                                  _updateAutoSync(
                                    enabled: _autoSyncEnabled,
                                    frequency: val,
                                    destination: _autoSyncDestination,
                                  );
                                }
                              },
                      ),
                      if (_autoSyncLastTime != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Última ejecución: ${_formatIsoDate(_autoSyncLastTime)} — ${_autoSyncLastStatus ?? ""}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── BACKUP LOCAL ────────────────────────────────────────────────
          _SectionHeader(icon: Icons.phone_android, title: 'Backup Local'),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.save,
                  iconColor: Colors.blue,
                  title: 'Guardar respaldo completo (.wbackup)',
                  subtitle: _customLocalDir != null
                      ? 'Carpeta: $_customLocalDir'
                      : 'Guarda en Download/WalletAI (sobrevive desinstalación)',
                  onTap: _isLoading ? null : _backupLocally,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.drive_file_move_outline,
                  iconColor: Colors.teal,
                  title: 'Exportar eligiendo carpeta (Descargas / Documentos)',
                  subtitle: 'Abre el selector nativo del sistema (SAF)',
                  onTap: _isLoading ? null : _exportWithPicker,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.folder_open,
                  iconColor: Colors.amber.shade700,
                  title: 'Configurar carpeta local automática',
                  subtitle: _customLocalDir ?? 'Por defecto: Download/WalletAI',
                  onTap: _isLoading ? null : _pickLocalDirectory,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.share,
                  iconColor: Colors.green,
                  title: 'Compartir por Correo, TeraBox o WhatsApp',
                  subtitle: 'Envía tu copia unificada por la app que prefieras',
                  onTap: _isLoading ? null : _shareBackup,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.restore,
                  iconColor: Colors.orange,
                  title: 'Restaurar desde archivo (.wbackup / .walletai / .db)',
                  subtitle: 'Importa y recarga todos los datos al instante',
                  onTap: _isLoading ? null : _restoreLocal,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── BACKUP CIFRADO ──────────────────────────────────────────────
          _SectionHeader(icon: Icons.lock, title: 'Backup Cifrado (AES-256)'),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _ActionTile(
                  icon: Icons.lock_outline,
                  iconColor: Colors.purple,
                  title: 'Guardar cifrado (.walletai)',
                  subtitle:
                      'Paquete completo (BD + ajustes) protegido con clave',
                  onTap: _isLoading ? null : _encryptAndSave,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.share,
                  iconColor: Colors.deepPurple,
                  title: 'Cifrar y compartir (Email / TeraBox)',
                  subtitle: 'Envía tu archivo .walletai protegido',
                  onTap: _isLoading ? null : _encryptAndShare,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.lock_open,
                  iconColor: Colors.indigo,
                  title: 'Restaurar backup cifrado',
                  subtitle: 'Abre .walletai V1 o V2 e ingresa la contraseña',
                  onTap: _isLoading ? null : _restoreEncrypted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── GOOGLE DRIVE ────────────────────────────────────────────────
          _SectionHeader(icon: Icons.cloud, title: 'Google Drive'),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _googleUser == null
                ? _ActionTile(
                    icon: Icons.login,
                    iconColor: cs.primary,
                    title: 'Iniciar sesión con Google',
                    subtitle: 'Conecta tu cuenta para respaldar en Drive',
                    onTap: _isLoading ? null : _signInGoogle,
                  )
                : Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: _googleUser!.photoUrl != null
                              ? NetworkImage(_googleUser!.photoUrl!)
                              : null,
                          child: _googleUser!.photoUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(
                          _googleUser!.displayName ?? 'Usuario de Google',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(_googleUser!.email),
                        trailing: TextButton(
                          onPressed: _signOutGoogle,
                          child: const Text(
                            'Salir',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 72),
                      _ActionTile(
                        icon: Icons.cloud_upload,
                        iconColor: Colors.blue,
                        title: 'Subir backup completo a Drive',
                        subtitle:
                            'Sube cuentas, categorías, movimientos y configuración',
                        onTap: _isLoading ? null : _backupToDrive,
                      ),
                    ],
                  ),
          ),

          if (_googleUser != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Backups en Drive',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadingDrive ? null : _loadDriveBackups,
                  tooltip: 'Actualizar lista',
                ),
              ],
            ),
            if (_loadingDrive)
              const Center(child: CircularProgressIndicator())
            else if (_driveBackups.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay backups en Drive',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _driveBackups.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 16),
                  itemBuilder: (context, index) {
                    final file = _driveBackups[index];
                    final date = file.createdTime;
                    final sizeKb = file.size != null
                        ? '${(int.parse(file.size!) / 1024).toStringAsFixed(1)} KB'
                        : '—';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade50,
                        child: Icon(Icons.backup, color: Colors.blue.shade600),
                      ),
                      title: Text(
                        file.name ?? 'Backup sin nombre',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        date != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(date)
                            : '—',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            sizeKb,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'restore') {
                                _restoreFromDrive(file);
                              } else if (value == 'delete') {
                                _deleteDriveBackup(file);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'restore',
                                child: Row(
                                  children: [
                                    Icon(Icons.restore, size: 18),
                                    SizedBox(width: 8),
                                    Text('Restaurar'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Eliminar',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconColor.withValues(alpha: 0.12),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
