import 'package:google_generative_ai/google_generative_ai.dart';

/// Servicio que se conecta a Gemini Flash para responder preguntas financieras.
/// Obtén tu API key gratis en https://aistudio.google.com/apikey
class GeminiService {
  static const String _defaultApiKey = 'AIzaSyALEvE5k4Da3QKOrFLDonQdEiDj-X_MJ9o';

  /// True si el usuario ya configuró su API key
  static bool get isConfigured => _defaultApiKey != 'YOUR_GEMINI_API_KEY';

  final String _apiKey;
  late final GenerativeModel _model;
  late ChatSession _chat;

  GeminiService({String? apiKey}) : _apiKey = apiKey ?? _defaultApiKey {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
      systemInstruction: Content.system(
        '''Eres WalletAI, un asistente financiero personal inteligente integrado en una app de gestión de gastos. 
Tu rol es ayudar al usuario a entender sus finanzas, dar consejos, analizar datos y responder cualquier pregunta sobre dinero, ahorro y gastos.

Reglas:
- Responde siempre en español
- Sé conciso y amigable (máximo 3-4 párrafos)
- Usa emojis con moderación para hacer las respuestas más visuales
- Cuando tengas datos financieros del usuario en el contexto, úsalos para personalizar tu respuesta
- Si el usuario pregunta de presupuestos, ahorros, gastos o ingresos, relaciona la respuesta con sus datos reales
- Si no tienes datos del usuario para una pregunta específica, responde con consejos generales
- No inventes datos que no te han proporcionado''',
      ),
    );
    _chat = _model.startChat();
  }

  /// Envía una pregunta al modelo con el contexto financiero del usuario
  Future<String> sendMessage(String userMessage, {String? financialContext}) async {
    try {
      final contextPrefix = financialContext != null && financialContext.isNotEmpty
          ? '**Datos financieros del usuario:**\n$financialContext\n\n**Pregunta del usuario:**\n'
          : '';

      final fullMessage = '$contextPrefix$userMessage';
      final response = await _chat.sendMessage(Content.text(fullMessage));
      return response.text ?? 'No pude generar una respuesta. Intenta de nuevo.';
    } on GenerativeAIException catch (e) {
      if (e.message.contains('API_KEY_INVALID') || e.message.contains('API key not valid')) {
        return '🔑 La API key de Gemini no es válida. Ve a **Ajustes → API Key Gemini** para configurarla. Obtén una gratis en https://aistudio.google.com';
      } else if (e.message.contains('QUOTA_EXCEEDED') || e.message.contains('Resource has been exhausted')) {
        return '⏳ Has alcanzado el límite de consultas gratuitas. Intenta más tarde.';
      }
      return '❌ Error al conectar con Gemini: ${e.message}';
    } catch (e) {
      return '❌ Error inesperado: $e';
    }
  }

  /// Limpia el historial de chat (nueva sesión)
  void resetSession() {
    _chat = _model.startChat();
  }
}
