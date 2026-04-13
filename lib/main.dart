import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'data/datasources/notification_service.dart';
import 'data/datasources/auto_sync_service.dart';
import 'app.dart';

// Callback de background para refrescar widgets desde el sistema
@pragma('vm:entry-point')
Future<void> _homeWidgetBackgroundCallback(Uri? uri) async {
  // No es necesario hacer nada especial aquí —
  // los widgets leen directamente de SharedPreferences.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar variables de entorno (opcional, solo en desarrollo)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // Si no encuentra el .env, continúa normalmente
    // Las API keys pueden estar configuradas por el usuario en ajustes
  }

  await initializeDateFormatting('es_PE', null);

  // Registrar callback de background para home_widget
  HomeWidget.registerInteractivityCallback(_homeWidgetBackgroundCallback);

  // Inicializar servicio de notificaciones
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();
  await notificationService
      .rescheduleIfEnabled(); // reactivar recordatorio al reiniciar app

  // Inicializar servicio de sincronización automática (Workmanager)
  await AutoSyncService().initialize();

  // Configurar manejo de errores global para UI
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '¡Ups! Algo salió mal.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details.exception.toString(),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    details.stack.toString().split('\n').take(5).join('\n'),
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.left,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  };

  ShowcaseView.register();

  runApp(const ProviderScope(child: MyApp()));
}
