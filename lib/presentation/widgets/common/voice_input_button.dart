import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/database/drift_database.dart';
import '../../../data/datasources/groq_service.dart';
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

        var dialogOpen = false;
        void closeDialogIfOpen() {
          if (dialogOpen && context.mounted) {
            dialogOpen = false;
            Navigator.of(context, rootNavigator: true).pop();
          }
        }

        try {
          final categories = await ref.read(allCategoriesFutureProvider.future);
          final accounts = await ref.read(accountsDaoProvider).getAllAccounts();
          final subcats = await ref
              .read(subcategoriesDaoProvider)
              .getAllSubcategories();
          final db = ref.read(databaseProvider);

          // 1. Parseo local instantáneo (<10ms): resuelve dictados claros sin esperar red.
          final parser = ref.read(transactionParserServiceProvider);
          final local = parser.parse(
            result,
            categories,
            accounts,
            subcategories: subcats,
          );

          String? localCatId = local.categoryId;
          String? localSubcatId = local.subcategoryId;
          final localProduct = local.productName;
          if (localProduct != null && localProduct.isNotEmpty) {
            final rule = await db.learningRulesDao.getRuleForProduct(
              localProduct,
            );
            if (rule != null) {
              localCatId = rule.categoryId;
            }
          }

          Map<String, dynamic>? payload;

          final resolvedLocally = local.amount != null &&
              local.amount! > 0 &&
              !local.isComplexPhrase &&
              local.description != null &&
              local.description!.trim().isNotEmpty &&
              (localCatId != null || local.accountId != null);

          if (resolvedLocally) {
            payload = {
              'type': local.type ?? 'expense',
              'amount': local.amount!,
              'currency': local.currency,
              'description': local.description,
              'productName': local.productName,
              'quantity': local.quantity,
              'unit': local.unit,
              'categoryId': localCatId,
              'subcategoryId': localSubcatId,
              'accountId': local.accountId,
            };
          } else {
            // 2. Solo consultar IA si la frase es ambigua o compleja (cuotas, transfer, fechas).
            if (context.mounted) {
              dialogOpen = true;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );
            }

            final groq = ref.read(groqServiceProvider);
            final aiData = await groq.parseVoiceTransaction(
              result,
              categories,
              accounts: accounts,
              timeout: const Duration(seconds: 6),
            );

            if (aiData != null) {
              String? catId = _matchCategoryId(
                aiData['categoria_sugerida']?.toString(),
                categories,
              );

              final parsedProductName = aiData['producto']?.toString();
              if (parsedProductName != null && parsedProductName.isNotEmpty) {
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
                'amount': (aiData['monto'] as num?)?.toDouble() ??
                    (local.amount ?? 0.0),
                'currency': currency,
                'description': aiData['descripcion']?.toString() ??
                    local.description,
                'productName': parsedProductName ?? local.productName,
                'quantity':
                    (aiData['cantidad'] as num?)?.toDouble() ?? local.quantity,
                'unit': aiData['unidad']?.toString() ?? local.unit,
                'categoryId': catId ?? localCatId,
                'accountId': accountId ?? local.accountId,
                'destinationAccountId': destinationAccountId,
                if (parsedDate != null)
                  'date': parsedDate.millisecondsSinceEpoch,
                if (cuotas > 1) 'installments': cuotas,
              };
            } else {
              payload = {
                'type': local.type ?? 'expense',
                'amount': local.amount ?? 0.0,
                'currency': local.currency,
                'description': (local.description != null &&
                        local.description!.isNotEmpty)
                    ? local.description
                    : result.trim(),
                'productName': local.productName,
                'quantity': local.quantity,
                'unit': local.unit,
                'categoryId': localCatId,
                'subcategoryId': localSubcatId,
                'accountId': local.accountId,
              };
            }
          }

          closeDialogIfOpen();

          if (!context.mounted) return;

          if (onVoiceExtracted != null) {
            onVoiceExtracted!(payload);
          } else {
            context.push('/transactions/create', extra: payload);
          }
        } catch (e) {
          closeDialogIfOpen();
          if (context.mounted) {
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
    unawaited(GroqService.warmUpServer());
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
            _scheduleAutoSubmit(const Duration(milliseconds: 200));
          } else {
            // Respaldo más ágil si el motor de voz tarda en emitir finalResult
            _scheduleAutoSubmit(const Duration(milliseconds: 1150));
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
