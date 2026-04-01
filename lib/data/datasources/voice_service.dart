import 'package:speech_to_text/speech_to_text.dart';
import 'package:logger/logger.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  final _logger = Logger();
  bool _isAvailable = false;

  Future<bool> initialize() async {
    if (!_isAvailable) {
      _isAvailable = await _speech.initialize(
        onError: (val) => _logger.e('onError: $val'),
        onStatus: (val) => _logger.i('onStatus: $val'),
      );
    }
    return _isAvailable;
  }

  Future<void> listen({
    required Function(String) onResult,
    required Function(String) onStatus, // listening, notListening, done
  }) async {
    if (!_isAvailable) {
      bool available = await initialize();
      if (!available) {
        onStatus('unavailable');
        return;
      }
    }

    await _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
      },
      localeId: 'es_PE', // Default to Spanish Peru, maybe fallback to 'es'
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        listenMode: ListenMode.confirmation, // Good for short commands
      ),
    );
  }

  Future<void> stop() async {
    await _speech.stop();
  }
}
