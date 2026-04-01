/// Constantes globales de la aplicación
class AppConstants {
  // Información de la app
  static const String appName = 'Control Financiero';
  static const String appVersion = '1.0.0';
  
  // Base de datos
  static const String dbName = 'finanzas.db';
  static const int dbVersion = 1;
  
  // Sincronización
  static const Duration syncInterval = Duration(hours: 6);
  static const String driveBackupFolder = 'ControlFinanciero_Backups';
  
  // Límites
  static const int maxTransactionsPerPage = 20;
  static const int maxAttachmentSizeMB = 10;
  static const int maxVoiceRecordingSeconds = 60;
  
  // Gemini AI
  static const int maxGeminiRequestsPerDay = 1500;
  static const String geminiModel = 'gemini-1.5-flash';
  
  // Categorías del sistema (no se pueden eliminar)
  static const List<String> systemCategoryIds = [
    'cat_alojamiento',
    'cat_servicios_digitales',
    'cat_transporte',
    'cat_educacion',
    'cat_salud',
    'cat_alimentacion',
    'cat_pareja',
    'cat_trabajo',
    'cat_entretenimiento',
    'cat_ropa',
    'cat_cuidado_personal',
    'cat_familia',
    'cat_mascotas',
    'cat_antojos',
    'cat_otro_gasto',
    'cat_dinero_mensual',
    'cat_salario',
    'cat_dinero_extra',
    'cat_plus',
    'cat_otro_ingreso',
  ];
}
