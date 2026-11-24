import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/subcategory_learning_service.dart';
import '../../../data/database/drift_database.dart';
import '../../../data/datasources/groq_service.dart';
import '../../../data/datasources/receipt_scanner_service.dart';
import '../../providers/service_providers.dart';
import '../../providers/database_providers.dart';
import '../../screens/transactions/widgets/add_receipt_items_screen.dart';

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

  static String? _matchSubcategoryId(
    String? suggestedName,
    String? categoryId,
    List<Subcategory> subcategories,
  ) {
    if (suggestedName == null || suggestedName.trim().isEmpty) return null;
    final clean = suggestedName.trim().toLowerCase();
    final scoped = categoryId == null
        ? subcategories
        : subcategories.where((s) => s.categoryId == categoryId).toList();
    final exact = scoped
        .where((s) => s.name.trim().toLowerCase() == clean)
        .firstOrNull;
    if (exact != null) return exact.id;
    final partial = scoped
        .where(
          (s) =>
              s.name.toLowerCase().contains(clean) ||
              clean.contains(s.name.toLowerCase()),
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
          barrierDismissible: false,
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

          // 1. Parseo local instantáneo (<10ms)
          final parser = ref.read(transactionParserServiceProvider);
          final local = parser.parse(
            result,
            categories,
            accounts,
            subcategories: subcats,
          );

          String? localCatId = local.categoryId;
          String? localSubcatId = local.subcategoryId;
          String? localAccountId = local.accountId;
          final localProduct = local.productName;
          if (localProduct != null && localProduct.isNotEmpty) {
            final rule = await db.learningRulesDao.getRuleForProduct(
              localProduct,
            );
            if (rule != null) {
              localCatId = rule.categoryId;
            }
            final subRule = await SubcategoryLearningService.getRule(
              localProduct,
            );
            if (subRule.subcategoryId != null) {
              localSubcatId = subRule.subcategoryId;
            }
            localAccountId ??= subRule.accountId;
          }

          // Detectar si el dictado menciona múltiples montos/productos para usar IA
          final amountMentions = RegExp(
            r'\b\d+(?:[.,]\d+)?\s*(?:soles|sol|s/|dolares|dólares|usd|lucas)\b',
            caseSensitive: false,
          ).allMatches(result).length;
          final looksMultiItem = amountMentions >= 2;

          Map<String, dynamic>? payload;
          List<ReceiptItem> multiItems = const [];

          final resolvedLocally =
              !looksMultiItem &&
              local.amount != null &&
              local.amount! > 0 &&
              !local.isComplexPhrase &&
              local.description != null &&
              local.description!.trim().isNotEmpty &&
              localCatId != null &&
              localSubcatId != null;

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
              'accountId': localAccountId,
            };
          } else {
            if (context.mounted) {
              dialogOpen = true;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );
            }

            final aiService = ref.read(groqServiceProvider);
            final aiData = await aiService.parseVoiceTransaction(
              result,
              categories,
              subcategories: subcats,
              accounts: accounts,
              timeout: const Duration(seconds: 10),
            );

            if (aiData != null) {
              final rawItems = aiData['items'];
              if (rawItems is List && rawItems.length >= 2) {
                multiItems = rawItems.whereType<Map>().map((m) {
                  final map = Map<String, dynamic>.from(m);
                  return ReceiptItem(
                    name: map['nombre']?.toString() ?? 'Producto',
                    price: (map['monto'] as num?)?.toDouble() ?? 0.0,
                    quantity: (map['cantidad'] as num?)?.toDouble() ?? 1.0,
                    unit: map['unidad']?.toString() ?? 'UND',
                    category: map['categoria']?.toString(),
                    subcategory: map['subcategoria']?.toString(),
                  );
                }).where((i) => i.price > 0).toList();
              }

              final suggestedCatName = aiData['categoria_sugerida']?.toString();
              final suggestedSubName =
                  aiData['subcategoria_sugerida']?.toString();
              String? catId = _matchCategoryId(suggestedCatName, categories);
              String? subcatId = _matchSubcategoryId(
                suggestedSubName,
                catId,
                subcats,
              );

              final parsedProductName = aiData['producto']?.toString();
              if (parsedProductName != null && parsedProductName.isNotEmpty) {
                final rule = await db.learningRulesDao.getRuleForProduct(
                  parsedProductName,
                );
                if (rule != null) {
                  catId = rule.categoryId;
                }
                final subRule = await SubcategoryLearningService.getRule(
                  parsedProductName,
                );
                if (subRule.subcategoryId != null) {
                  subcatId = subRule.subcategoryId;
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

              final bool isNewCat =
                  aiData['es_nueva_categoria'] == true ||
                  (catId == null &&
                      suggestedCatName != null &&
                      suggestedCatName.trim().isNotEmpty &&
                      suggestedCatName.trim().toUpperCase() != 'OTRO');
              final bool isNewSub =
                  aiData['es_nueva_subcategoria'] == true ||
                  (subcatId == null &&
                      suggestedSubName != null &&
                      suggestedSubName.trim().isNotEmpty);

              payload = {
                'type': aiData['tipo']?.toString() ?? 'expense',
                'amount':
                    (aiData['monto'] as num?)?.toDouble() ??
                    (local.amount ?? 0.0),
                'currency': currency,
                'description':
                    aiData['descripcion']?.toString() ?? local.description,
                'productName': parsedProductName ?? local.productName,
                'quantity':
                    (aiData['cantidad'] as num?)?.toDouble() ?? local.quantity,
                'unit': aiData['unidad']?.toString() ?? local.unit,
                'categoryId': catId ?? localCatId,
                'subcategoryId': subcatId ?? localSubcatId,
                'accountId': accountId ?? localAccountId,
                'destinationAccountId': destinationAccountId,
                if (parsedDate != null)
                  'date': parsedDate.millisecondsSinceEpoch,
                if (cuotas > 1) 'installments': cuotas,
                if (isNewCat || isNewSub)
                  'aiSuggestion': AiCategoryPrediction(
                    categoryName: suggestedCatName,
                    subcategoryName: suggestedSubName,
                    isNewCategory: isNewCat,
                    isNewSubcategory: isNewSub,
                  ),
              };
            } else {
              payload = {
                'type': local.type ?? 'expense',
                'amount': local.amount ?? 0.0,
                'currency': local.currency,
                'description':
                    (local.description != null && local.description!.isNotEmpty)
                    ? local.description
                    : result.trim(),
                'productName': local.productName,
                'quantity': local.quantity,
                'unit': local.unit,
                'categoryId': localCatId,
                'subcategoryId': localSubcatId,
                'accountId': localAccountId,
              };
            }
          }

          closeDialogIfOpen();

          if (!context.mounted) return;

          // Si se dictaron múltiples productos con precios separados, abrir pantalla multi-ítem
          if (multiItems.length >= 2 && onVoiceExtracted == null) {
            final total = multiItems.fold<double>(0, (s, i) => s + i.price);
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddReceiptItemsScreen(
                  receipt: ScannedReceipt(
                    amount: total,
                    date: DateTime.now(),
                    merchant: payload?['description']?.toString() ?? 'Dictado por voz',
                    items: multiItems,
                    currency: payload?['currency']?.toString() ?? 'PEN',
                    rawText: result.trim(),
                  ),
                ),
              ),
            );
            return;
          }

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

/// Diálogo de dictado continuo con control manual:
/// nunca se corta ni se envía solo por pausas; el usuario revisa/edita
/// y pulsa **Listo** cuando termina de hablar.
class VoiceListeningDialog extends ConsumerStatefulWidget {
  const VoiceListeningDialog({super.key});

  @override
  ConsumerState<VoiceListeningDialog> createState() =>
      _VoiceListeningDialogState();
}

class _VoiceListeningDialogState extends ConsumerState<VoiceListeningDialog> {
  final TextEditingController _transcriptCtrl = TextEditingController();
  String _committedText = '';
  String _liveChunk = '';
  String _status = 'Iniciando micrófono...';
  bool _isListening = false;
  bool _hasCompleted = false;
  bool _hasError = false;
  bool _triedOnDevice = false;

  @override
  void initState() {
    super.initState();
    unawaited(GroqService.warmUpServer());
    Future.delayed(Duration.zero, _startListening);
  }

  @override
  void dispose() {
    _transcriptCtrl.dispose();
    if (!_hasCompleted) {
      ref.read(voiceServiceProvider).cancel();
    }
    super.dispose();
  }

  void _syncControllerFromChunks() {
    final combined = [
      if (_committedText.trim().isNotEmpty) _committedText.trim(),
      if (_liveChunk.trim().isNotEmpty) _liveChunk.trim(),
    ].join(' ');
    _transcriptCtrl.value = TextEditingValue(
      text: combined,
      selection: TextSelection.collapsed(offset: combined.length),
    );
  }

  void _commitCurrentChunk() {
    if (_liveChunk.trim().isNotEmpty) {
      _committedText = [
        if (_committedText.trim().isNotEmpty) _committedText.trim(),
        _liveChunk.trim(),
      ].join(' ');
      _liveChunk = '';
      _syncControllerFromChunks();
    } else {
      _committedText = _transcriptCtrl.text.trim();
    }
  }

  Future<void> _pauseListening() async {
    await ref.read(voiceServiceProvider).stop();
    if (!mounted) return;
    setState(() {
      _commitCurrentChunk();
      _isListening = false;
      _status = 'En pausa · puedes editar, seguir hablando o tocar Listo';
    });
  }

  Future<void> _completeAndSubmit() async {
    final clean = _transcriptCtrl.text.trim();
    if (clean.isEmpty || _hasCompleted || !mounted) return;
    _hasCompleted = true;
    await ref.read(voiceServiceProvider).stop();
    if (mounted) {
      Navigator.of(context).pop(clean);
    }
  }

  Future<void> _startListening({bool onDevice = false}) async {
    _committedText = _transcriptCtrl.text.trim();
    _liveChunk = '';
    if (mounted) {
      setState(() {
        _hasError = false;
        _isListening = true;
        _status = onDevice
            ? 'Escuchando en modo local... habla tranquilo y toca Listo al terminar'
            : 'Escuchando... habla tranquilo y toca Listo al terminar';
      });
    }

    final voiceService = ref.read(voiceServiceProvider);

    await voiceService.listen(
      onDevice: onDevice,
      onResult: (text, isFinal) {
        if (!mounted || _hasCompleted) return;
        setState(() {
          _liveChunk = text;
          _syncControllerFromChunks();
          if (isFinal) {
            _commitCurrentChunk();
          }
        });
      },
      onStatus: (status) {
        if (!mounted || _hasCompleted) return;
        if (status == 'unavailable') {
          setState(() {
            _isListening = false;
            _hasError = true;
            _status = 'Micrófono no disponible o permiso denegado';
          });
          return;
        }

        final isFinished = status == 'done' || status == 'notListening';
        if (isFinished) {
          setState(() {
            _commitCurrentChunk();
            _isListening = false;
            _status = _transcriptCtrl.text.trim().isNotEmpty
                ? 'Pausado · toca "Seguir hablando" para agregar más o "Listo" para registrar'
                : 'No se escuchó audio. Toca "Seguir hablando" o escribe abajo.';
          });
        } else if (status == 'listening') {
          setState(() {
            _isListening = true;
            _status = onDevice
                ? 'Escuchando (modo local)... toca Listo cuando termines'
                : 'Escuchando... toca Listo cuando termines';
          });
        }
      },
      onError: (errorMsg) {
        if (!mounted || _hasCompleted) return;
        final isNetworkError = errorMsg.toLowerCase().contains('network');
        if (isNetworkError && !_triedOnDevice) {
          _triedOnDevice = true;
          Future.microtask(() {
            if (mounted && !_hasCompleted) {
              _startListening(onDevice: true);
            }
          });
          return;
        }
        setState(() {
          _commitCurrentChunk();
          _isListening = false;
          _hasError = _transcriptCtrl.text.trim().isEmpty;
          _status = _transcriptCtrl.text.trim().isNotEmpty
              ? 'Micrófono en pausa · revisa tu texto y toca Listo o Seguir hablando'
              : 'No se pudo capturar el audio ($errorMsg). Reintenta o escribe abajo:';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasText = _transcriptCtrl.text.trim().isNotEmpty;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isListening ? Icons.graphic_eq_rounded : Icons.mic_rounded,
            color: _isListening ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(_isListening ? 'Escuchando...' : 'Dictado por voz'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _isListening
                  ? _pauseListening
                  : () {
                      _triedOnDevice = false;
                      _startListening();
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _isListening
                      ? cs.primaryContainer
                      : (_hasError
                            ? cs.errorContainer
                            : cs.surfaceContainerHighest),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isListening
                        ? cs.primary
                        : cs.outlineVariant.withValues(alpha: 0.4),
                    width: _isListening ? 2.5 : 1,
                  ),
                ),
                child: Icon(
                  _isListening
                      ? Icons.pause_rounded
                      : (_hasError ? Icons.mic_off : Icons.mic_rounded),
                  size: 32,
                  color: _isListening
                      ? cs.primary
                      : (_hasError ? cs.error : cs.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _transcriptCtrl,
              maxLines: 4,
              minLines: 2,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText:
                    'Ej: "Gasté 25 soles en 2 kilos de pollo con Yape"\nO varios: "Pollo 22 soles y papa 4 soles con BCP"',
                hintStyle: const TextStyle(fontSize: 12.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                suffixIcon: hasText
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Limpiar',
                        onPressed: () {
                          setState(() {
                            _committedText = '';
                            _liveChunk = '';
                            _transcriptCtrl.clear();
                          });
                        },
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _hasCompleted = true;
            ref.read(voiceServiceProvider).cancel();
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        if (!_isListening)
          OutlinedButton.icon(
            onPressed: () {
              _triedOnDevice = false;
              _startListening();
            },
            icon: const Icon(Icons.mic, size: 16),
            label: Text(hasText ? 'Seguir' : 'Hablar'),
          ),
        FilledButton.icon(
          onPressed: hasText ? _completeAndSubmit : null,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Listo'),
        ),
      ],
    );
  }
}
