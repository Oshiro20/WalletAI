import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/datasources/notification_service.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('daily_reminder_enabled') ?? false;
      final h = prefs.getInt('daily_reminder_hour') ?? 20;
      final m = prefs.getInt('daily_reminder_min') ?? 0;
      _time = TimeOfDay(hour: h, minute: m);
      _loading = false;
    });
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
                '✅ Recordatorio programado a las ${_time.format(context)}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await NotificationService().cancelDailyReminder();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
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
            content: Text('🔔 Recordatorio actualizado a las ${picked.format(context)}'),
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
                // ─── Recordatorio diario ────────────────────────────────
                _SectionHeader(title: 'Recordatorio diario'),
                SwitchListTile(
                  value: _enabled,
                  onChanged: _toggleReminder,
                  title: const Text('Recordatorio de registro'),
                  subtitle: const Text(
                      'Te recuerda registrar tus gastos cada día'),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.notifications_outlined,
                        color: cs.primary, size: 22),
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
                      child: Icon(Icons.access_time,
                          color: cs.tertiary, size: 22),
                    ),
                    title: const Text('Hora del recordatorio'),
                    subtitle: Text(
                      _time.format(context),
                      style: TextStyle(
                          color: cs.primary, fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickTime,
                  ),
                ],
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
                  subtitle: 'Se activa cuando un gasto supera 3× tu promedio diario',
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
