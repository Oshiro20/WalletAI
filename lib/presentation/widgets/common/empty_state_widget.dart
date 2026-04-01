import 'package:flutter/material.dart';

/// Widget reutilizable para estados vacíos con animación suave.
/// Usar en cualquier lista o pantalla sin datos.
class EmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  // ─── Factory constructors para pantallas específicas ──────────────────────

  factory EmptyStateWidget.transactions({VoidCallback? onCreate}) =>
      EmptyStateWidget(
        icon: Icons.receipt_long,
        title: 'Sin transacciones',
        subtitle: 'Registra tus ingresos y gastos para\nver tu historial aquí.',
        actionLabel: 'Nueva transacción',
        onAction: onCreate,
        iconColor: Colors.blue,
      );

  factory EmptyStateWidget.categories({VoidCallback? onCreate}) =>
      EmptyStateWidget(
        icon: Icons.category,
        title: 'Sin categorías',
        subtitle: 'Crea categorías para organizar\ntus ingresos y gastos.',
        actionLabel: 'Nueva categoría',
        onAction: onCreate,
        iconColor: Colors.purple,
      );

  factory EmptyStateWidget.budgets({VoidCallback? onCreate}) =>
      EmptyStateWidget(
        icon: Icons.savings,
        title: 'Sin presupuestos',
        subtitle: 'Define límites de gasto por categoría\npara mantener el control.',
        actionLabel: 'Nuevo presupuesto',
        onAction: onCreate,
        iconColor: Colors.orange,
      );

  factory EmptyStateWidget.goals({VoidCallback? onCreate}) =>
      EmptyStateWidget(
        icon: Icons.flag,
        title: 'Sin metas de ahorro',
        subtitle: 'Establece objetivos financieros y\nsigue tu progreso mes a mes.',
        actionLabel: 'Nueva meta',
        onAction: onCreate,
        iconColor: Colors.green,
      );

  factory EmptyStateWidget.search() => const EmptyStateWidget(
        icon: Icons.search_off,
        title: 'Sin resultados',
        subtitle: 'Prueba con otro término\no revisa los filtros aplicados.',
        iconColor: Colors.grey,
      );

  factory EmptyStateWidget.recurring({VoidCallback? onCreate}) =>
      EmptyStateWidget(
        icon: Icons.loop,
        title: 'Sin pagos recurrentes',
        subtitle: 'Registra suscripciones, alquileres u\notros pagos que se repiten.',
        actionLabel: 'Nuevo pago',
        onAction: onCreate,
        iconColor: Colors.teal,
      );

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = widget.iconColor ?? theme.colorScheme.primary;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Ícono con fondo circular
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 48, color: iconColor),
                ),
              ),
              const SizedBox(height: 24),

              // Título
              Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),

              // Subtítulo
              Text(
                widget.subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(153),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              // Botón de acción (opcional)
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: widget.onAction,
                  icon: const Icon(Icons.add),
                  label: Text(widget.actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
