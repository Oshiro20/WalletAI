import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/dashboard_provider.dart';

/// Pantalla para personalizar el orden y visibilidad de los widgets del dashboard.
class DashboardCustomizeScreen extends ConsumerWidget {
  const DashboardCustomizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(dashboardLayoutProvider);
    final notifier = ref.read(dashboardLayoutProvider.notifier);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar Dashboard'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Restablecer'),
            onPressed: () => _confirmReset(context, notifier),
          ),
        ],
      ),
      body: Column(
        children: [
          // ─── Banner informativo ────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: cs.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.drag_indicator, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Arrastra ≡ para reordenar • Toca el ojo para mostrar/ocultar',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Lista reordenable ─────────────────────────────────────────
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: layout.length,
              onReorder: (oldIndex, newIndex) {
                notifier.reorder(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final widget = layout[index];
                return _WidgetConfigTile(
                  key: ValueKey(widget.type),
                  config: widget,
                  onToggle: () => notifier.toggleVisibility(widget.type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, DashboardLayoutNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restablecer dashboard'),
        content: const Text(
            '¿Volver al orden y visibilidad predeterminados?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              notifier.resetToDefault();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dashboard restablecido')),
              );
            },
            child: const Text('Restablecer'),
          ),
        ],
      ),
    );
  }
}

// ─── Tile de configuración ─────────────────────────────────────────────────

class _WidgetConfigTile extends StatelessWidget {
  final DashboardWidgetConfig config;
  final VoidCallback onToggle;

  const _WidgetConfigTile({
    super.key,
    required this.config,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isVisible = config.visible;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isVisible
                ? cs.primaryContainer
                : cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            config.icon,
            color: isVisible ? cs.primary : cs.onSurfaceVariant,
            size: 22,
          ),
        ),
        title: Text(
          config.label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isVisible ? null : cs.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          isVisible ? 'Visible' : 'Oculto',
          style: TextStyle(
            fontSize: 12,
            color: isVisible ? cs.primary : cs.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Toggle visibilidad
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: IconButton(
                key: ValueKey(isVisible),
                icon: Icon(
                  isVisible ? Icons.visibility : Icons.visibility_off,
                  color: isVisible ? cs.primary : cs.onSurfaceVariant,
                ),
                onPressed: onToggle,
                tooltip: isVisible ? 'Ocultar' : 'Mostrar',
              ),
            ),
            // Handle de reordenamiento
            ReorderableDragStartListener(
              index: context
                  .findAncestorWidgetOfExactType<ReorderableListView>()
                  ?.key
                  .hashCode ?? 0,
              child: const Icon(Icons.drag_handle, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
