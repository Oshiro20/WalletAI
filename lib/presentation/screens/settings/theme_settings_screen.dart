import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeState = ref.watch(themeProvider);
    final notifier = ref.read(themeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Apariencia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ─── Modo ───────────────────────────────────────────────────────
          Text(
            'Modo',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _ThemeModeSelector(
            current: themeState.mode,
            onChanged: (mode) => notifier.setThemeMode(mode),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          // ─── Color ──────────────────────────────────────────────────────
          Text(
            'Color de acento',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'El color primario afecta botones, activos y la barra de navegación',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _ColorThemeGrid(
            currentId: themeState.colorThemeId,
            onSelect: (color) => notifier.setSeedColor(color),
          ),

          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 20),

          // ─── Vista previa ────────────────────────────────────────────────
          Text(
            'Vista previa',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _PreviewCard(),
        ],
      ),
    );
  }
}

// ─── Selector de modo ─────────────────────────────────────────────────────

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeModeSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final modes = [
      (ThemeMode.system, Icons.brightness_auto, 'Sistema'),
      (ThemeMode.light, Icons.light_mode, 'Claro'),
      (ThemeMode.dark, Icons.dark_mode, 'Oscuro'),
    ];

    return Row(
      children: modes.map((e) {
        final (mode, icon, label) = e;
        final isSelected = current == mode;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primaryContainer
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? cs.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 26,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Grid de colores ──────────────────────────────────────────────────────

class _ColorThemeGrid extends StatelessWidget {
  final String currentId;
  final ValueChanged<Color> onSelect;

  const _ColorThemeGrid({required this.currentId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: kAvailableThemes.length,
      itemBuilder: (context, i) {
        final t = kAvailableThemes[i];
        final isSelected = t.id == currentId;
        return GestureDetector(
          onTap: () => onSelect(t.seed),
          child: AnimatedScale(
            scale: isSelected ? 1.0 : 0.92,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: t.seed,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? t.seed : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: t.seed.withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white, size: 26)
                      : null,
                ),
                const SizedBox(height: 6),
                Text(
                  t.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Vista previa ─────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance Total',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                Icon(Icons.account_balance_wallet, color: cs.primary, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'S/ 4,250.00',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Ingresos',
                    value: 'S/ 6,000',
                    color: const Color(0xFF10B981),
                    icon: Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: 'Gastos',
                    value: 'S/ 1,750',
                    color: const Color(0xFFEF4444),
                    icon: Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Nueva transacción'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 42),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, color: color)),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
