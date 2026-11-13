import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/financial_context_builder.dart';
import '../../../data/datasources/assistant_service.dart' hide ChatMessage;
import '../../../data/datasources/groq_service.dart';
import '../../../data/datasources/keep_alive_service.dart';

// ─── Modelo de Mensaje ────────────────────────────────────────────────────────

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String,
    isUser: json['isUser'] as bool,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref _ref;
  GroqService? _groq;
  bool _isLoading = false;

  static const _kHistoryKey = 'chat_history_v1';
  static const _maxStoredMessages = 30;

  static const _welcomeMessage =
      '👋 ¡Hola! Soy WalletAI, tu asistente financiero con IA. Puedes preguntarme cualquier cosa sobre tus finanzas, consejos de ahorro, análisis de gastos o lo que necesites. 💬';

  ChatNotifier(this._ref) : super([]) {
    _loadHistory();
  }

  bool get isLoading => _isLoading;

  GroqService _getGroq() {
    _groq ??= GroqService();
    return _groq!;
  }

  // ─── Persistencia ────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHistoryKey);
      if (raw != null && raw.isNotEmpty) {
        final list = (jsonDecode(raw) as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          state = list;
          return;
        }
      }
    } catch (_) {}
    // Primera vez: mensaje de bienvenida
    state = [
      ChatMessage(
        text: _welcomeMessage,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
  }

  Future<void> _saveHistory(List<ChatMessage> messages) async {
    try {
      // Filtrar el indicador de "escribiendo" antes de guardar
      final toSave = messages
          .where((m) => m.text != '...')
          .take(_maxStoredMessages)
          .toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kHistoryKey,
        jsonEncode(toSave.map((m) => m.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    _isLoading = true;
    state = [
      ...state,
      ChatMessage(text: text.trim(), isUser: true, timestamp: DateTime.now()),
    ];

    final typing = ChatMessage(
      text: '...',
      isUser: false,
      timestamp: DateTime.now(),
    );
    state = [...state, typing];

    final contextBuilder = _ref.read(financialContextBuilderProvider);
    final localAssistant = _ref.read(assistantServiceProvider);
    final context = await contextBuilder.buildContext(userQuery: text);
    final groq = _getGroq();
    final response = await groq.sendMessage(
      text,
      financialContext: context,
      offlineFallback: (q) => localAssistant.processQuestion(q),
    );

    final msgs = [...state];
    msgs.removeLast();
    final finalMsgs = [
      ...msgs,
      ChatMessage(text: response, isUser: false, timestamp: DateTime.now()),
    ];
    state = finalMsgs;
    _isLoading = false;
    await _saveHistory(finalMsgs);
  }

  void clearMessages() {
    _groq?.resetSession();
    final welcome = [
      ChatMessage(
        text: '🔄 Chat reiniciado. ¿En qué puedo ayudarte?',
        isUser: false,
        timestamp: DateTime.now(),
      ),
    ];
    state = welcome;
    _saveHistory(welcome); // limpiar historial persistido
  }
}

final chatNotifierProvider =
    StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
      (ref) => ChatNotifier(ref),
    );

// ─── Pantalla ─────────────────────────────────────────────────────────────────

class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();

  // Sugerencias iniciales orientadas a datos reales del usuario
  static const _suggestions = [
    '¿Cuánto gasté este mes?',
    '¿Cuál es mi saldo y mis deudas?',
    '¿En qué categoría gasto más?',
    '¿Cómo van mis presupuestos y metas?',
    '¿Qué pagos recurrentes o cuotas tengo?',
    'Compara mis gastos con el mes pasado',
  ];

  @override
  void initState() {
    super.initState();
    keepAliveService.wakeUp();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? text]) {
    final msg = text ?? _msgController.text;
    if (msg.trim().isEmpty) return;
    _msgController.clear();
    ref.read(chatNotifierProvider.notifier).sendMessage(msg);
    Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatNotifierProvider);
    final notifier = ref.watch(chatNotifierProvider.notifier);
    final isLoading = notifier.isLoading;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              radius: 16,
              child: Icon(Icons.auto_awesome, size: 18, color: cs.primary),
            ),
            const SizedBox(width: 10),
            const Text(
              'Asistente IA',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Nuevo chat',
            onPressed: () =>
                ref.read(chatNotifierProvider.notifier).clearMessages(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length + (isLoading ? 0 : 0),
              itemBuilder: (context, i) {
                final msg = messages[i];
                return _MessageBubble(message: msg, cs: cs);
              },
            ),
          ),

          // Sugerencias (solo si hay pocas mensajes)
          if (messages.length <= 1)
            _SuggestionsBar(suggestions: _suggestions, onTap: _send),

          // Input
          _ChatInput(
            controller: _msgController,
            isLoading: isLoading,
            onSend: _send,
            cs: cs,
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ColorScheme cs;

  const _MessageBubble({required this.message, required this.cs});

  @override
  Widget build(BuildContext context) {
    final isTyping = message.text == '...';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: cs.primaryContainer,
              radius: 14,
              child: Icon(Icons.auto_awesome, size: 14, color: cs.primary),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: message.isUser ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(message.isUser ? 18 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 18),
                ),
              ),
              child: isTyping
                  ? _TypingIndicator(color: cs.onSurfaceVariant)
                  : Text(
                      message.text,
                      style: TextStyle(
                        color: message.isUser ? cs.onPrimary : cs.onSurface,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
          if (message.isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final Color color;
  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          3,
          (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: ((_ctrl.value + i * 0.3) % 1.0).clamp(0.3, 1.0),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionsBar extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;

  const _SuggestionsBar({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          label: Text(suggestions[i], style: const TextStyle(fontSize: 12)),
          onPressed: () => onTap(suggestions[i]),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final void Function([String?]) onSend;
  final ColorScheme cs;

  const _ChatInput({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Pregunta lo que quieras...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  filled: true,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: FloatingActionButton.small(
                onPressed: isLoading ? null : () => onSend(),
                backgroundColor: isLoading
                    ? cs.surfaceContainerHighest
                    : cs.primary,
                child: isLoading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: cs.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
