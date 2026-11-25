import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/notification_service.dart';
import '../../providers/database_providers.dart';

class NotificationsSettingsScreen extends ConsumerStatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  ConsumerState<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends ConsumerState<NotificationsSettingsScreen>
    with WidgetsBindingObserver {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _cardAlertsEnabled = true;
  int _cardAlertsDaysBefore = 3;
  bool _notificationsGranted = true;
  bool _exactAlarmsGranted = true;
  bool _batteryUnrestricted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionStatus();
    }
  }

  Future<void> _refreshPermissionStatus() async {
    final notifEnabled = await NotificationService().areNotificationsEnabled();
    final exactEnabled = await NotificationService().canScheduleExactAlarms();
    final batteryOk = await NotificationService()
        .isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _notificationsGranted = notifEnabled;
      _exactAlarmsGranted = exactEnabled;
      _batteryUnrestricted = batteryOk;
    });
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final cardEnabled = await NotificationService().isCardAlertsEnabled();
    final cardDays = await NotificationService().getCardAlertsDaysBefore();
    final notifEnabled = await NotificationService().areNotificationsEnabled();
    final exactEnabled = await NotificationService().canScheduleExactAlarms();
    final batteryOk = await NotificationService()
        .isIgnoringBatteryOptimizations();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool('daily_reminder_enabled') ?? false;
      final h = prefs.getInt('daily_reminder_hour') ?? 20;
      final m = prefs.getInt('daily_reminder_min') ?? 0;
      _time = TimeOfDay(hour: h, minute: m);
      _cardAlertsEnabled = cardEnabled;
      _cardAlertsDaysBefore = cardDays;
      _notificationsGranted = notifEnabled;
      _exactAlarmsGranted = exactEnabled;
      _batteryUnrestricted = batteryOk;
      _loading = false;
    });
  }

  Future<void> _requestExactAlarms() async {
    await NotificationService().requestExactAlarmPermission();
    await _refreshPermissionStatus();
    if (_exactAlarmsGranted && _enabled) {
      await NotificationService().scheduleDailyReminder(
        hour: _time.hour,
        minute: _time.minute,
      );
    }
  }

  Future<void> _scheduleTestIn10s() async {
    final ok = await NotificationService().scheduleTestNotificationIn(
      delay: const Duration(seconds: 10),
    );
    await _refreshPermissionStatus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? '⏱️ Prueba programada en 10 segundos. Cierra WalletAI ahora para comprobar que llega en segundo plano.'
              : '⚠️ Activa el permiso de notificaciones en Android para recibir alertas.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _toggleCardAlerts(bool value) async {
    setState(() => _cardAlertsEnabled = value);
    await NotificationService().setCardAlertsEnabled(value);
    final accounts = await ref.read(accountsDaoProvider).getAllAccounts();
    await NotificationService().checkCreditCardDueDates(
      accounts,
      transactionsDao: ref.read(transactionsDaoProvider),
      forceRefresh: false,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '💳 Alertas de tarjetas activadas (solo si hay deuda al corte)'
                : '🔕 Alertas de vencimiento de tarjetas desactivadas',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changeCardDaysBefore(int days) async {
    setState(() => _cardAlertsDaysBefore = days);
    await NotificationService().setCardAlertsDaysBefore(days);
    final accounts = await ref.read(accountsDaoProvider).getAllAccounts();
    await NotificationService().checkCreditCardDueDates(
      accounts,
      transactionsDao: ref.read(transactionsDaoProvider),
      forceRefresh: false,
    );
  }

  Future<void> _toggleReminder(bool value) async {
    setState(() => _enabled = value);
    if (value) {
      await NotificationService().scheduleDailyReminder(
        hour: _time.hour,
        minute: _time.minute,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Recordatorio programado a las ${_time.format(context)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await NotificationService().cancelDailyReminder();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
    if (_enabled) {
      await NotificationService().scheduleDailyReminder(
        hour: picked.hour,
        minute: picked.minute,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🔔 Recordatorio actualizado a las ${picked.format(context)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ─── Estado en segundo plano ─────────────────────────────
                _SectionHeader(title: 'Entrega en segundo plano'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Card(
                    elevation: 0,
                    color: cs.surfaceContainerHighest.withAlpha(110),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _notificationsGranted
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: _notificationsGranted
                                    ? Colors.green
                                    : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _notificationsGranted
                                      ? 'Permiso de notificaciones activo'
                                      : 'Falta permiso de notificaciones',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              if (!_notificationsGranted)
                                TextButton(
                                  onPressed: () async {
                                    await NotificationService()
                                        .requestPermissions();
                                    await _refreshPermissionStatus();
                                  },
                                  child: const Text('Activar'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _exactAlarmsGranted
                                    ? Icons.alarm_on
                                    : Icons.alarm_off,
                                color: _exactAlarmsGranted
                                    ? Colors.green
                                    : Colors.amber.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _exactAlarmsGranted
                                      ? 'Alarmas exactas activas (puntuales con app cerrada)'
                                      : 'Alarmas exactas desactivadas (pueden retrasarse)',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              if (!_exactAlarmsGranted)
                                TextButton(
                                  onPressed: _requestExactAlarms,
                                  child: const Text('Permitir'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                _batteryUnrestricted
                                    ? Icons.battery_charging_full
                                    : Icons.battery_alert,
                                color: _batteryUnrestricted
                                    ? Colors.green
                                    : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _batteryUnrestricted
                                      ? 'Segundo plano sin restricciones activo'
                                      : 'Segundo plano restringido por batería',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                              if (!_batteryUnrestricted)
                                TextButton(
                                  onPressed: () async {
                                    await NotificationService()
                                        .requestIgnoreBatteryOptimizations();
                                    await _refreshPermissionStatus();
                                  },
                                  child: const Text('Activar'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Si usas Xiaomi/Honor/Oppo, toca "Ajustes Android" y activa Inicio automático para que el sistema no mate las alarmas al cerrar recientes.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurface.withAlpha(150),
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _scheduleTestIn10s,
                                  icon: const Icon(
                                    Icons.timer_outlined,
                                    size: 18,
                                  ),
                                  label: const Text('Probar en 10s'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    NotificationService().openAppSettings(),
                                icon: const Icon(
                                  Icons.settings_outlined,
                                  size: 18,
                                ),
                                label: const Text('Ajustes'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ─── Recordatorio diario ────────────────────────────────
                _SectionHeader(title: 'Recordatorio diario'),
                SwitchListTile(
                  value: _enabled,
                  onChanged: _toggleReminder,
                  title: const Text('Recordatorio de registro'),
                  subtitle: const Text(
                    'Te recuerda registrar tus gastos cada día',
                  ),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: cs.primary,
                      size: 22,
                    ),
                  ),
                ),
                if (_enabled) ...[
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.access_time,
                        color: cs.tertiary,
                        size: 22,
                      ),
                    ),
                    title: const Text('Hora del recordatorio'),
                    subtitle: Text(
                      _time.format(context),
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickTime,
                  ),
                ],
                const Divider(),

                // ─── Tarjetas de crédito ────────────────────────────────
                _SectionHeader(title: 'Tarjetas de crédito'),
                SwitchListTile(
                  value: _cardAlertsEnabled,
                  onChanged: _toggleCardAlerts,
                  title: const Text('Recordatorio de pago de tarjeta'),
                  subtitle: const Text(
                    'Solo te avisa cuando hay saldo pendiente de tu último corte',
                  ),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.credit_card_outlined,
                      color: cs.secondary,
                      size: 22,
                    ),
                  ),
                ),
                if (_cardAlertsEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      children: [1, 3, 5].map((days) {
                        final selected = _cardAlertsDaysBefore == days;
                        return ChoiceChip(
                          label: Text(
                            days == 1 ? '1 día antes' : '$days días antes',
                          ),
                          selected: selected,
                          onSelected: (_) => _changeCardDaysBefore(days),
                        );
                      }).toList(),
                    ),
                  ),
                const Divider(),

                // ─── Info ────────────────────────────────────────────────
                _SectionHeader(title: 'Alertas automáticas'),
                _InfoTile(
                  icon: Icons.savings,
                  iconColor: Colors.orange,
                  title: 'Alertas de presupuesto',
                  subtitle: 'Se activan al llegar al 80% y 100% del límite',
                ),
                _InfoTile(
                  icon: Icons.warning_amber,
                  iconColor: Colors.red,
                  title: 'Gasto inusualmente alto',
                  subtitle:
                      'Se activa cuando un gasto supera 3× tu promedio diario',
                ),
                _InfoTile(
                  icon: Icons.repeat,
                  iconColor: Colors.blue,
                  title: 'Pagos recurrentes programados',
                  subtitle:
                      'Te avisa con anticipación y el día de cobro incluso con la app cerrada',
                ),
                _InfoTile(
                  icon: Icons.flag_outlined,
                  iconColor: Colors.green,
                  title: 'Metas de ahorro',
                  subtitle: 'Te notifica al completar una meta',
                ),

                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Las alertas automáticas funcionan sin configuración adicional.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withAlpha(120),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }
}
