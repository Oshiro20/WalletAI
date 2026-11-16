import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/service_providers.dart';
import '../../providers/database_providers.dart';

class VoiceInputButton extends ConsumerWidget {
  /// Si se provee (por ej. dentro de CreateTransactionScreen), aplica los datos
  /// extraídos directamente al formulario en vez de abrir otra ruta.
  final ValueChanged<Map<String, dynamic>>? onVoiceExtracted;

  const VoiceInputButton({super.key, this.onVoiceExtracted});

  static String? _matchCategoryId(
    String? suggestedName,
    List<Category> categories,
  ) {
    if (suggestedName == null || suggestedName.trim().isEmpty) return null;
    final clean = suggestedName.trim().toLowerCase();
    final exact = categories
        .where((c) => c.name.trim().toLowerCase() == clean)
        .firstOrNull;
    if (exact != null) return exact.id;
    final partial = categories
        .where(
          (c) =>
              c.name.toLowerCase().contains(clean) ||
              clean.contains(c.name.toLowerCase()),
        )
        .firstOrNull;
    return partial?.id;
  }

  static String? _matchAccountId(
    String? suggestedName,
    List<Account> accounts,
  ) {
    if (suggestedName == null || suggestedName.trim().isEmpty) return null;
    final clean = suggestedName.trim().toLowerCase();
    final activeAccounts = accounts.where((a) => a.isActive).toList();
    final exact = activeAccounts
        .where((a) => a.name.trim().toLowerCase() == clean)
        .firstOrNull;
    if (exact != null) return exact.id;
    final partial = activeAccounts
        .where(
          (a) =>
              a.name.toLowerCase().contains(clean) ||
              clean.contains(a.name.toLowerCase()),
        )
        .firstOrNull;
    return partial?.id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.mic),
      tooltip: 'Entrada por voz',
      onPressed: () async {
        final result = await showDialog<String>(
          context: context,
          builder: (context) => const VoiceListeningDialog(),
        );

        if (result == null || result.trim().isEmpty || !context.mounted) {
          return;
        }

        // Mostrar indicador de carga mientras la IA interpreta el audio
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final groq = ref.read(groqServiceProvider);
          final categories = await ref.read(allCategoriesFutureProvider.future);
          final accounts = await ref.read(accountsDaoProvider).getAllAccounts();

          final aiData = await groq.parseVoiceTransaction(
            result,
            categories,
            accounts: accounts,
          );

          Map<String, dynamic> payload;

          if (aiData != null) {
            String? catId = _matchCategoryId(
              aiData['categoria_sugerida']?.toString(),
              categories,
            );

            // Override de aprendizaje persistente por producto
            final parsedProductName = aiData['producto']?.toString();
            if (parsedProductName != null && parsedProductName.isNotEmpty) {
              final db = ref.read(databaseProvider);
              final rule = await db.learningRulesDao.getRuleForProduct(
                parsedProductName,
              );
              if (rule != null) {
                catId = rule.categoryId;
              }
            }

            final accountId = _matchAccountId(
              aiData['cuenta_sugerida']?.toString(),
              accounts,
            );
            final destinationAccountId = _matchAccountId(
              aiData['cuenta_destino_sugerida']?.toString(),
              accounts,
            );
            final parsedDate = aiData['fecha'] != null
                ? DateTime.tryParse(aiData['fecha'].toString())
                : null;
            final rawCurrency =
                aiData['moneda']?.toString().toUpperCase() ?? 'PEN';
            final currency = ['PEN', 'USD', 'EUR'].contains(rawCurrency)
                ? rawCurrency
                : 'PEN';
            final cuotas = (aiData['cuotas'] as num?)?.toInt() ?? 1;

            payload = {
              'type': aiData['tipo']?.toString() ?? 'expense',
              'amount': (aiData['monto'] as num?)?.toDouble() ?? 0.0,
              'currency': currency,
              'description': aiData['descripcion']?.toString(),
              'productName': parsedProductName,
              'quantity': (aiData['cantidad'] as num?)?.toDouble() ?? 1.0,
              'unit': aiData['unidad']?.toString() ?? 'UND',
              'categoryId': catId,
              'accountId': accountId,
              'destinationAccountId': destinationAccountId,
              if (parsedDate != null) 'date': parsedDate.millisecondsSinceEpoch,
              if (cuotas > 1) 'installments': cuotas,
            };
          } else {
            // Respaldo offline automático con TransactionParserService
            final parser = ref.read(transactionParserServiceProvider);
            final subcats = await ref
                .read(subcategoriesDaoProvider)
                .getAllSubcategories();
            final fallback = parser.parse(
              result,
              categories,
              accounts,
              subcategories: subcats,
            );

            payload = {
              'type': fallback.type ?? 'expense',
              'amount': fallback.amount ?? 0.0,
              'description':
                  (fallback.description != null &&
                      fallback.description!.isNotEmpty)
                  ? fallback.description
                  : result.trim(),
              'categoryId': fallback.categoryId,
              'subcategoryId': fallback.subcategoryId,
              'accountId': fallback.accountId,
              'quantity': 1.0,
              'unit': 'UND',
            };
          }

          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // cerrar loading
          }

          if (!context.mounted) return;

          if (onVoiceExtracted != null) {
            onVoiceExtracted!(payload);
          } else {
            context.push('/transactions/create', extra: payload);
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al procesar audio: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
    );
  }
}

class VoiceListeningDialog extends ConsumerStatefulWidget {
  const VoiceListeningDialog({super.key});

  @override
  ConsumerState<VoiceListeningDialog> createState() =>
      _VoiceListeningDialogState();
}

class _VoiceListeningDialogState extends ConsumerState<VoiceListeningDialog> {
  String _text = '';
  String _status = 'Iniciando micrófono...';
  bool _hasCompleted = false;
  bool _hasError = false;
  Timer? _autoSubmitTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _startListening);
  }

  @override
  void dispose() {
    _autoSubmitTimer?.cancel();
    if (!_hasCompleted) {
      ref.read(voiceServiceProvider).cancel();
    }
    super.dispose();
  }

  void _scheduleAutoSubmit(Duration delay) {
    if (_hasCompleted || _text.trim().isEmpty) return;
    _autoSubmitTimer?.cancel();
    _autoSubmitTimer = Timer(delay, _completeWithTranscript);
  }

  Future<void> _completeWithTranscript() async {
    if (_hasCompleted || !mounted) return;
    final clean = _text.trim();
    if (clean.isEmpty) return;
    _hasCompleted = true;
    _autoSubmitTimer?.cancel();
    await ref.read(voiceServiceProvider).stop();
    if (mounted) {
      Navigator.of(context).pop(clean);
    }
  }

  Future<void> _startListening() async {
    _autoSubmitTimer?.cancel();
    if (mounted) {
      setState(() {
        _hasError = false;
        _status = 'Escuchando...';
      });
    }

    final voiceService = ref.read(voiceServiceProvider);

    await voiceService.listen(
      onResult: (text, isFinal) {
        if (!mounted || _hasCompleted) return;
        setState(() => _text = text);
        if (text.trim().isNotEmpty) {
          if (isFinal) {
            _scheduleAutoSubmit(const Duration(milliseconds: 300));
          } else {
            // Respaldo si el motor de voz no emite finalResult rápido tras pausar
            _scheduleAutoSubmit(const Duration(milliseconds: 2200));
          }
        }
      },
      onStatus: (status) {
        if (!mounted || _hasCompleted) return;
        if (status == 'unavailable') {
          setState(() {
            _hasError = true;
            _status = 'Micrófono no disponible o permiso denegado';
          });
          return;
        }

        final isFinished = status == 'done' || status == 'notListening';
        if (isFinished && _text.trim().isNotEmpty) {
          setState(() => _status = 'Procesando audio...');
          _scheduleAutoSubmit(const Duration(milliseconds: 200));
        } else if (status == 'done' && _text.trim().isEmpty) {
          setState(() {
            _hasError = true;
            _status = 'No se detectó voz. Toca Reintentar para hablar.';
          });
        } else {
          setState(() {
            _status = status == 'listening' ? 'Escuchando...' : status;
          });
        }
      },
      onError: (errorMsg) {
        if (!mounted || _hasCompleted) return;
        if (_text.trim().isNotEmpty) {
          _scheduleAutoSubmit(const Duration(milliseconds: 200));
        } else {
          setState(() {
            _hasError = true;
            _status = 'No se pudo capturar el audio ($errorMsg)';
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_hasError ? 'Entrada por voz' : 'Escuchando...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _hasError
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _hasError ? Icons.mic_off : Icons.mic,
              size: 32,
              color: _hasError
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _text.isEmpty
                ? 'Ej: "Gasté 20 soles en 2 kilos de pollo con BCP"'
                : _text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _text.isNotEmpty && !_hasError
                ? 'Se procesará automáticamente al terminar...'
                : _status,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            _hasCompleted = true;
            _autoSubmitTimer?.cancel();
            ref.read(voiceServiceProvider).cancel();
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        if (_hasError)
          FilledButton.icon(
            onPressed: _startListening,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reintentar'),
          )
        else
          FilledButton(
            onPressed: _text.trim().isNotEmpty ? _completeWithTranscript : null,
            child: const Text('Listo'),
          ),
      ],
    );
  }
}
