/// Configuración centralizada de la aplicación.
/// En producción, reemplaza los valores por los reales o usa
/// variables de entorno mediante `--dart-define` al compilar:
///
///   flutter run --dart-define=API_BASE_URL=https://tu-backend.com/api
///   flutter build apk --dart-define=API_BASE_URL=https://tu-backend.com/api
class AppConfig {
  AppConfig._();

  /// URL base del backend de WalletAI (Groq proxy + recibo OCR).
  /// Configurable en tiempo de compilación con --dart-define=API_BASE_URL=...
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-gastos-6iri.onrender.com/api',
  );

  /// Nombre de la app (para uso en notificaciones, etc.)
  static const String appName = 'WalletAI';

  /// Versión de la app
  static const String appVersion = '1.1.0';

  /// Máximo de mensajes en el historial del asistente
  static const int chatHistoryLimit = 30;

  /// Número de días para considerar una tasa de cambio como "fresca"
  static const int currencyCacheDays = 1;
}
