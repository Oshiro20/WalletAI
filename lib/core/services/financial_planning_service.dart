import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/drift_database.dart';

/// Presets configurables para la regla de distribución del presupuesto mensual.
enum BudgetRulePreset {
  balanced503020(50, 30, 20, '50/30/20', 'Equilibrada'),
  highFixed602020(60, 20, 20, '60/20/20', 'Gastos fijos altos'),
  aggressiveSave502030(50, 20, 30, '50/20/30', 'Ahorro agresivo'),
  starter702010(70, 20, 10, '70/20/10', 'Ajuste inicial');

  final int needsPct;
  final int wantsPct;
  final int savingsPct;
  final String label;
  final String subtitle;

  const BudgetRulePreset(
    this.needsPct,
    this.wantsPct,
    this.savingsPct,
    this.label,
    this.subtitle,
  );

  static BudgetRulePreset fromName(String? raw) {
    for (final p in BudgetRulePreset.values) {
      if (p.name == raw) return p;
    }
    return BudgetRulePreset.balanced503020;
  }
}

/// Plan mensual calculado automáticamente para una Meta de Ahorro.
class SavingsGoalPlan {
  final double remainingAmount;
  final int? monthsRemaining;
  final double? suggestedMonthlyAmount;
  final double? suggestedWeeklyAmount;
  final double contributedThisMonth;

  const SavingsGoalPlan({
    required this.remainingAmount,
    this.monthsRemaining,
    this.suggestedMonthlyAmount,
    this.suggestedWeeklyAmount,
    this.contributedThisMonth = 0,
  });

  double get remainingThisMonth => suggestedMonthlyAmount == null
      ? 0.0
      : (suggestedMonthlyAmount! - contributedThisMonth).clamp(
          0.0,
          double.infinity,
        );

  bool get isOnTrackThisMonth =>
      suggestedMonthlyAmount == null ||
      contributedThisMonth + 0.01 >= suggestedMonthlyAmount!;
}

/// Motor de planificación financiera personal:
/// 1) Ingresos de fin de mes asignados al presupuesto del mes siguiente.
/// 2) Plan mensual sugerido para Metas de Ahorro.
/// 3) Detección de transferencias reales hacia ahorro/inversión.
/// 4) Regla de distribución personalizable (50/30/20, 60/20/20, etc.).
class FinancialPlanningService {
  static const incomeOverridesKey = 'walletai_income_month_overrides_v1';
  static const budgetRulePresetKey = 'walletai_budget_rule_preset_v1';

  /// Formatea un mes contable como `YYYY-MM`.
  static String formatYearMonth(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  /// Devuelve el mes siguiente a [date] y su etiqueta legible en español.
  static ({int year, int month, String key, String label}) nextMonthOf(
    DateTime date,
  ) {
    final nextYear = date.month == 12 ? date.year + 1 : date.year;
    final nextMonth = date.month == 12 ? 1 : date.month + 1;
    final key = formatYearMonth(nextYear, nextMonth);
    const monthsEs = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return (
      year: nextYear,
      month: nextMonth,
      key: key,
      label: '${monthsEs[nextMonth - 1]} $nextYear',
    );
  }

  /// Indica si conviene destacar la opción de "contar para el próximo mes" (días 25..31).
  static bool isEndOfMonthPayWindow(DateTime date) => date.day >= 25;

  /// Devuelve año y mes contables efectivos de una transacción.
  /// Para ingresos con override, devuelve el mes asignado; para gastos/transferencias, su fecha real.
  static ({int year, int month}) effectiveYearMonth(
    Transaction tx,
    Map<String, String> incomeOverrides,
  ) {
    if (tx.type == 'income') {
      final raw = incomeOverrides[tx.id];
      if (raw != null && raw.contains('-')) {
        final parts = raw.split('-');
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (y != null && m != null && m >= 1 && m <= 12) {
          return (year: y, month: m);
        }
      }
    }
    return (year: tx.date.year, month: tx.date.month);
  }

  /// Verifica si [tx] corresponde al mes contable ([year], [month]).
  static bool belongsToBudgetMonth(
    Transaction tx,
    int year,
    int month,
    Map<String, String> incomeOverrides,
  ) {
    final ym = effectiveYearMonth(tx, incomeOverrides);
    return ym.year == year && ym.month == month;
  }

  /// Etiqueta corta de mes contable asignado si un ingreso cuenta en otro mes (ej. "→ Dic").
  static String? overrideShortBadge(
    String txId,
    Map<String, String> incomeOverrides,
  ) {
    final raw = incomeOverrides[txId];
    if (raw == null || !raw.contains('-')) return null;
    final parts = raw.split('-');
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) return null;
    final short = DateFormat('MMM', 'es').format(DateTime(y, m, 1));
    final cap = short.isEmpty
        ? short
        : '${short[0].toUpperCase()}${short.substring(1)}';
    return '→ Cuenta en $cap';
  }

  /// Identifica si una transferencia corresponde a ahorro/inversión real del usuario.
  static bool isSavingsTransfer(
    Transaction tx, {
    Set<String> savingsAccountIds = const {},
  }) {
    if (tx.type != 'transfer') return false;
    if (tx.destinationAccountId != null &&
        savingsAccountIds.contains(tx.destinationAccountId)) {
      return true;
    }
    final text = '${tx.productName ?? ''} ${tx.description ?? ''}'
        .toLowerCase();
    return text.contains('ahorro:') || text.contains('meta de ahorro');
  }

  /// Calcula el plan de aporte mensual/semanal sugerido para alcanzar una Meta de Ahorro.
  static SavingsGoalPlan computeGoalPlan(
    SavingsGoal goal, {
    DateTime? now,
    double contributedThisMonth = 0,
  }) {
    final refNow = now ?? DateTime.now();
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(
      0.0,
      double.infinity,
    );
    if (goal.isCompleted || remaining <= 0) {
      return SavingsGoalPlan(
        remainingAmount: 0,
        monthsRemaining: 0,
        suggestedMonthlyAmount: 0,
        suggestedWeeklyAmount: 0,
        contributedThisMonth: contributedThisMonth,
      );
    }

    if (goal.deadline == null) {
      return SavingsGoalPlan(
        remainingAmount: remaining,
        contributedThisMonth: contributedThisMonth,
      );
    }

    final dl = goal.deadline!;
    final monthDiff = (dl.year - refNow.year) * 12 + (dl.month - refNow.month);
    final months = (monthDiff + (dl.day >= refNow.day ? 1 : 0)).clamp(1, 120);
    final monthly = remaining / months;
    final weekly = monthly / 4.33;

    return SavingsGoalPlan(
      remainingAmount: remaining,
      monthsRemaining: months,
      suggestedMonthlyAmount: double.parse(monthly.toStringAsFixed(2)),
      suggestedWeeklyAmount: double.parse(weekly.toStringAsFixed(2)),
      contributedThisMonth: contributedThisMonth,
    );
  }

  /// Suma el ahorro mensual sugerido de todas las metas activas con fecha límite.
  static double totalSuggestedMonthlySavings(
    List<SavingsGoal> goals, {
    DateTime? now,
  }) {
    double total = 0;
    for (final g in goals) {
      if (g.isCompleted) continue;
      final plan = computeGoalPlan(g, now: now);
      if (plan.suggestedMonthlyAmount != null &&
          plan.suggestedMonthlyAmount! > 0) {
        total += plan.suggestedMonthlyAmount!;
      }
    }
    return double.parse(total.toStringAsFixed(2));
  }

  // ── Persistencia en SharedPreferences ───────────────────────────────────────

  static Future<Map<String, String>> loadIncomeOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(incomeOverridesKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {}
    return {};
  }

  static Future<void> saveIncomeOverrides(Map<String, String> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(incomeOverridesKey, jsonEncode(map));
    } catch (_) {}
  }

  static Future<BudgetRulePreset> loadBudgetRulePreset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return BudgetRulePreset.fromName(prefs.getString(budgetRulePresetKey));
    } catch (_) {
      return BudgetRulePreset.balanced503020;
    }
  }

  static Future<void> saveBudgetRulePreset(BudgetRulePreset preset) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(budgetRulePresetKey, preset.name);
    } catch (_) {}
  }
}
