import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.15.0';
  static const _build = '3';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ─── Hero AppBar ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(background: _HeroBanner(cs: cs)),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Versión ────────────────────────────────────────────────
                _InfoCard(
                  children: [
                    _InfoRow(
                      icon: Icons.info_outline,
                      label: 'Versión',
                      value: '1.15.0',
                    ),
                    _InfoRow(
                      icon: Icons.phone_android,
                      label: 'Plataforma',
                      value: 'Android',
                    ),
                    _InfoRow(
                      icon: Icons.code,
                      label: 'Framework',
                      value: 'Flutter 3.x · Dart 3',
                    ),
                    _InfoRow(
                      icon: Icons.storage,
                      label: 'Base de datos',
                      value: 'Drift (SQLite) · Offline-first',
                    ),
                    _InfoRow(
                      icon: Icons.lock_outline,
                      label: 'Estado',
                      value: 'Riverpod 2.x',
                    ),
                  ],
                ),

                // ─── Funcionalidades ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Funcionalidades',
                    style: txt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _FeatureGrid(cs: cs),

                // ─── IA & Tecnología ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Tecnologías IA',
                    style: txt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _InfoCard(
                  children: [
                    _AiTechRow(
                      emoji: '🎙️',
                      label: 'Entrada por Voz',
                      detail: 'speech_to_text — NLP local',
                    ),
                    _AiTechRow(
                      emoji: '📷',
                      label: 'Escaneo de Boletas',
                      detail: 'Google ML Kit Text Recognition',
                    ),
                    _AiTechRow(
                      emoji: '✨',
                      label: 'Detección de Recurrentes',
                      detail: 'Heurística de intervalos propia',
                    ),
                    _AiTechRow(
                      emoji: '🔒',
                      label: 'Backup Cifrado',
                      detail: 'AES-256-CBC · SHA-256 KDF',
                    ),
                  ],
                ),

                // ─── Créditos ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: Text(
                    'Créditos',
                    style: txt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _InfoCard(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        child: const Text(
                          'JO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: const Text(
                        'Oshiro Joel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Desarrollador principal'),
                    ),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: cs.secondaryContainer,
                        child: Icon(Icons.smart_toy, color: cs.secondary),
                      ),
                      title: const Text(
                        'Antigravity AI',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Asistente de desarrollo (Google DeepMind)',
                      ),
                    ),
                  ],
                ),

                // ─── Paquetes de código abierto ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Código Abierto',
                    style: txt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _InfoCard(
                  children: [
                    InkWell(
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'WalletAI',
                        applicationVersion: '$_version+$_build',
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      child: const ListTile(
                        leading: Icon(Icons.description_outlined),
                        title: Text('Licencias de paquetes'),
                        subtitle: Text('Flutter, Riverpod, Drift y más'),
                        trailing: Icon(Icons.chevron_right),
                      ),
                    ),
                  ],
                ),

                // ─── Privacidad ──────────────────────────────────────────────
                _InfoCard(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: const Text('Privacidad'),
                      subtitle: const Text(
                        'Todos tus datos se almacenan localmente en tu dispositivo.\nWalletAI no envía información a ningún servidor externo.',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── Footer ──────────────────────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Hecho con ❤️ en Perú',
                        style: txt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '© 2026 WalletAI · v$_version',
                        style: txt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final ColorScheme cs;
  const _HeroBanner({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary, cs.tertiary],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Logo
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'WalletAI',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tu asistente financiero inteligente',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feature Grid ─────────────────────────────────────────────────────────────

class _FeatureGrid extends StatelessWidget {
  final ColorScheme cs;
  const _FeatureGrid({required this.cs});

  static const _features = [
    ('💰', 'Cuentas'),
    ('📊', 'Analíticas'),
    ('🎯', 'Presupuestos'),
    ('🚩', 'Metas'),
    ('🔁', 'Recurrentes IA'),
    ('📷', 'OCR Boletas'),
    ('🎙️', 'Voz'),
    ('🔒', 'Backup Cifrado'),
    ('📤', 'Excel / CSV'),
    ('🏠', 'Widgets'),
    ('🌙', 'Modo Oscuro'),
    ('☁️', 'Google Drive'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _features.map((f) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(f.$1, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 5),
                Text(
                  f.$2,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: cs.primary),
      title: Text(
        label,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AiTechRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String detail;
  const _AiTechRow({
    required this.emoji,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Text(emoji, style: const TextStyle(fontSize: 22)),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      ),
      subtitle: Text(detail, style: const TextStyle(fontSize: 11)),
    );
  }
}
