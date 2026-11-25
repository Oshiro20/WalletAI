import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import '../database/drift_database.dart';
import '../database/daos/transactions_dao.dart';
import '../../core/utils/credit_card_calculator.dart';

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

  static const prefCardAlertsEnabled = 'credit_card_alerts_enabled';
  static const prefCardAlertsDaysBefore = 'credit_card_alerts_days_before';
  static const _prefRecurringIds = 'scheduled_recurring_notif_ids';
  static const int _recurringBatchId = 9004;
  static const int _testScheduledId = 9099;

  Future<bool> isCardAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefCardAlertsEnabled) ?? true;
  }

  Future<void> setCardAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefCardAlertsEnabled, enabled);
  }

  Future<int> getCardAlertsDaysBefore() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(prefCardAlertsDaysBefore) ?? 3).clamp(1, 7);
  }

  Future<void> setCardAlertsDaysBefore(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(prefCardAlertsDaysBefore, days.clamp(1, 7));
  }

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
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      debugPrint('[NotificationService] Fallback timezone: $e');
      final offsetHours = DateTime.now().timeZoneOffset.inHours;
      if (offsetHours == -5) {
        tz.setLocalLocation(tz.getLocation('America/Lima'));
      } else {
        tz.setLocalLocation(tz.UTC);
      }
    }
    _tz = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Solicitar permisos de notificación (Android 13+)
  Future<bool> requestPermissions() async {
    await initialize();
    try {
      final granted = await _androidPlugin?.requestNotificationsPermission();
      return granted ?? true;
    } catch (e) {
      debugPrint('[NotificationService] requestPermissions error: $e');
      return false;
    }
  }

  /// Verifica si el permiso de notificaciones está activo en el sistema.
  Future<bool> areNotificationsEnabled() async {
    await initialize();
    try {
      return await _androidPlugin?.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Verifica si Android permite programar alarmas exactas (Android 12+).
  Future<bool> canScheduleExactAlarms() async {
    await initialize();
    try {
      return await _androidPlugin?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Abre la solicitud de permiso de alarmas exactas en Android 12+.
  Future<bool> requestExactAlarmPermission() async {
    await initialize();
    try {
      final granted = await _androidPlugin?.requestExactAlarmsPermission();
      return granted ?? await canScheduleExactAlarms();
    } catch (e) {
      debugPrint('[NotificationService] requestExactAlarmPermission error: $e');
      return false;
    }
  }

  /// Programa con alarma exacta si está permitido; si no, hace fallback seguro a inexactAllowWhileIdle.
  Future<void> _zonedScheduleSafe({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails details,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    final canExact = await canScheduleExactAlarms();
    final primaryMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: primaryMode,
        matchDateTimeComponents: matchDateTimeComponents,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      if (primaryMode == AndroidScheduleMode.exactAllowWhileIdle) {
        debugPrint(
          '[NotificationService] exactAllowWhileIdle falló ($e), reintentando con inexactAllowWhileIdle',
        );
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduledDate,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: matchDateTimeComponents,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      } else {
        debugPrint('[NotificationService] zonedSchedule error: $e');
      }
    }
  }

  /// Programa una notificación de prueba para dentro de [delay] (por defecto 10s)
  /// para verificar que llega incluso con la app completamente cerrada.
  Future<bool> scheduleTestNotificationIn({
    Duration delay = const Duration(seconds: 10),
  }) async {
    await initialize();
    await _initTz();
    final granted = await requestPermissions();
    if (!granted) return false;

    final fireAt = tz.TZDateTime.now(tz.local).add(delay);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_reminder',
        'Recordatorio Diario',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );
    await _plugin.cancel(_testScheduledId);
    await _zonedScheduleSafe(
      id: _testScheduledId,
      title: '✅ WalletAI funcionando en segundo plano',
      body:
          'Si estás leyendo esto con la app cerrada, tus alertas programadas ya están activas.',
      scheduledDate: fireAt,
      details: details,
    );
    return true;
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

    await _zonedScheduleSafe(
      id: _dailyReminderId,
      title: '📝 ¿Registraste tus gastos de hoy?',
      body: 'Mantén tu control financiero al día.',
      scheduledDate: scheduled,
      details: details,
      matchDateTimeComponents: DateTimeComponents.time, // repite diariamente
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

  int _cardBaseNotificationId(String accountId) {
    final positiveHash = accountId.hashCode & 0x7FFFF;
    return 200000 + (positiveHash * 10);
  }

  Future<void> cancelCreditCardAlerts(String accountId) async {
    await initialize();
    final baseId = _cardBaseNotificationId(accountId);
    await _plugin.cancel(baseId + 1);
    await _plugin.cancel(baseId + 2);
    await _plugin.cancel(baseId + 3);
    // Cancelar también el ID usado por versiones anteriores
    await _plugin.cancel(accountId.hashCode + 200);
  }

  Future<void> cancelAllCreditCardAlerts(List<Account> accounts) async {
    for (final account in accounts) {
      if (account.type == 'credit_card') {
        await cancelCreditCardAlerts(account.id);
      }
    }
  }

  String _currencyPrefix(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return 'US\$ ';
      case 'EUR':
        return '€ ';
      default:
        return 'S/ ';
    }
  }

  Future<void> _scheduleCardAlertAt({
    required int id,
    required DateTime targetDay,
    required String title,
    required String body,
  }) async {
    await _initTz();
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = tz.TZDateTime(
      tz.local,
      targetDay.year,
      targetDay.month,
      targetDay.day,
      9,
      0,
    );
    if (!scheduled.isAfter(now)) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'credit_card_alerts',
        'Alertas de Tarjeta',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _zonedScheduleSafe(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      details: details,
    );
  }

  /// Verifica tarjetas de crédito y SOLO notifica o programa recordatorios
  /// cuando existe deuda facturada pendiente al último corte (> S/ 0.01).
  Future<void> checkCreditCardDueDates(
    List<Account> accounts, {
    required TransactionsDao transactionsDao,
    bool forceRefresh = false,
  }) async {
    final enabled = await isCardAlertsEnabled();
    if (!enabled) {
      await cancelAllCreditCardAlerts(accounts);
      return;
    }

    await initialize();
    final daysBefore = await getCardAlertsDaysBefore();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    for (final account in accounts) {
      if (account.type != 'credit_card') continue;

      if (!account.isActive || account.paymentDueDay == null) {
        await cancelCreditCardAlerts(account.id);
        continue;
      }

      final txs = await transactionsDao.getTransactionsByAccount(
        account.id,
        limit: 1000,
      );

      final cycle = CreditCardCalculator.calculateStatementCycle(
        accountId: account.id,
        balance: account.balance,
        creditLimit: account.creditLimit,
        closingDay: account.closingDay,
        paymentDueDay: account.paymentDueDay,
        transactions: txs.map(
          (tx) => (
            date: tx.date,
            accountId: tx.accountId,
            type: tx.type,
            amount: tx.amount,
          ),
        ),
        referenceDate: now,
      );

      // Si no hay deuda facturada pendiente al último corte, limpiar alertas y no recordar
      if (!cycle.hasStatementDebt || cycle.paymentDueDate == null) {
        await cancelCreditCardAlerts(account.id);
        continue;
      }

      final dueDate = DateTime(
        cycle.paymentDueDate!.year,
        cycle.paymentDueDate!.month,
        cycle.paymentDueDate!.day,
      );
      final difference = dueDate.difference(today).inDays;
      final baseId = _cardBaseNotificationId(account.id);
      final amountLabel =
          '${_currencyPrefix(account.currency)}${cycle.statementDebt.toStringAsFixed(2)}';

      // Limpiar alertas programadas previas antes de evaluar/mostrar las actuales
      await cancelCreditCardAlerts(account.id);

      final notifiedPrefKey = 'cc_notified_${account.id}_$todayKey';
      final alreadyNotifiedToday = prefs.getBool(notifiedPrefKey) ?? false;

      if (forceRefresh || !alreadyNotifiedToday) {
        String? title;
        String? body;
        int? immediateId;

        if (difference == 0) {
          immediateId = baseId + 3;
          title = '🚨 Pago de tarjeta HOY';
          body =
              'Hoy vence tu tarjeta ${account.name}. Pendiente del corte: $amountLabel.';
        } else if (difference == 1) {
          immediateId = baseId + 2;
          title = '⚠️ Tarjeta vence mañana';
          body =
              'Mañana vence tu tarjeta ${account.name}. Pendiente del corte: $amountLabel.';
        } else if (difference == daysBefore) {
          immediateId = baseId + 1;
          title = '💳 Tarjeta por vencer';
          body =
              'Faltan $daysBefore días para pagar ${account.name}. Monto del corte: $amountLabel.';
        }

        if (immediateId != null && title != null && body != null) {
          await _show(
            id: immediateId,
            title: title,
            body: body,
            channel: 'credit_card_alerts',
            channelName: 'Alertas de Tarjeta',
          );
          await prefs.setBool(notifiedPrefKey, true);
        }
      }

      // Reprogramar alertas locales futuras mientras exista saldo pendiente al corte
      if (daysBefore > 1) {
        await _scheduleCardAlertAt(
          id: baseId + 1,
          targetDay: dueDate.subtract(Duration(days: daysBefore)),
          title: '💳 Tarjeta por vencer',
          body:
              'Faltan $daysBefore días para pagar ${account.name}. Monto del corte: $amountLabel.',
        );
      }
      await _scheduleCardAlertAt(
        id: baseId + 2,
        targetDay: dueDate.subtract(const Duration(days: 1)),
        title: '⚠️ Tarjeta vence mañana',
        body:
            'Mañana vence tu tarjeta ${account.name}. Pendiente del corte: $amountLabel.',
      );
      await _scheduleCardAlertAt(
        id: baseId + 3,
        targetDay: dueDate,
        title: '🚨 Pago de tarjeta HOY',
        body:
            'Hoy vence tu tarjeta ${account.name}. Pendiente del corte: $amountLabel.',
      );
    }
  }

  /// Notifica cuando se ejecutaron pagos recurrentes automáticos
  Future<void> notifyRecurringExecuted(List<String> executedItems) async {
    if (executedItems.isEmpty) return;
    final body = executedItems.length == 1
        ? 'Se registró automáticamente: ${executedItems.first}'
        : 'Se registraron ${executedItems.length} movimientos automáticos: ${executedItems.take(2).join(', ')}';
    await _show(
      id: _recurringBatchId,
      title: '🔁 Pagos recurrentes aplicados',
      body: body,
      channel: 'recurring_alerts',
      channelName: 'Pagos Recurrentes',
    );
  }

  /// Programa alertas locales futuras para todos los pagos recurrentes activos
  /// (tanto con días de anticipación como la mañana del vencimiento) para que
  /// lleguen incluso si el usuario no abre la app.
  Future<void> scheduleRecurringPaymentReminders(
    List<RecurringPayment> payments,
  ) async {
    await initialize();
    await _initTz();
    final prefs = await SharedPreferences.getInstance();

    // Cancelar recordatorios previos para evitar alertas obsoletas
    final previousIds = prefs.getStringList(_prefRecurringIds) ?? const [];
    for (final rawId in previousIds) {
      final parsed = int.tryParse(rawId);
      if (parsed != null) {
        await _plugin.cancel(parsed);
      }
    }

    final scheduledIds = <String>[];
    final now = tz.TZDateTime.now(tz.local);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'recurring_alerts',
        'Pagos Recurrentes',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    for (final payment in payments) {
      if (!payment.isActive) continue;

      final baseId = 300000 + ((payment.id.hashCode & 0x3FFFF) * 4);
      final dueDay = DateTime(
        payment.nextDueDate.year,
        payment.nextDueDate.month,
        payment.nextDueDate.day,
      );
      final amountLabel = 'S/ ${payment.amount.toStringAsFixed(2)}';

      // 1. Recordatorio anticipado (reminderDays antes, a las 9:00 AM)
      final reminderDays = payment.reminderDays.clamp(0, 14);
      if (reminderDays > 0) {
        final advanceDay = dueDay.subtract(Duration(days: reminderDays));
        final advanceAt = tz.TZDateTime(
          tz.local,
          advanceDay.year,
          advanceDay.month,
          advanceDay.day,
          9,
          0,
        );
        if (advanceAt.isAfter(now)) {
          final id = baseId + 1;
          await _zonedScheduleSafe(
            id: id,
            title: '📅 Pago recurrente próximo',
            body:
                '${payment.name} ($amountLabel) vence en $reminderDays ${reminderDays == 1 ? 'día' : 'días'}.',
            scheduledDate: advanceAt,
            details: details,
          );
          scheduledIds.add(id.toString());
        }
      }

      // 2. Recordatorio el mismo día del vencimiento (9:00 AM)
      final dueAt = tz.TZDateTime(
        tz.local,
        dueDay.year,
        dueDay.month,
        dueDay.day,
        9,
        0,
      );
      if (dueAt.isAfter(now)) {
        final id = baseId + 2;
        await _zonedScheduleSafe(
          id: id,
          title: '🔁 Pago recurrente HOY',
          body: 'Hoy toca ${payment.name} ($amountLabel).',
          scheduledDate: dueAt,
          details: details,
        );
        scheduledIds.add(id.toString());
      }
    }

    await prefs.setStringList(_prefRecurringIds, scheduledIds);
  }
}
