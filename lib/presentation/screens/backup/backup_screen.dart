import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/backup_service.dart';
import '../../../data/datasources/auto_sync_service.dart';
import '../../../data/datasources/encrypted_backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  GoogleSignInAccount? _googleUser;
  List<drive.File> _driveBackups = [];
  bool _isLoading = false;
  bool _loadingDrive = false;

  // Auto-Sync
  bool _autoSyncEnabled = false;
  String _autoSyncFrequency = 'daily'; // daily, weekly

  @override
  void initState() {
    super.initState();
    _checkGoogleSession();
    _loadAutoSyncPrefs();
  }

  Future<void> _loadAutoSyncPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoSyncEnabled = prefs.getBool('auto_sync_enabled') ?? false;
      _autoSyncFrequency = prefs.getString('auto_sync_frequency') ?? 'daily';
    });
  }

  Future<void> _updateAutoSync(bool enabled, String frequency) async {
    setState(() {
      _autoSyncEnabled = enabled;
      _autoSyncFrequency = frequency;
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync_enabled', enabled);
    await prefs.setString('auto_sync_frequency', frequency);

    final service = AutoSyncService();
    if (enabled) {
      if (_googleUser == null) await _signInGoogle();

      if (_googleUser != null) {
        final duration = frequency == 'weekly'
            ? const Duration(days: 7)
            : const Duration(hours: 24);
        await service.registerPeriodicTask(frequency: duration);
        _showResult(
          const BackupResult(
            success: true,
            message: 'Respaldo automático configurado',
          ),
        );
      } else {
        // No se pudo loguear
        setState(() => _autoSyncEnabled = false);
        await prefs.setBool('auto_sync_enabled', false);
        _showResult(
          const BackupResult(
            success: false,
            message: 'Requiere inicio de sesión en Google',
          ),
        );
      }
    } else {
      await service.cancelTask();
      _showResult(
        const BackupResult(
          success: true,
          message: 'Respaldo automático desactivado',
        ),
      );
    }

    setState(() => _isLoading = false);
  }

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

  void _showResult(BackupResult result) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success
            ? Colors.green.shade600
            : Colors.red.shade600,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ─── ENCRYPTED ────────────────────────────────────────────────────────────

  Future<void> _encryptAndSave() async {
    final password = await _showPasswordDialog(
      title: 'Nueva contraseña de cifrado',
    );
    if (password == null) return;
    setState(() => _isLoading = true);
    final result = await EncryptedBackupService.encryptAndSave(password);
    _showResult(BackupResult(success: result.success, message: result.message));
  }

  Future<void> _encryptAndShare() async {
    final password = await _showPasswordDialog(
      title: 'Nueva contraseña de cifrado',
    );
    if (password == null) return;
    setState(() => _isLoading = true);
    final result = await EncryptedBackupService.encryptAndShare(password);
    _showResult(BackupResult(success: result.success, message: result.message));
  }

  Future<void> _restoreEncrypted() async {
    // 1. Seleccionar archivo
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (picked == null || picked.files.single.path == null) return;
    final filePath = picked.files.single.path!;

    if (!filePath.endsWith('.walletai')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un archivo .walletai de WalletAI'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 2. Pedir contraseña
    final password = await _showPasswordDialog(
      title: 'Contraseña del backup cifrado',
      hint: 'Ingresa la contraseña con la que se cifró el backup',
      confirmMode: false,
    );
    if (password == null) return;

    // 3. Confirmar restauración
    final confirm = await _showRestoreConfirmDialog();
    if (!confirm) return;

    setState(() => _isLoading = true);
    final result = await EncryptedBackupService.decryptAndRestore(
      filePath,
      password,
    );
    _showResult(BackupResult(success: result.success, message: result.message));
  }

  /// Muestra un diálogo de ingreso de contraseña.
  /// En [confirmMode] = true, pide la contraseña dos veces para confirmar.
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
    final result = await BackupService.backupLocally();
    _showResult(result);
  }

  Future<void> _shareBackup() async {
    setState(() => _isLoading = true);
    final result = await BackupService.shareBackup();
    _showResult(result);
  }

  Future<void> _restoreLocal() async {
    final confirm = await _showRestoreConfirmDialog();
    if (!confirm) return;
    setState(() => _isLoading = true);
    final result = await BackupService.restoreFromLocalFile();
    _showResult(result);
  }

  // ─── GOOGLE DRIVE ─────────────────────────────────────────────────────────

  Future<void> _signInGoogle() async {
    setState(() => _isLoading = true);
    try {
      final user = await BackupService.signInWithGoogle();
      setState(() {
        _googleUser = user;
        _isLoading = false;
      });
      if (user != null) {
        _loadDriveBackups();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inicio de sesión cancelado o fallido'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error de Google Sign-In: $e\n(Posible falta de configuración SHA-1)',
            ),
            backgroundColor: Colors.red.shade600,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _signOutGoogle() async {
    await BackupService.signOutGoogle();
    setState(() {
      _googleUser = null;
      _driveBackups = [];
    });
  }

  Future<void> _backupToDrive() async {
    setState(() => _isLoading = true);
    final result = await BackupService.backupToDrive();
    _showResult(result);
    if (result.success) _loadDriveBackups();
  }

  Future<void> _restoreFromDrive(drive.File file) async {
    final confirm = await _showRestoreConfirmDialog(fileName: file.name);
    if (!confirm) return;
    setState(() => _isLoading = true);
    final result = await BackupService.restoreFromDrive(file.id!);
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
                Text('⚠️ Confirmar restauración'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fileName != null)
                  Text(
                    'Archivo: $fileName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Esto reemplazará TODOS tus datos actuales con los del backup.\n\n'
                  'Se hará un respaldo automático de seguridad antes de restaurar.',
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
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shield,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Haz backups regularmente para no perder tus datos financieros.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
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
                  title: 'Guardar en el dispositivo',
                  subtitle:
                      'Guarda un archivo .db en la memoria de tu teléfono',
                  onTap: _isLoading ? null : _backupLocally,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.share,
                  iconColor: Colors.green,
                  title: 'Compartir backup',
                  subtitle: 'Envía vía WhatsApp, email, Terabox u otra app',
                  onTap: _isLoading ? null : _shareBackup,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.restore,
                  iconColor: Colors.orange,
                  title: 'Restaurar desde archivo',
                  subtitle:
                      'Abre un archivo .db de tu galería o almacenamiento',
                  onTap: _isLoading ? null : _restoreLocal,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ─── BACKUP CIFRADO ──────────────────────────────────────────────
          _SectionHeader(icon: Icons.lock, title: 'Backup Cifrado (AES-256)'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.enhanced_encryption,
                  color: Colors.purple.shade700,
                  size: 18,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Protege tu backup con una contraseña. '
                    'Solo quien tenga la clave puede restaurarlo.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
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
                  title: 'Guardar cifrado',
                  subtitle:
                      'Guarda un archivo .walletai protegido con contraseña',
                  onTap: _isLoading ? null : _encryptAndSave,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.share,
                  iconColor: Colors.deepPurple,
                  title: 'Cifrar y compartir',
                  subtitle:
                      'Comparte el backup cifrado vía WhatsApp, email, etc.',
                  onTap: _isLoading ? null : _encryptAndShare,
                ),
                const Divider(height: 1, indent: 56),
                _ActionTile(
                  icon: Icons.lock_open,
                  iconColor: Colors.indigo,
                  title: 'Restaurar backup cifrado',
                  subtitle: 'Abre un archivo .walletai e ingresa la contraseña',
                  onTap: _isLoading ? null : _restoreEncrypted,
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ─── GOOGLE DRIVE ────────────────────────────────────────────────
          _SectionHeader(icon: Icons.cloud, title: 'Google Drive'),
          const SizedBox(height: 12),

          // Estado de sesión Google
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: _googleUser == null
                ? _ActionTile(
                    icon: Icons.login,
                    iconColor: Theme.of(context).colorScheme.primary,
                    title: 'Iniciar sesión con Google',
                    subtitle: 'Conecta tu cuenta para sincronizar con Drive',
                    onTap: _isLoading ? null : _signInGoogle,
                    trailing: const Icon(Icons.chevron_right),
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
                      SwitchListTile(
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sync,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                        ),
                        title: const Text(
                          'Respaldo automático',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _autoSyncEnabled
                              ? (_autoSyncFrequency == 'daily'
                                    ? 'Cada 24 horas'
                                    : 'Semanalmente')
                              : 'Desactivado',
                        ),
                        value: _autoSyncEnabled,
                        onChanged: _isLoading
                            ? null
                            : (val) => _updateAutoSync(val, _autoSyncFrequency),
                      ),
                      if (_autoSyncEnabled)
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 72,
                            right: 16,
                            bottom: 12,
                          ),
                          child: DropdownButtonFormField<String>(
                            initialValue: _autoSyncFrequency,
                            decoration: const InputDecoration(
                              labelText: 'Frecuencia',
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'daily',
                                child: Text('Diario (24h)'),
                              ),
                              DropdownMenuItem(
                                value: 'weekly',
                                child: Text('Semanal (7 días)'),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) _updateAutoSync(true, val);
                            },
                          ),
                        ),
                      const Divider(height: 1, indent: 72),
                      _ActionTile(
                        icon: Icons.cloud_upload,
                        iconColor: Colors.blue,
                        title: 'Subir backup a Drive',
                        subtitle:
                            'Crea una nueva copia de seguridad en la nube',
                        onTap: _isLoading ? null : _backupToDrive,
                      ),
                    ],
                  ),
          ),

          // Lista de backups en Drive
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
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'restore',
                                child: Row(
                                  children: [
                                    Icon(Icons.restore, size: 18),
                                    SizedBox(width: 8),
                                    Text('Restaurar'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
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

// ─── WIDGETS AUXILIARES ────────────────────────────────────────────────────

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
  final Widget? trailing;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
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
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
