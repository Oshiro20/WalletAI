import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/datasources/smart_recurring_service.dart';

/// Pantalla que muestra sugerencias de pagos recurrentes detectados
/// automáticamente por [SmartRecurringService].
class RecurringSuggestionsScreen extends ConsumerStatefulWidget {
  const RecurringSuggestionsScreen({super.key});

  @override
  ConsumerState<RecurringSuggestionsScreen> createState() =>
      _RecurringSuggestionsScreenState();
}

class _RecurringSuggestionsScreenState
    extends ConsumerState<RecurringSuggestionsScreen> {
  final Set<int> _dismissed = {};
  final Set<int> _accepted = {};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recurringFromHistory);
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sugerencias Inteligentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar análisis',
            onPressed: () => ref.invalidate(recurringFromHistory),
          ),
        ],
      ),
      body: async.when(
        loading: () => const _LoadingView(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (suggestions) {
          final visible = suggestions
              .asMap()
              .entries
              .where((e) => !_dismissed.contains(e.key) && !_accepted.contains(e.key))
              .toList();

          if (visible.isEmpty) {
            return _EmptyView(hasResults: suggestions.isNotEmpty);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Banner de información ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: cs.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'WalletAI detectó ${suggestions.length} posibles pagos'
                        ' recurrentes en tu historial.',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── Tarjetas de sugerencias ──────────────────────────────
              ...visible.map((entry) {
                final i = entry.key;
                final s = entry.value;
                return _SuggestionCard(
                  suggestion: s,
                  fmt: fmt,
                  onAccept: () => _accept(i, s),
                  onDismiss: () => setState(() => _dismissed.add(i)),
                );
              }),

              // ─── Botón aceptar todo ───────────────────────────────────
              if (visible.length > 1) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.done_all),
                  label: Text('Aceptar todas (${visible.length})'),
                  onPressed: () => _acceptAll(
                    visible.map((e) => MapEntry(e.key, e.value)).toList(),
                  ),
                ),
              ],

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Future<void> _accept(int i, RecurringSuggestion s) async {
    final service = ref.read(smartRecurringServiceProvider);
    await service.acceptSuggestion(s);
    setState(() => _accepted.add(i));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${s.name}" agregado como pago recurrente ✓'),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _acceptAll(List<MapEntry<int, RecurringSuggestion>> entries) async {
    final service = ref.read(smartRecurringServiceProvider);
    for (final entry in entries) {
      await service.acceptSuggestion(entry.value);
      setState(() => _accepted.add(entry.key));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${entries.length} pagos recurrentes agregados ✓'),
          backgroundColor: Colors.green.shade600,
        ),
      );
    }
  }
}

// ─── Tarjeta de sugerencia ─────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final RecurringSuggestion suggestion;
  final NumberFormat fmt;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  const _SuggestionCard({
    required this.suggestion,
    required this.fmt,
    required this.onAccept,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final confidenceColor = _confidenceColor(suggestion.confidence);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ───────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.loop, color: cs.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.name,
                        style: text.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: confidenceColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${suggestion.confidenceLabel} confianza',
                              style: TextStyle(
                                fontSize: 10,
                                color: confidenceColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: cs.outlineVariant),
                  onPressed: onDismiss,
                  tooltip: 'Ignorar',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ─── Detalles ───────────────────────────────────────────────
            _InfoRow(
              icon: Icons.attach_money,
              label: 'Monto promedio',
              value: fmt.format(suggestion.amount),
            ),
            _InfoRow(
              icon: Icons.repeat,
              label: 'Frecuencia',
              value: suggestion.frequencyLabel,
            ),
            _InfoRow(
              icon: Icons.event_repeat,
              label: 'Visto',
              value: '${suggestion.occurrences} veces – último: '
                  '${DateFormat('dd/MM/yyyy').format(suggestion.lastSeen)}',
            ),

            const SizedBox(height: 14),

            // ─── Botón aceptar ─────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text('Agregar como recurrente'),
                onPressed: onAccept,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _confidenceColor(double c) {
    if (c >= 0.75) return Colors.green.shade700;
    if (c >= 0.5)  return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vistas auxiliares ─────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Analizando tu historial de transacciones…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasResults;
  const _EmptyView({required this.hasResults});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasResults ? Icons.check_circle_outline : Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              hasResults
                  ? '¡Has procesado todas las sugerencias!'
                  : 'No se detectaron patrones recurrentes aún.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              hasResults
                  ? 'WalletAI seguirá monitoreando tu historial.'
                  : 'Registra más transacciones para que WalletAI'
                      ' pueda detectar patrones.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
