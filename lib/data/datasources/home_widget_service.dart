import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../../presentation/providers/database_providers.dart';

/// Servicio que empuja los datos más recientes hacia los widgets nativos de pantalla de inicio.
/// Debe llamarse: al iniciar la app, tras cada transacción nueva, y cuando la app pasa a background.
class HomeWidgetService {
  static const _appGroupId = 'com.finanzas.aplicativo_gastos'; // ≡ applicationId
  static final _fmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

  /// Actualiza el widget de Balance con los datos actuales.
  static Future<void> updateBalanceWidget(Ref ref) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      // Balance líquido disponible — calculado directamente desde el DAO (lectura puntual)
      final accountsDao = ref.read(accountsDaoProvider);
      final allAccounts = await accountsDao.getAllAccounts();
      final balance = allAccounts
          .where((a) => a.type == 'cash' || a.type == 'bank' || a.type == 'wallet')
          .fold<double>(0.0, (sum, a) => sum + a.balance);
      final summary = await ref.read(currentMonthSummaryProvider.future).catchError((_) => <String, double>{});
      final income  = summary['income'] ?? 0.0;
      final expense = summary['expense'] ?? 0.0;

      final now = DateTime.now();
      final updated = 'Act. ${DateFormat('HH:mm').format(now)}';

      await Future.wait([
        HomeWidget.saveWidgetData<String>('hw_balance_amount',  _fmt.format(balance)),
        HomeWidget.saveWidgetData<String>('hw_balance_income',  _fmt.format(income)),
        HomeWidget.saveWidgetData<String>('hw_balance_expense', _fmt.format(expense)),
        HomeWidget.saveWidgetData<String>('hw_balance_updated', updated),
      ]);

      await HomeWidget.updateWidget(
        name: 'BalanceWidget',
        androidName: 'BalanceWidget',
        qualifiedAndroidName: 'com.finanzas.aplicativo_gastos.BalanceWidget',
      );

      debugPrint('HomeWidgetService: balance widget actualizado');
    } catch (e) {
      debugPrint('HomeWidgetService.updateBalanceWidget: $e');
    }
  }

  /// Actualiza el widget de Próximos Pagos Recurrentes.
  static Future<void> updateRecurringWidget(Ref ref) async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);

      final dao = ref.read(recurringPaymentsDaoProvider);
      final all = await dao.getAllRecurringPayments();
      final now = DateTime.now();

      // Pagos activos ordenados por fecha
      final upcoming = all
          .where((p) => p.isActive)
          .toList()
        ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

      final top3 = upcoming.take(3).toList();

      for (int i = 0; i < 3; i++) {
        final idx = i + 1;
        if (i < top3.length) {
          final p = top3[i];
          final daysLeft = p.nextDueDate.difference(now).inDays;
          final when = daysLeft < 0
              ? ' (vencido)'
              : daysLeft == 0
                  ? ' (hoy)'
                  : ' ($daysLeft d.)';
          await HomeWidget.saveWidgetData<String>('hw_recurring_name$idx',   '${p.name}$when');
          await HomeWidget.saveWidgetData<String>('hw_recurring_amount$idx', _fmt.format(p.amount));
        } else {
          await HomeWidget.saveWidgetData<String>('hw_recurring_name$idx',   '');
          await HomeWidget.saveWidgetData<String>('hw_recurring_amount$idx', '');
        }
      }

      await HomeWidget.updateWidget(
        name: 'RecurringWidget',
        androidName: 'RecurringWidget',
        qualifiedAndroidName: 'com.finanzas.aplicativo_gastos.RecurringWidget',
      );

      debugPrint('HomeWidgetService: recurring widget actualizado');
    } catch (e) {
      debugPrint('HomeWidgetService.updateRecurringWidget: $e');
    }
  }

  /// Actualiza ambos widgets a la vez.
  static Future<void> updateAll(Ref ref) async {
    await Future.wait([
      updateBalanceWidget(ref),
      updateRecurringWidget(ref),
    ]);
  }
}

/// Provider de conveniencia para disparar actualizaciones de widgets
/// sin romper el árbol de providers.
final homeWidgetUpdaterProvider = Provider<HomeWidgetUpdater>((ref) {
  return HomeWidgetUpdater(ref);
});

class HomeWidgetUpdater {
  final Ref _ref;
  HomeWidgetUpdater(this._ref);

  Future<void> updateAll() => HomeWidgetService.updateAll(_ref);
}
