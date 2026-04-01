import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/service_providers.dart';
import '../../providers/database_providers.dart';

class VoiceInputButton extends ConsumerWidget {
  const VoiceInputButton({super.key});

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

        if (result != null && result.isNotEmpty) {
          if (!context.mounted) return;
          // Mostrar indicador de carga mientras la IA procesa
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          try {
            final groq = ref.read(groqServiceProvider);
            final categories = await ref.read(allCategoriesFutureProvider.future);
            
            final aiData = await groq.parseVoiceTransaction(result, categories);
            
            if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // cerrar loading

            if (aiData != null && context.mounted) {
              // Buscar categoría
              String? catId;
              if (aiData['categoria_sugerida'] != null) {
                final matchName = aiData['categoria_sugerida'].toString().toLowerCase();
                try {
                  final match = categories.firstWhere(
                    (c) => (c as dynamic).name.toLowerCase() == matchName,
                  );
                  catId = (match as dynamic).id;
                } catch (_) {
                  // No se encontró coincidencia exacta con sugerencia
                }
              }

              // OVERRIDE DE APRENDIZAJE PERSISTENTE
              final parsedProductName = aiData['producto']?.toString();
              if (parsedProductName != null && parsedProductName.isNotEmpty) {
                 final db = ref.read(databaseProvider);
                 final rule = await db.learningRulesDao.getRuleForProduct(parsedProductName);
                 if (rule != null) {
                   catId = rule.categoryId; // Sobrescribir con lo aprendido
                 }
              }
              
              if (!context.mounted) return;

              context.push(
                '/transactions/create',
                extra: {
                  'type': aiData['tipo'] ?? 'expense',
                  'amount': (aiData['monto'] as num?)?.toDouble() ?? 0.0,
                  'description': aiData['descripcion'],
                  'productName': aiData['producto'],
                  'quantity': (aiData['cantidad'] as num?)?.toDouble() ?? 1.0,
                  'unit': aiData['unidad']?.toString() ?? 'UND',
                  'categoryId': catId,
                },
              );
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop(); // cerrar loading en caso de error
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error AI: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
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
  String _status = 'Iniciando...';

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _startListening);
  }

  Future<void> _startListening() async {
    final voiceService = ref.read(voiceServiceProvider);

    await voiceService.listen(
      onResult: (text) {
        if (mounted) setState(() => _text = text);
      },
      onStatus: (status) {
        if (mounted) setState(() => _status = status);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Escuchando...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mic,
              size: 32,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _text.isEmpty
                ? 'Ej: "Gasto de 20 soles en cena con BCP"'
                : _text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _status,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(voiceServiceProvider).stop();
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            ref.read(voiceServiceProvider).stop();
            Navigator.of(context).pop(_text.isNotEmpty ? _text : null);
          },
          child: const Text('Listo'),
        ),
      ],
    );
  }
}
