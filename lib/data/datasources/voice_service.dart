import 'package:speech_to_text/speech_to_text.dart';
import 'package:logger/logger.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  final _logger = Logger();
  bool _isAvailable = false;
  String? _cachedLocaleId;
  Future<bool>? _initFuture;
  void Function(String)? _statusListener;
  void Function(String)? _errorListener;

  Future<bool> initialize() {
    if (_isAvailable) return Future.value(true);
    return _initFuture ??= _speech
        .initialize(
          onError: (val) {
            _logger.e('onError: $val');
            _errorListener?.call(val.errorMsg);
          },
          onStatus: (val) {
            _logger.i('onStatus: $val');
            _statusListener?.call(val);
          },
        )
        .then((ok) async {
          _isAvailable = ok;
          if (ok && _cachedLocaleId == null) {
            _cachedLocaleId = await _resolveSpanishLocaleId();
          }
          return ok;
        })
        .catchError((_) {
          _initFuture = null;
          return false;
        });
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

    final localeId = _cachedLocaleId ??= await _resolveSpanishLocaleId();

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      localeId: localeId,
      listenFor: const Duration(seconds: 25),
      pauseFor: const Duration(milliseconds: 950),
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
