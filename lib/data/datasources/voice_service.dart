import 'package:speech_to_text/speech_to_text.dart';
import 'package:logger/logger.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  final _logger = Logger();
  bool _isAvailable = false;
  void Function(String)? _statusListener;
  void Function(String)? _errorListener;

  Future<bool> initialize() async {
    if (!_isAvailable) {
      _isAvailable = await _speech.initialize(
        onError: (val) {
          _logger.e('onError: $val');
          _errorListener?.call(val.errorMsg);
        },
        onStatus: (val) {
          _logger.i('onStatus: $val');
          _statusListener?.call(val);
        },
      );
    }
    return _isAvailable;
  }

  Future<String?> _resolveSpanishLocaleId() async {
    try {
      final locales = await _speech.locales();
      if (locales.isEmpty) return 'es_PE';
      for (final preferred in ['es_PE', 'es_419', 'es_ES', 'es_MX']) {
        final match = locales
            .where((l) => l.localeId.toLowerCase() == preferred.toLowerCase())
            .firstOrNull;
        if (match != null) return match.localeId;
      }
      final anySpanish = locales
          .where((l) => l.localeId.toLowerCase().startsWith('es'))
          .firstOrNull;
      return anySpanish?.localeId;
    } catch (_) {
      return 'es_PE';
    }
  }

  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
    required void Function(String status) onStatus,
    void Function(String error)? onError,
  }) async {
    _statusListener = onStatus;
    _errorListener = onError;

    if (!_isAvailable) {
      final available = await initialize();
      if (!available) {
        onStatus('unavailable');
        return;
      }
    }

    final localeId = await _resolveSpanishLocaleId();

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(milliseconds: 1600),
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        partialResults: true,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stop() async {
    _statusListener = null;
    _errorListener = null;
    await _speech.stop();
  }

  Future<void> cancel() async {
    _statusListener = null;
    _errorListener = null;
    await _speech.cancel();
  }
}
