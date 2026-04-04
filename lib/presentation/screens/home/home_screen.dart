import 'package:flutter/material.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/mylifeos_integration_service.dart';
import '../../../data/datasources/notification_service.dart';
import '../transactions/transaction_search_delegate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../widgets/common/tutorial_tooltip.dart';
import '../../providers/database_providers.dart';
import '../../providers/balance_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../widgets/common/voice_input_button.dart';
import 'widgets/balance_card.dart';
import 'widgets/month_summary_card.dart';
import 'widgets/recent_transactions_list.dart';
import 'widgets/quick_actions.dart';
import 'widgets/expenses_pie_chart.dart';
import 'widgets/balance_trend_chart.dart';
import 'widgets/budget_summary_widget.dart';
import 'widgets/savings_summary_widget.dart';
import 'widgets/upcoming_recurring_widget.dart';
import 'widgets/month_projection_widget.dart';
import 'widgets/monthly_comparison_widget.dart';
import 'widgets/budget_rule_widget.dart';
import '../../../core/services/update_service.dart';
import '../../widgets/dialogs/update_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();
  final GlobalKey _customizeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTutorial();
      _checkCreditCardAlerts();
      _checkUpdates();
      _exportMyLifeOSSummary();
    });
  }

  /// Exporta el resumen mensual para MyLifeOS.
  Future<void> _exportMyLifeOSSummary() async {
    try {
      final incomeVal = ref.read(currentMonthIncomeProvider);
      final expensesVal = ref.read(currentMonthExpensesProvider);

      final income = incomeVal.when(
        data: (v) => v,
        loading: () => 0.0,
        error: (_, __) => 0.0,
      );

      final expenses = expensesVal.when(
        data: (v) => v,
        loading: () => 0.0,
        error: (_, __) => 0.0,
      );

      final now = DateTime.now();
      final summary = {
        'balance': income - expenses,
        'income': income,
        'expenses': expenses,
        'currency': 'PEN',
        'month': '${now.year}-${now.month.toString().padLeft(2, '0')}',
      };

      final integration = MyLifeOSIntegrationService(
        getMonthlySummary: () async => summary,
      );
      await integration.exportWalletSummary();
    } catch (e) {
      debugPrint('[Home] Error exportando resumen MyLifeOS: $e');
    }
  }

  Future<void> _checkCreditCardAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getString('last_cc_alert_check');
    final today = DateTime.now().toIso8601String().split('T')[0];

    if (lastCheck != today && mounted) {
      final accounts = await ref.read(accountsStreamProvider.future);
      await NotificationService().checkCreditCardDueDates(accounts);
      await prefs.setString('last_cc_alert_check', today);
    }
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('tutorial_home_shown') ?? false;

    if (!shown && mounted) {
      ShowcaseView.get().startShowCase([_summaryKey, _fabKey, _customizeKey]);
      await prefs.setBool('tutorial_home_shown', true);
    }
  }

  Future<void> _checkUpdates() async {
    // Pequeño delay para no saturar el inicio
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final lastDismissed = prefs.getString('update_last_dismissed');

    final updateService = ref.read(updateServiceProvider);
    final release = await updateService.checkForUpdate();

    if (release != null && mounted) {
      // Solo mostrar si no fue descartada antes para esta versión
      if (lastDismissed != release.tagName) {
        showUpdateDialog(
          context,
          release,
          onDismiss: () async {
            await prefs.setString('update_last_dismissed', release.tagName);
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liquidBalanceAsync = ref.watch(liquidBalanceProvider);
    final monthBalanceAsync = ref.watch(currentMonthBalanceProvider);
    final monthIncomeAsync = ref.watch(currentMonthIncomeProvider);
    final monthExpensesAsync = ref.watch(currentMonthExpensesProvider);
    final visibleWidgets = ref.watch(visibleDashboardWidgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        actions: [
          const VoiceInputButton(),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => showSearch(
              context: context,
              delegate: TransactionSearchDelegate(ref),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => context.push('/accounts'),
          ),
          // ─── Personalizar dashboard ──────────────────────────────────
          IconButton(
            icon: const Icon(Icons.dashboard_customize),
            tooltip: AppLocalizations.of(context)!.tooltipCustomize,
            onPressed: () => context.push('/dashboard/customize'),
          ),
          /* Showcase widget disabled for customization for now to reduce clutter, 
             uncomment if needed and add _customizeKey to startShowCase 
             
             Showcase(
               key: _customizeKey,
               description: 'Organiza los widgets a tu gusto',
               child: IconButton(
                 icon: const Icon(Icons.dashboard_customize),
                 onPressed: () => context.push('/dashboard/customize'),
               ),
             ),
          */
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(totalBalanceProvider);
          ref.invalidate(currentMonthBalanceProvider);
          ref.invalidate(currentMonthIncomeProvider);
          ref.invalidate(currentMonthExpensesProvider);
          ref.invalidate(currentMonthExpensesByCategoryProvider);
          ref.invalidate(currentMonthDailyTotalsProvider);
          ref.invalidate(liquidBalanceProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Renderizar widgets en el orden del usuario ────────────
              for (final cfg in visibleWidgets) ...[
                _buildDashboardWidget(
                  type: cfg.type,
                  context: context,
                  ref: ref,
                  liquidBalanceAsync: liquidBalanceAsync,
                  monthBalanceAsync: monthBalanceAsync,
                  monthIncomeAsync: monthIncomeAsync,
                  monthExpensesAsync: monthExpensesAsync,
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
      // FAB removed — central FAB is now in bottom navigation
    );
  }

  Widget _buildDashboardWidget({
    required DashboardWidgetType type,
    required BuildContext context,
    required WidgetRef ref,
    required AsyncValue<double> liquidBalanceAsync,
    required AsyncValue<double> monthBalanceAsync,
    required AsyncValue<double> monthIncomeAsync,
    required AsyncValue<double> monthExpensesAsync,
  }) {
    switch (type) {
      // ── Balance ─────────────────────────────────────────────────────
      case DashboardWidgetType.balanceSummary:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            liquidBalanceAsync.when(
              data: (b) => BalanceCard(
                balance: b,
                title: AppLocalizations.of(context)!.balanceAvailable,
              ),
              loading: () => const LoadingWidget(),
              error: (e, _) => ErrorDisplayWidget(message: e.toString()),
            ),
            const SizedBox(height: 12),
            Showcase.withWidget(
              key: _summaryKey,
              container: TutorialTooltip(
                title: AppLocalizations.of(context)!.showcaseSummaryTitle,
                description: AppLocalizations.of(context)!.showcaseSummaryDesc,
                onNext: () {
                  ShowcaseView.get().completed(_summaryKey);
                  ShowcaseView.get().startShowCase([_fabKey]);
                },
                onSkip: () => ShowcaseView.get().dismiss(),
              ),
              child: MonthSummaryCard(
                incomeAsync: monthIncomeAsync,
                expensesAsync: monthExpensesAsync,
                balanceAsync: monthBalanceAsync,
              ),
            ),
          ],
        );

      // ── Acciones rápidas ─────────────────────────────────────────────
      case DashboardWidgetType.quickActions:
        return const QuickActions();

      // ── Torta de categorías ──────────────────────────────────────────
      case DashboardWidgetType.categoryBreakdown:
        return const ExpensePieChart();

      // ── Tendencia mensual ────────────────────────────────────────────
      case DashboardWidgetType.monthlyTrend:
        return const BalanceTrendChart();

      // ── Presupuestos ─────────────────────────────────────────────────
      case DashboardWidgetType.budgetProgress:
        return const BudgetSummaryWidget();

      // ── Metas de ahorro ──────────────────────────────────────────────
      case DashboardWidgetType.savingsGoals:
        return const SavingsSummaryWidget();

      // ── Próximos pagos recurrentes ───────────────────────────────────
      case DashboardWidgetType.recurringPayments:
        return const UpcomingRecurringWidget();

      // ── Proyección del mes ───────────────────────────────────────────
      case DashboardWidgetType.monthProjection:
        return const MonthProjectionWidget();

      // ── Comparación mensual ──────────────────────────────────────────
      case DashboardWidgetType.monthComparison:
        return const MonthlyComparisonWidget();

      // ── Regla 50/30/20 ──────────────────────────────────────────────
      case DashboardWidgetType.budgetRule:
        return const BudgetRuleWidget();

      case DashboardWidgetType.recentTransactions:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.recentTransactions,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.go('/transactions'),
                  child: Text(AppLocalizations.of(context)!.seeAll),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const RecentTransactionsList(),
          ],
        );
    }
  }
}
