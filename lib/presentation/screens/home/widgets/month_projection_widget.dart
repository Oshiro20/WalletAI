import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/projection_provider.dart';

class MonthProjectionWidget extends ConsumerWidget {
  const MonthProjectionWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectionAsync = ref.watch(monthProjectionProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return projectionAsync.when(
      loading: () => const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (proj) {
        // Colores según estado de salud financiera
        final Color statusColor = proj.healthStatus == 0
            ? const Color(0xFF10B981) // verde
            : proj.healthStatus == 1
            ? const Color(0xFFF59E0B) // amarillo
            : const Color(0xFFEF4444); // rojo

        final String statusEmoji = proj.healthStatus == 0
            ? '✅'
            : proj.healthStatus == 1
            ? '⚠️'
            : '🔴';

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Título ─────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Proyección del Mes',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(statusEmoji),
                  ],
                ),
                const SizedBox(height: 12),

                // ── Barra de progreso días ──────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Día ${proj.daysElapsed} de ${proj.daysInMonth}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(proj.progressPercent * 100).toInt()}% del mes',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: proj.progressPercent.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Datos ───────────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _InfoTile(
                        label: 'Gastado',
                        value: 'S/ ${proj.spentSoFar.toStringAsFixed(2)}',
                        icon: Icons.receipt_long,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _InfoTile(
                        label: 'Proyección',
                        value: 'S/ ${proj.projectedTotal.toStringAsFixed(2)}',
                        icon: Icons.analytics,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ── Saldo proyectado ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        proj.projectedBalance >= 0
                            ? Icons.savings
                            : Icons.warning_amber,
                        size: 18,
                        color: statusColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          proj.projectedBalance >= 0
                              ? 'Te quedarán ~S/ ${proj.projectedBalance.toStringAsFixed(2)} al fin de mes'
                              : 'Excederás tu ingreso por ~S/ ${proj.projectedBalance.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (proj.dailyAverage > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Promedio diario: S/ ${proj.dailyAverage.toStringAsFixed(2)}/día',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
