import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'core/router/app_router.dart';
import 'core/services/wallet_summary_service.dart';
import 'data/datasources/recurrence_service.dart';
import 'data/datasources/keep_alive_service.dart';
import 'data/database/drift_database.dart';
import 'presentation/providers/theme_provider.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recurrenceServiceProvider).checkDuePayments();
      // Exportar resumen para MyLifeOS (silencioso, no bloquea UI)
      WalletSummaryService(AppDatabase()).exportSummary();
    });
    // Iniciar keep-alive para despertar backend
    keepAliveService.start();
  }

  @override
  void dispose() {
    keepAliveService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeProvider);
    final lightTheme = ref.watch(lightThemeProvider);
    final darkTheme  = ref.watch(darkThemeProvider);

    return MaterialApp.router(
      title: 'WalletAI',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es'),
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeState.mode,
      routerConfig: appRouter,
    );
  }
}
