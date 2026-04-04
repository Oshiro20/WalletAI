import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_providers.dart';

/// Modelo de proyección financiera del mes
class MonthProjection {
  final double spentSoFar;
  final double projectedTotal;
  final double currentIncome;
  final double projectedBalance;
  final double dailyAverage;
  final int daysElapsed;
  final int daysInMonth;

  const MonthProjection({
    required this.spentSoFar,
    required this.projectedTotal,
    required this.currentIncome,
    required this.projectedBalance,
    required this.dailyAverage,
    required this.daysElapsed,
    required this.daysInMonth,
  });

  double get progressPercent => daysInMonth > 0 ? daysElapsed / daysInMonth : 0;

  /// Estado de salud financiera: 0 = saludable, 1 = advertencia, 2 = crítico
  int get healthStatus {
    if (currentIncome <= 0) return 0;
    final ratio = projectedTotal / currentIncome;
    if (ratio < 0.8) return 0;
    if (ratio < 1.0) return 1;
    return 2;
  }
}

/// Provider que calcula la proyección financiera del mes actual
final monthProjectionProvider = FutureProvider<MonthProjection>((ref) async {
  final txDao = ref.watch(transactionsDaoProvider);

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
  final today = DateTime(now.year, now.month, now.day, 23, 59, 59);

  // Datos reales hasta hoy
  final spentSoFar = await txDao.getTotalExpenses(startOfMonth, today);
  final currentIncome = await txDao.getTotalIncome(startOfMonth, endOfMonth);

  // Días
  final daysElapsed = now.day;
  final daysInMonth = endOfMonth.day;
  final daysRemaining = daysInMonth - daysElapsed;

  // Promedio diario real y proyección al fin de mes
  final dailyAverage = daysElapsed > 0 ? spentSoFar / daysElapsed : 0.0;
  final projectedTotal = spentSoFar + (dailyAverage * daysRemaining);
  final projectedBalance = currentIncome - projectedTotal;

  return MonthProjection(
    spentSoFar: spentSoFar,
    projectedTotal: projectedTotal,
    currentIncome: currentIncome,
    projectedBalance: projectedBalance,
    dailyAverage: dailyAverage,
    daysElapsed: daysElapsed,
    daysInMonth: daysInMonth,
  );
});
