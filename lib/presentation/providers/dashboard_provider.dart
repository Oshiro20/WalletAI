import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ─── Modelo de Widget del Dashboard ───────────────────────────────────────────

enum DashboardWidgetType {
  balanceSummary, // Balance total + ingresos + gastos
  recentTransactions, // Últimas transacciones
  categoryBreakdown, // Torta de categorías
  budgetProgress, // Progreso de presupuestos
  savingsGoals, // Metas de ahorro
  recurringPayments, // Próximos pagos recurrentes
  monthlyTrend, // Gráfico de tendencia mensual
  quickActions, // Acciones rápidas
  monthProjection, // Proyección financiera del mes
  monthComparison, // Comparación este mes vs mes anterior
  budgetRule, // Regla 50/30/20
}

class DashboardWidgetConfig {
  final DashboardWidgetType type;
  final bool visible;
  final int order;

  const DashboardWidgetConfig({
    required this.type,
    required this.visible,
    required this.order,
  });

  DashboardWidgetConfig copyWith({bool? visible, int? order}) {
    return DashboardWidgetConfig(
      type: type,
      visible: visible ?? this.visible,
      order: order ?? this.order,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'visible': visible,
    'order': order,
  };

  factory DashboardWidgetConfig.fromJson(Map<String, dynamic> json) {
    return DashboardWidgetConfig(
      type: DashboardWidgetType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => DashboardWidgetType.balanceSummary,
      ),
      visible: json['visible'] as bool,
      order: json['order'] as int,
    );
  }

  String get label {
    switch (type) {
      case DashboardWidgetType.balanceSummary:
        return 'Resumen de Balance';
      case DashboardWidgetType.recentTransactions:
        return 'Transacciones Recientes';
      case DashboardWidgetType.categoryBreakdown:
        return 'Distribución por Categoría';
      case DashboardWidgetType.budgetProgress:
        return 'Progreso de Presupuestos';
      case DashboardWidgetType.savingsGoals:
        return 'Metas de Ahorro';
      case DashboardWidgetType.recurringPayments:
        return 'Próximos Pagos';
      case DashboardWidgetType.monthlyTrend:
        return 'Tendencia Mensual';
      case DashboardWidgetType.quickActions:
        return 'Acciones Rápidas';
      case DashboardWidgetType.monthProjection:
        return 'Proyección del Mes';
      case DashboardWidgetType.monthComparison:
        return 'Comparación Mensual';
      case DashboardWidgetType.budgetRule:
        return 'Regla 50/30/20';
    }
  }

  IconData get icon {
    switch (type) {
      case DashboardWidgetType.balanceSummary:
        return Icons.account_balance_wallet;
      case DashboardWidgetType.recentTransactions:
        return Icons.receipt_long;
      case DashboardWidgetType.categoryBreakdown:
        return Icons.pie_chart;
      case DashboardWidgetType.budgetProgress:
        return Icons.savings;
      case DashboardWidgetType.savingsGoals:
        return Icons.flag;
      case DashboardWidgetType.recurringPayments:
        return Icons.loop;
      case DashboardWidgetType.monthlyTrend:
        return Icons.show_chart;
      case DashboardWidgetType.quickActions:
        return Icons.grid_view;
      case DashboardWidgetType.monthProjection:
        return Icons.trending_up;
      case DashboardWidgetType.monthComparison:
        return Icons.compare_arrows;
      case DashboardWidgetType.budgetRule:
        return Icons.pie_chart;
    }
  }
}

// ─── Estado ───────────────────────────────────────────────────────────────────

const _prefsKey = 'dashboard_layout_v1';

/// Configuración por defecto del dashboard
List<DashboardWidgetConfig> _defaultLayout() {
  final types = DashboardWidgetType.values;
  return List.generate(types.length, (i) {
    return DashboardWidgetConfig(type: types[i], visible: true, order: i);
  });
}

// ─── Provider ──────────────────────────────────────────────────────────────────

class DashboardLayoutNotifier extends Notifier<List<DashboardWidgetConfig>> {
  @override
  List<DashboardWidgetConfig> build() {
    // Carga inicial desde SharedPreferences (asíncrono, pero arranca con default)
    _loadLayout();
    return _defaultLayout();
  }

  Future<void> _loadLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => DashboardWidgetConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      // Merge: si hay tipos nuevos que no están en prefs, agregalos al final
      final existing = {for (final w in list) w.type: w};
      final merged = DashboardWidgetType.values.map((t) {
        return existing[t] ??
            DashboardWidgetConfig(type: t, visible: true, order: list.length);
      }).toList();
      merged.sort((a, b) => a.order.compareTo(b.order));
      state = merged;
    } catch (_) {
      // Corrupción → volver a default
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(state.map((e) => e.toJson()).toList()),
    );
  }

  void toggleVisibility(DashboardWidgetType type) {
    state = state.map((w) {
      if (w.type == type) return w.copyWith(visible: !w.visible);
      return w;
    }).toList();
    _save();
  }

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = List.generate(list.length, (i) => list[i].copyWith(order: i));
    _save();
  }

  void resetToDefault() {
    state = _defaultLayout();
    _save();
  }
}

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, List<DashboardWidgetConfig>>(
      DashboardLayoutNotifier.new,
    );

/// Solo los widgets visibles, en orden
final visibleDashboardWidgetsProvider = Provider<List<DashboardWidgetConfig>>((
  ref,
) {
  final all = ref.watch(dashboardLayoutProvider);
  return all.where((w) => w.visible).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
});
