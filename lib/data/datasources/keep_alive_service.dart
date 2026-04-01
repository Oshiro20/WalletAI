import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Servicio para mantener despierto el backend de Render.com
/// Render duerme las instancias gratuitas tras 15 minutos de inactividad.
/// Este servicio hace un "ping" (HTTP GET) cada 10 minutos mientras la app está abierta,
/// y también lanza un ping inmediato al iniciar la app para que el backend
/// vaya despertando mientras el usuario navega por la interfaz antes de usar el escáner.
class KeepAliveService {
  static const String _url = 'https://api-gastos-6iri.onrender.com/';
  Timer? _timer;

  /// Inicia el ciclo de keep-alive. Debe llamarse al abrir la app.
  void start() {
    // Ping inmediato al arrancar la app
    _ping();
    
    // Ping periódico cada 10 minutos
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _ping());
  }

  /// Detiene el ciclo de keep-alive.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ping() async {
    try {
      if (kDebugMode) {
        print('🕒 KeepAliveService: Enviando ping a Render.com para evitar cold-start...');
      }
      
      // Llamada "fire-and-forget" con timeout largo (el cold start puede durar ~50s)
      // Usamos el endpoint raíz para no procesar nada pesado
      final response = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 60));
      
      if (kDebugMode) {
        print('✅ KeepAliveService: Backend respondió con código ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ KeepAliveService: Fallo en el ping (probablemente timeout, pero el backend igual despertará): $e');
      }
    }
  }
}

// Instancia global
final keepAliveService = KeepAliveService();
