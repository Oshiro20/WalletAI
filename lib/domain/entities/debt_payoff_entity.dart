/// Entidad de dominio para Estrategia de Liquidación de Deudas
/// Implementa matemáticas de Avalanche (TEA alta primero) y Snowball (saldo bajo primero)
class DebtPayoffEntity {
  final List<DebtAccount> debts;
  final double totalDebt;
  final double totalMinimumPayments;
  final double extraPayment;
  final DebtStrategy strategy;
  final DateTime calculatedAt;

  DebtPayoffEntity({
    required this.debts,
    required this.extraPayment,
    this.strategy = DebtStrategy.avalanche,
    DateTime? calculatedAt,
  }) : totalDebt = debts.fold(0, (sum, d) => sum + d.balance),
       totalMinimumPayments = debts.fold(0, (sum, d) => sum + d.minimumPayment),
       calculatedAt = calculatedAt ?? DateTime.now();

  /// Plan de pago ordenado según la estrategia
  List<DebtAccount> get orderedDebts {
    final sorted = [...debts];
    switch (strategy) {
      case DebtStrategy.avalanche:
        sorted.sort(
          (a, b) => b.annualInterestRate.compareTo(a.annualInterestRate),
        );
        break;
      case DebtStrategy.snowball:
        sorted.sort((a, b) => a.balance.compareTo(b.balance));
        break;
    }
    return sorted;
  }

  /// Meses estimados para liquidar toda la deuda
  int get estimatedMonthsToPayoff {
    if (totalDebt == 0) return 0;
    final totalMonthlyPayment = totalMinimumPayments + extraPayment;
    if (totalMonthlyPayment <= 0) return 999;

    // Cálculo simplificado con interés compuesto
    double remaining = totalDebt;
    int months = 0;

    while (remaining > 0 && months < 600) {
      double interestThisMonth = 0;
      for (final debt in debts) {
        if (debt.balance > 0) {
          interestThisMonth += debt.balance * debt.monthlyInterestRate;
        }
      }
      remaining = remaining + interestThisMonth - totalMonthlyPayment;
      months++;
      if (remaining <= 0) break;
    }
    return months;
  }

  /// Intereses totales estimados a pagar
  double get estimatedTotalInterest {
    if (totalDebt == 0) return 0;
    final totalMonthlyPayment = totalMinimumPayments + extraPayment;
    if (totalMonthlyPayment <= totalMinimumPayments) {
      // Solo pagos mínimos: estimación basada en promedio ponderado de TEA
      final avgRate =
          debts.fold(0.0, (sum, d) => sum + d.annualInterestRate * d.balance) /
          (totalDebt > 0 ? totalDebt : 1);
      return totalDebt * avgRate * (estimatedMonthsToPayoff / 12);
    }
    return (totalMonthlyPayment * estimatedMonthsToPayoff) - totalDebt;
  }

  /// Total a pagar (deuda + intereses)
  double get totalCost => totalDebt + estimatedTotalInterest;

  /// Fecha estimada de liberación de deuda
  DateTime get estimatedDebtFreeDate => DateTime.now().add(
    Duration(days: (estimatedMonthsToPayoff * 30.44).toInt()),
  );

  /// Ahorro comparado con la otra estrategia
  double get savingsVsOtherStrategy {
    if (debts.length < 2) return 0;

    final thisCost = _calculateCost(strategy);
    final otherStrategy = strategy == DebtStrategy.avalanche
        ? DebtStrategy.snowball
        : DebtStrategy.avalanche;
    final otherCost = _calculateCost(otherStrategy);

    return (otherCost - thisCost).clamp(0, double.infinity);
  }

  double _calculateCost(DebtStrategy strat) {
    final ordered = [...debts];
    switch (strat) {
      case DebtStrategy.avalanche:
        ordered.sort(
          (a, b) => b.annualInterestRate.compareTo(a.annualInterestRate),
        );
        break;
      case DebtStrategy.snowball:
        ordered.sort((a, b) => a.balance.compareTo(b.balance));
        break;
    }

    double totalInterest = 0;
    final balances = ordered.map((d) => d.balance).toList();
    final rates = ordered.map((d) => d.monthlyInterestRate).toList();
    final mins = ordered.map((d) => d.minimumPayment).toList();
    int months = 0;

    while (balances.any((b) => b > 0) && months < 600) {
      double available = extraPayment;
      for (int i = 0; i < ordered.length; i++) {
        if (balances[i] > 0) {
          final interest = balances[i] * rates[i];
          totalInterest += interest;
          balances[i] += interest;

          final payment = mins[i] + (i == 0 ? available : 0);
          final actualPayment = balances[i] < payment ? balances[i] : payment;
          balances[i] -= actualPayment;
          if (i > 0) {
            available += (mins[i] - actualPayment).clamp(0, double.infinity);
          }
        }
      }
      months++;
    }
    return totalInterest;
  }
}

enum DebtStrategy { avalanche, snowball }

/// Cuenta de deuda individual
class DebtAccount {
  final String id;
  final String name;
  final String? institution;
  final double balance;
  final double annualInterestRate; // TEA
  final double minimumPayment;
  final double? creditLimit;
  final DateTime? dueDate;

  const DebtAccount({
    required this.id,
    required this.name,
    this.institution,
    required this.balance,
    required this.annualInterestRate,
    required this.minimumPayment,
    this.creditLimit,
    this.dueDate,
  });

  /// Tasa de interés mensual
  double get monthlyInterestRate => annualInterestRate / 12;

  /// Porcentaje de límite utilizado
  double get creditUtilization => creditLimit != null && creditLimit! > 0
      ? balance / creditLimit! * 100
      : 0;

  bool get isOverutilized => creditUtilization > 80;

  /// Costo mensual de intereses
  double get monthlyInterestCost => balance * monthlyInterestRate;

  /// Meses para pagar solo con pago mínimo
  int get monthsToPayoffMinimum {
    if (balance == 0 || minimumPayment == 0) return 0;
    if (minimumPayment <= balance * monthlyInterestRate) {
      return 999; // Nunca se paga
    }
    return (balance / (minimumPayment - balance * monthlyInterestRate)).ceil();
  }
}
