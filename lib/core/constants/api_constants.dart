/// Constantes de API
class ApiConstants {
  // Gemini AI
  static const String geminiApiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  
  // Google Drive
  static const String driveApiBaseUrl = 'https://www.googleapis.com/drive/v3';
  static const List<String> driveScopes = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.appdata',
  ];
  
  // Endpoints
  static const String geminiGenerateEndpoint = '/models/gemini-1.5-flash:generateContent';
}
