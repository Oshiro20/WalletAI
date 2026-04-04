import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../database/drift_database.dart';
import '../database/daos/transactions_dao.dart';

/// Servicio de notificaciones inteligentes del asesor financiero
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _tz = false;

  static const _prefEnabled = 'daily_reminder_enabled';
  static const _prefHour = 'daily_reminder_hour';
  static const _prefMin = 'daily_reminder_min';
  static const int _dailyReminderId = 9001;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> _initTz() async {
    if (_tz) return;
    tzdata.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    _tz = true;
  }

  /// Solicitar permisos de notificación (Android 13+)
  Future<void> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
  }

  /// Llama esto al iniciar la app — reactiva el recordatorio si fue configurado
  Future<void> rescheduleIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefEnabled) ?? false;
    if (!enabled) return;
    final hour = prefs.getInt(_prefHour) ?? 20;
    final min = prefs.getInt(_prefMin) ?? 0;
    await scheduleDailyReminder(hour: hour, minute: min);
  }

  /// Programa un recordatorio diario a la hora indicada
  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    await initialize();
    await _initTz();

    // Cancela cualquier recordatorio anterior
    await _plugin.cancel(_dailyReminderId);

    // Calcula el próximo disparo
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Recordatorio Diario',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.zonedSchedule(
      _dailyReminderId,
      '📝 ¿Registraste tus gastos de hoy?',
      'Mantén tu control financiero al día.',
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repite diariamente
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    // Persiste preferencias
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, true);
    await prefs.setInt(_prefHour, hour);
    await prefs.setInt(_prefMin, minute);
  }

  /// Cancela el recordatorio diario
  Future<void> cancelDailyReminder() async {
    await initialize();
    await _plugin.cancel(_dailyReminderId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEnabled, false);
  }

  /// Notificación: Presupuesto al 80%
  Future<void> notifyBudgetWarning({
    required String categoryName,
    required double spent,
    required double limit,
  }) async {
    await _show(
      id: categoryName.hashCode,
      title: '⚠️ Presupuesto al ${(spent / limit * 100).toStringAsFixed(0)}%',
      body:
          '$categoryName: S/ ${spent.toStringAsFixed(2)} de S/ ${limit.toStringAsFixed(2)}',
      channel: 'budget_alerts',
      channelName: 'Alertas de Presupuesto',
    );
  }

  /// Notificación: Presupuesto superado
  Future<void> notifyBudgetExceeded({
    required String categoryName,
    required double spent,
    required double limit,
  }) async {
    await _show(
      id: categoryName.hashCode + 1,
      title: '🚨 Presupuesto superado en $categoryName',
      body:
          'Gastaste S/ ${spent.toStringAsFixed(2)} (límite: S/ ${limit.toStringAsFixed(2)})',
      channel: 'budget_alerts',
      channelName: 'Alertas de Presupuesto',
    );
  }

  /// Notificación: Gasto inusualmente alto
  Future<void> notifyHighExpense({
    required String description,
    required double amount,
    required double dailyAverage,
  }) async {
    await _show(
      id: 9002,
      title: '💸 Gasto alto detectado',
      body:
          '"$description" (S/ ${amount.toStringAsFixed(2)}) es ${(amount / dailyAverage).toStringAsFixed(1)}x tu promedio diario.',
      channel: 'spending_alerts',
      channelName: 'Alertas de Gasto',
    );
  }

  /// Notificación: Meta de ahorro alcanzada
  Future<void> notifyGoalCompleted({required String goalName}) async {
    await _show(
      id: goalName.hashCode,
      title: '🎉 ¡Meta alcanzada!',
      body: 'Completaste tu meta "$goalName". ¡Felicitaciones!',
      channel: 'savings_alerts',
      channelName: 'Alertas de Ahorro',
    );
  }

  /// Notificación: Resumen mensual disponible
  Future<void> notifyMonthlySummary({
    required double totalExpense,
    required double totalIncome,
  }) async {
    final balance = totalIncome - totalExpense;
    final emoji = balance >= 0 ? '✅' : '⚠️';
    await _show(
      id: 9003,
      title: '$emoji Resumen del mes disponible',
      body:
          'Ingresos: S/ ${totalIncome.toStringAsFixed(2)} | Gastos: S/ ${totalExpense.toStringAsFixed(2)}',
      channel: 'monthly_summary',
      channelName: 'Resumen Mensual',
    );
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channel,
    required String channelName,
  }) async {
    await initialize();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  /// Verificar presupuestos y disparar alertas si es necesario
  Future<void> checkBudgetAlerts({
    required List<Budget> budgets,
    required TransactionsDao transactionsDao,
    required List<Category> categories,
  }) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    for (final budget in budgets) {
      final expensesByCategory = await transactionsDao.getExpensesByCategory(
        startOfMonth,
        endOfMonth,
      );
      final spent = expensesByCategory[budget.categoryId] ?? 0;
      final pct = spent / budget.amount;

      final cat = categories
          .where((c) => c.id == budget.categoryId)
          .firstOrNull;
      final catName = cat?.name ?? budget.categoryId;

      if (pct >= 1.0) {
        await notifyBudgetExceeded(
          categoryName: catName,
          spent: spent,
          limit: budget.amount,
        );
      } else if (pct >= 0.8) {
        await notifyBudgetWarning(
          categoryName: catName,
          spent: spent,
          limit: budget.amount,
        );
      }
    }
  }

  /// Verificar fechas de vencimiento de tarjetas de crédito
  Future<void> checkCreditCardDueDates(List<Account> accounts) async {
    final now = DateTime.now();
    for (final account in accounts) {
      if (account.type != 'credit_card' || account.paymentDueDay == null) {
        continue;
      }

      final dueDay = account.paymentDueDay!;
      int maxDays = DateTime(now.year, now.month + 1, 0).day;
      int actualDueDay = dueDay > maxDays ? maxDays : dueDay;

      final dueDate = DateTime(now.year, now.month, actualDueDay);
      final difference = dueDate
          .difference(DateTime(now.year, now.month, now.day))
          .inDays;

      if (difference == 3) {
        await _show(
          id: account.id.hashCode + 200,
          title: '💳 Tarjeta por vencer',
          body: 'Faltan 3 días para pagar tu tarjeta ${account.name}.',
          channel: 'credit_card_alerts',
          channelName: 'Alertas de Tarjeta',
        );
      } else if (difference == 1) {
        await _show(
          id: account.id.hashCode + 200,
          title: '⚠️ Tarjeta vence mañana',
          body: 'Recuerda pagar tu tarjeta ${account.name} mañana.',
          channel: 'credit_card_alerts',
          channelName: 'Alertas de Tarjeta',
        );
      } else if (difference == 0) {
        await _show(
          id: account.id.hashCode + 200,
          title: '🚨 Pago de tarjeta HOY',
          body: 'Hoy es el último día para pagar tu tarjeta ${account.name}.',
          channel: 'credit_card_alerts',
          channelName: 'Alertas de Tarjeta',
        );
      }
    }
  }
}
