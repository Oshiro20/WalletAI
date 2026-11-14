import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/ecosystem_sync_service.dart';
import '../../../core/services/mylifeos_integration_service.dart';
import '../../../data/datasources/cloud_account_service.dart';
import '../../providers/database_providers.dart';

class MyLifeOSIntegrationScreen extends ConsumerStatefulWidget {
  const MyLifeOSIntegrationScreen({super.key});

  @override
  ConsumerState<MyLifeOSIntegrationScreen> createState() =>
      _MyLifeOSIntegrationScreenState();
}

class _MyLifeOSIntegrationScreenState
    extends ConsumerState<MyLifeOSIntegrationScreen> {
  String? _projectId;
  String? _cloudUsername;
  int _pendingCount = 0;
  bool _loading = true;
  bool _syncingCloud = false;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProjectId();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadProjectId() async {
    final id = await MyLifeOSIntegrationService.getMyLifeOSProjectId();
    final session = await CloudAccountService.getSessionInfo();
    final pending = (session.token != null && session.token!.isNotEmpty)
        ? await EcosystemSyncService.fetchPendingTransactions()
        : const <Map<String, dynamic>>[];

    if (mounted) {
      setState(() {
        _projectId = id;
        _cloudUsername = session.username;
        _pendingCount = pending.length;
        _controller.text = id ?? '';
        _loading = false;
      });
    }
  }

  Future<void> _syncCloudEcosystem() async {
    setState(() => _syncingCloud = true);
    final db = ref.read(databaseProvider);
    final imported = await EcosystemSyncService.importAllPendingTransactions(
      db,
    );
    final published = await EcosystemSyncService.publishSummary(db);
    await _loadProjectId();

    if (mounted) {
      setState(() => _syncingCloud = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            published
                ? '☁️ Resumen publicado en la nube ($imported movimientos importados)'
                : '⚠️ Inicia sesión en Respaldos > Cuenta en la Nube para sincronizar entre apps.',
          ),
          backgroundColor: published
              ? const Color(0xFF00C896)
              : Colors.orange.shade700,
        ),
      );
    }
  }

  Future<void> _saveProjectId() async {
    final id = _controller.text.trim();
    if (id.isEmpty) {
      await MyLifeOSIntegrationService.setMyLifeOSProjectId('');
    } else {
      await MyLifeOSIntegrationService.setMyLifeOSProjectId(id);
    }
    await _loadProjectId();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project ID guardado'),
          backgroundColor: Color(0xFF00C896),
        ),
      );
    }
  }

  Future<void> _copyProjectId() async {
    if (_projectId == null || _projectId!.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _projectId!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project ID copiado'),
          backgroundColor: Color(0xFF00C896),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integración MyLifeOS')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Estado
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _projectId != null && _projectId!.isNotEmpty
                              ? Icons.check_circle
                              : Icons.link_off,
                          color: _projectId != null && _projectId!.isNotEmpty
                              ? const Color(0xFF00C896)
                              : Colors.orange,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _projectId != null && _projectId!.isNotEmpty
                                    ? 'Conectado'
                                    : 'Sin configurar',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _projectId != null && _projectId!.isNotEmpty
                                    ? 'El resumen se exporta automáticamente'
                                    : 'Ingresa el Project ID de MyLifeOS',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Project ID
                if (_projectId != null && _projectId!.isNotEmpty) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Project ID',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  _projectId!,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20),
                                onPressed: _copyProjectId,
                                tooltip: 'Copiar',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Input personalizado
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Project ID personalizado (opcional)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Ej: a1b2c3d4e5f6...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.tag),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveProjectId,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00C896),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Guardar'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Estado Nube Ecosistema (Render + PostgreSQL)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _cloudUsername != null
                                  ? Icons.cloud_done
                                  : Icons.cloud_off,
                              color: _cloudUsername != null
                                  ? const Color(0xFF00C896)
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _cloudUsername != null
                                        ? 'Cuenta Nube: $_cloudUsername'
                                        : 'Cuenta Nube no conectada',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    _cloudUsername != null
                                        ? 'Pendientes desde MyLifeOS: $_pendingCount'
                                        : 'Inicia sesión en Backup para conectar MyLifeOS sin límites de sandbox.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _syncingCloud
                                    ? null
                                    : (_cloudUsername != null
                                        ? _syncCloudEcosystem
                                        : () => context.push('/backup')),
                                icon: _syncingCloud
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        _cloudUsername != null
                                            ? Icons.sync
                                            : Icons.login,
                                      ),
                                label: Text(
                                  _cloudUsername != null
                                      ? 'Sincronizar ahora'
                                      : 'Configurar Cuenta Nube',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C896),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Instrucciones
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Cómo funciona?',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _Step(
                          number: 1,
                          title: 'Conecta la misma Cuenta WalletAI',
                          description:
                              'Inicia sesión con tu usuario en Backup (WalletAI) y en Finanzas > 🔗 (MyLifeOS).',
                        ),
                        const SizedBox(height: 8),
                        _Step(
                          number: 2,
                          title: 'Resumen enriquecido automático',
                          description:
                              'WalletAI publica categorías, gastos semanales y movimientos recientes en Render.',
                        ),
                        const SizedBox(height: 8),
                        _Step(
                          number: 3,
                          title: 'Importación bidireccional',
                          description:
                              'Las compras registradas en Cocina (MyLifeOS) se importan aquí automáticamente.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String title;
  final String description;
  const _Step({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF00C896).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF00C896),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
