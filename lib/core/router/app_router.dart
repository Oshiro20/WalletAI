import 'package:go_router/go_router.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/accounts/accounts_screen.dart';
import '../../presentation/screens/accounts/account_detail_screen.dart';
import '../../presentation/screens/accounts/create_account_screen.dart';
import '../../presentation/screens/accounts/edit_account_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/mylifeos_integration_screen.dart';
import '../../presentation/screens/categories/categories_screen.dart';
import '../../presentation/screens/categories/create_category_screen.dart';
import '../../presentation/screens/categories/create_subcategory_screen.dart';
import '../../presentation/screens/recurring/recurring_payments_screen.dart';
import '../../presentation/screens/recurring/create_recurring_payment_screen.dart';
import '../../presentation/screens/recurring/recurring_suggestions_screen.dart';

import '../../presentation/screens/transactions/create_transaction_screen.dart';
import '../../presentation/screens/transactions/transactions_screen.dart';
import '../../presentation/screens/transactions/edit_transaction_screen.dart';
import '../../presentation/widgets/navigation/main_navigation.dart';
import '../../presentation/screens/analytics/analytics_screen.dart';
import '../../presentation/screens/analytics/statistics_screen.dart';
import '../../presentation/screens/budgets/budgets_screen.dart';
import '../../presentation/screens/savings/savings_goals_screen.dart';
import '../../presentation/screens/reports/pdf_report_screen.dart';
import '../../presentation/screens/backup/backup_screen.dart';
import '../../presentation/screens/receipts/scan_receipt_screen.dart';
import '../../presentation/screens/settings/theme_settings_screen.dart';
import '../../presentation/screens/home/dashboard_customize_screen.dart';
import '../../presentation/screens/settings/about_screen.dart';
import '../../presentation/screens/assistant/assistant_screen.dart';
import '../../presentation/screens/settings/notifications_settings_screen.dart';
import '../../presentation/screens/helper/currency_converter_screen.dart';
import '../../presentation/screens/travels/travels_screen.dart';
import '../../presentation/screens/travels/create_travel_screen.dart';
import '../../presentation/screens/travels/travel_details_screen.dart';
import '../../presentation/screens/analytics/map_analytics_screen.dart';
import '../../presentation/screens/net_worth/net_worth_screen.dart';
import '../../presentation/screens/debt_payoff/debt_payoff_screen.dart';
import '../../presentation/screens/onboarding/onboarding_screen.dart';

// ─── Onboarding check (cache síncrona) ───────────────────────────────────────
bool? _onboardingCache;

/// Verifica síncronamente si el onboarding fue completado
/// Usa cache para evitar llamadas async en el redirect
String? _checkOnboarding() {
  // Si ya está en caché, usar valor cacheado
  if (_onboardingCache == true) return null;
  // Si no está en caché, asumir que no está completado
  // Se verificará async después y se actualizará el caché
  if (_onboardingCache == null) {
    // Verificar async y actualizar caché
    hasCompletedOnboarding().then((done) {
      _onboardingCache = done;
      // Forzar rebuild del router si es necesario
      appRouter.refresh();
    });
    return null; // Permitir navegación inicial
  }
  // Si es false, redirigir a onboarding
  return '/onboarding';
}

/// Configuración de rutas de la aplicación usando go_router
final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // Solo verificar en la ruta inicial — evitar bucles en /onboarding
    if (state.uri.path == '/onboarding') return null;
    // Usar Future synchronously — GoRouter handles this via refreshListenable
    // pero como fallback, verificamos de forma síncrona con un valor cacheado
    return _checkOnboarding();
  },
  routes: [
    // Shell route para mantener el bottom navigation bar
    ShellRoute(
      builder: (context, state, child) {
        return MainNavigation(child: child);
      },
      routes: [
        // Ruta principal - Home
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) =>
              NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
        ),

        // Ruta de transacciones (placeholder para lista completa)
        GoRoute(
          path: '/transactions',
          name: 'transactions',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const TransactionsScreen(),
          ),
        ),

        // Ruta de análisis/estadísticas
        GoRoute(
          path: '/analytics',
          name: 'analytics',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const AnalyticsScreen(),
          ),
        ),

        // Ruta del Asistente IA
        GoRoute(
          path: '/assistant',
          name: 'assistant',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const AssistantScreen(),
          ),
        ),

        // Ruta de configuración
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const SettingsScreen(),
          ),
        ),
      ],
    ),

    // Estadísticas detalladas (pantalla completa sin bottom nav)
    GoRoute(
      path: '/statistics',
      name: 'statistics',
      builder: (context, state) => const StatisticsScreen(),
    ),

    // Presupuestos
    GoRoute(
      path: '/budgets',
      name: 'budgets',
      builder: (context, state) => const BudgetsScreen(),
    ),

    // Metas de ahorro
    GoRoute(
      path: '/savings',
      name: 'savings',
      builder: (context, state) => const SavingsGoalsScreen(),
    ),

    // Reporte PDF
    GoRoute(
      path: '/reports/pdf',
      name: 'pdf-report',
      builder: (context, state) => const PdfReportScreen(),
    ),

    // Copias de Seguridad
    GoRoute(
      path: '/backup',
      name: 'backup',
      builder: (context, state) => const BackupScreen(),
    ),

    // Escanear Factura con IA
    GoRoute(
      path: '/scan-receipt',
      name: 'scan-receipt',
      builder: (context, state) => const ScanReceiptScreen(),
    ),

    // Apariencia (Tema)
    GoRoute(
      path: '/settings/theme',
      name: 'theme-settings',
      builder: (context, state) => const ThemeSettingsScreen(),
    ),

    // Map Analytics
    GoRoute(
      path: '/analytics/map',
      name: 'map-analytics',
      builder: (context, state) => const MapAnalyticsScreen(),
    ),

    // Módulo de Viajes
    GoRoute(
      path: '/travels',
      name: 'travels',
      builder: (context, state) => const TravelsScreen(),
    ),
    GoRoute(
      path: '/travels/create',
      name: 'create-travel',
      builder: (context, state) => const CreateTravelScreen(),
    ),
    GoRoute(
      path: '/travels/:id',
      name: 'travel-details',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return TravelDetailsScreen(travelId: id);
      },
    ),

    // Rutas sin bottom navigation (pantallas modales/secundarias)
    GoRoute(
      path: '/accounts',
      name: 'accounts',
      builder: (context, state) => const AccountsScreen(),
    ),

    GoRoute(
      path: '/accounts/create',
      name: 'create-account',
      builder: (context, state) => const CreateAccountScreen(),
    ),

    GoRoute(
      path: '/accounts/edit/:id',
      name: 'edit-account',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EditAccountScreen(accountId: id);
      },
    ),

    GoRoute(
      path: '/accounts/detail/:id',
      name: 'account-detail',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return AccountDetailScreen(accountId: id);
      },
    ),

    GoRoute(
      path: '/transactions/create',
      name: 'create-transaction',
      builder: (context, state) {
        final type = state.uri.queryParameters['type'];
        final extra = state.extra as Map<String, dynamic>?;
        // Convertir timestamp a DateTime si viene del escáner
        final dateMs = extra?['date'] as int?;
        final date = dateMs != null
            ? DateTime.fromMillisecondsSinceEpoch(dateMs)
            : null;
        return CreateTransactionScreen(
          initialType: type ?? extra?['type'],
          initialAmount: (extra?['amount'] as num?)?.toDouble(),
          initialDescription: extra?['description'],
          initialProductName: extra?['productName'],
          initialCategoryId: extra?['categoryId'],
          initialSubcategoryId: extra?['subcategoryId'],
          initialAccountId: extra?['accountId'],
          initialDate: date,
        );
      },
    ),

    // Editar transacción
    GoRoute(
      path: '/transactions/edit/:id',
      name: 'edit-transaction',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return EditTransactionScreen(transactionId: id);
      },
    ),

    // Rutas de Categorías
    GoRoute(
      path: '/categories',
      name: 'categories',
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: '/categories/create',
      name: 'create-category',
      builder: (context, state) {
        final type = state.uri.queryParameters['type'];
        return CreateCategoryScreen(initialType: type);
      },
    ),
    GoRoute(
      path: '/categories/edit/:id',
      name: 'edit-category',
      builder: (context, state) {
        final id = state.pathParameters['id'];
        return CreateCategoryScreen(categoryId: id);
      },
    ),
    GoRoute(
      path: '/categories/:id/subcategories/create',
      name: 'create-subcategory',
      builder: (context, state) {
        final categoryId = state.pathParameters['id']!;
        return CreateSubcategoryScreen(categoryId: categoryId);
      },
    ),

    // Rutas de Pagos Recurrentes
    GoRoute(
      path: '/recurring',
      name: 'recurring-payments',
      builder: (context, state) => const RecurringPaymentsScreen(),
    ),
    GoRoute(
      path: '/recurring/create',
      name: 'create-recurring-payment',
      builder: (context, state) => const CreateRecurringPaymentScreen(),
    ),
    GoRoute(
      path: '/recurring/suggestions',
      name: 'recurring-suggestions',
      builder: (context, state) => const RecurringSuggestionsScreen(),
    ),
    GoRoute(
      path: '/dashboard/customize',
      name: 'dashboard-customize',
      builder: (context, state) => const DashboardCustomizeScreen(),
    ),
    GoRoute(
      path: '/about',
      name: 'about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/settings/mylifeos',
      name: 'settings-mylifeos',
      builder: (context, state) => const MyLifeOSIntegrationScreen(),
    ),
    GoRoute(
      path: '/settings/notifications',
      name: 'settings-notifications',
      builder: (context, state) => const NotificationsSettingsScreen(),
    ),
    GoRoute(
      path: '/currency',
      name: 'currency-converter',
      builder: (context, state) => const CurrencyConverterScreen(),
    ),
    GoRoute(
      path: '/net-worth',
      name: 'net-worth',
      builder: (context, state) => const NetWorthScreen(),
    ),
    GoRoute(
      path: '/debt-payoff',
      name: 'debt-payoff',
      builder: (context, state) => const DebtPayoffScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
  ],
);
