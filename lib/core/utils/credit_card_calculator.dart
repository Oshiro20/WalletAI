import 'dart:math' as math;

/// Resultado de la simulación de financiamiento en cuotas
class InstallmentPlanCalculation {
  final double principal; // Monto financiado
  final int installments; // Número de cuotas
  final double tea; // Tasa Efectiva Anual (%)
  final double tem; // Tasa Efectiva Mensual (%)
  final double monthlyPayment; // Cuota fija mensual
  final double totalInterest; // Total de intereses
  final double totalToPay; // Total a pagar (Capital + Intereses)
  final bool hasInterest;
  final DateTime firstDueDate; // Fecha de vencimiento de la primera cuota
  final List<InstallmentItem> schedule; // Cronograma detallado

  const InstallmentPlanCalculation({
    required this.principal,
    required this.installments,
    required this.tea,
    required this.tem,
    required this.monthlyPayment,
    required this.totalInterest,
    required this.totalToPay,
    required this.hasInterest,
    required this.firstDueDate,
    required this.schedule,
  });
}

/// Detalle de una cuota individual en el cronograma
class InstallmentItem {
  final int number; // Número de cuota (1 a N)
  final DateTime dueDate; // Fecha de pago
  final double payment; // Monto de la cuota
  final double principalPortion; // Amortización del capital
  final double interestPortion; // Interés de esta cuota
  final double remainingBalance; // Saldo restante por pagar

  const InstallmentItem({
    required this.number,
    required this.dueDate,
    required this.payment,
    required this.principalPortion,
    required this.interestPortion,
    required this.remainingBalance,
  });
}

/// Utilidad matemática y financiera para tarjetas de crédito
class CreditCardCalculator {
  /// Convierte una Tasa Efectiva Anual (TEA %) a Tasa Efectiva Mensual (TEM %)
  /// Fórmula: TEM = ((1 + TEA)^(1/12)) - 1
  static double teaToTem(double teaPercent) {
    if (teaPercent <= 0) return 0.0;
    final teaDecimal = teaPercent / 100.0;
    final temDecimal = math.pow(1.0 + teaDecimal, 1.0 / 12.0) - 1.0;
    return temDecimal.toDouble() * 100.0;
  }

  /// Calcula el plan de cuotas completo (Sistema Francés)
  static InstallmentPlanCalculation calculatePlan({
    required double principal,
    required int installments,
    required double tea,
    required bool hasInterest,
    required DateTime purchaseDate,
    int? closingDay,
    int? paymentDueDay,
  }) {
    if (installments < 1) installments = 1;
    final effectiveTea = hasInterest ? math.max(0.0, tea) : 0.0;
    final temPercent = hasInterest ? teaToTem(effectiveTea) : 0.0;
    final temDecimal = temPercent / 100.0;

    double monthlyPayment;
    double totalInterest;
    double totalToPay;

    if (!hasInterest || effectiveTea == 0 || temDecimal == 0 || installments == 1) {
      monthlyPayment = principal / installments;
      totalInterest = 0.0;
      totalToPay = principal;
    } else {
      // Fórmula del Sistema Francés: R = P * [ i * (1+i)^n ] / [ (1+i)^n - 1 ]
      final factor = math.pow(1.0 + temDecimal, installments).toDouble();
      monthlyPayment = principal * (temDecimal * factor) / (factor - 1.0);
      totalToPay = monthlyPayment * installments;
      totalInterest = totalToPay - principal;
    }

    final firstDueDate = calculateFirstDueDate(
      purchaseDate: purchaseDate,
      closingDay: closingDay,
      paymentDueDay: paymentDueDay,
    );

    // Generar cronograma detallado
    final schedule = <InstallmentItem>[];
    double balance = principal;

    for (int i = 1; i <= installments; i++) {
      final dueDate = addMonthsToDay(firstDueDate, i - 1, paymentDueDay ?? firstDueDate.day);
      double interestForMonth = 0.0;
      double principalForMonth = monthlyPayment;

      if (hasInterest && temDecimal > 0 && installments > 1) {
        interestForMonth = balance * temDecimal;
        principalForMonth = monthlyPayment - interestForMonth;
        if (i == installments) {
          // Ajuste de redondeo final
          principalForMonth = balance;
        }
      }

      balance = math.max(0.0, balance - principalForMonth);

      schedule.add(
        InstallmentItem(
          number: i,
          dueDate: dueDate,
          payment: monthlyPayment,
          principalPortion: principalForMonth,
          interestPortion: interestForMonth,
          remainingBalance: balance,
        ),
      );
    }

    return InstallmentPlanCalculation(
      principal: principal,
      installments: installments,
      tea: effectiveTea,
      tem: temPercent,
      monthlyPayment: monthlyPayment,
      totalInterest: totalInterest,
      totalToPay: totalToPay,
      hasInterest: hasInterest,
      firstDueDate: firstDueDate,
      schedule: schedule,
    );
  }

  /// Calcula la fecha de vencimiento de la primera cuota según día de corte y pago
  static DateTime calculateFirstDueDate({
    required DateTime purchaseDate,
    int? closingDay,
    int? paymentDueDay,
  }) {
    // Si no tiene configurado día de corte o pago, estimar vencimiento a 30 días
    if (closingDay == null || paymentDueDay == null) {
      return purchaseDate.add(const Duration(days: 30));
    }

    // 1. Determinar la fecha de corte aplicable a esta compra
    DateTime closingDate;
    if (purchaseDate.day <= closingDay) {
      // Compra antes o durante el día de corte: corta este mismo mes
      closingDate = _createValidDate(purchaseDate.year, purchaseDate.month, closingDay);
    } else {
      // Compra después del día de corte: pasa al ciclo del siguiente mes
      var nextMonth = purchaseDate.month + 1;
      var year = purchaseDate.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        year++;
      }
      closingDate = _createValidDate(year, nextMonth, closingDay);
    }

    // 2. Determinar la fecha de pago correspondiente a ese corte
    // Por convención bancaria, el pago suele ser en el mes siguiente al corte
    var payYear = closingDate.year;
    var payMonth = closingDate.month + 1;
    if (payMonth > 12) {
      payMonth = 1;
      payYear++;
    }

    // Si el día de pago es mayor al de corte en al menos 10 días, podría ser en el mismo mes
    if (paymentDueDay > closingDate.day && (paymentDueDay - closingDate.day) >= 10) {
      return _createValidDate(closingDate.year, closingDate.month, paymentDueDay);
    }

    return _createValidDate(payYear, payMonth, paymentDueDay);
  }

  /// Añade meses de forma segura ajustando el día según el calendario (ej. fin de mes)
  static DateTime addMonthsToDay(DateTime baseDate, int monthsToAdd, int targetDay) {
    if (monthsToAdd == 0) return baseDate;

    var newYear = baseDate.year;
    var newMonth = baseDate.month + monthsToAdd;

    while (newMonth > 12) {
      newMonth -= 12;
      newYear++;
    }
    while (newMonth < 1) {
      newMonth += 12;
      newYear--;
    }

    return _createValidDate(newYear, newMonth, targetDay);
  }

  /// Crea una fecha válida protegiéndose contra días inexistentes (ej. 31 en febrero o abril)
  static DateTime _createValidDate(int year, int month, int day) {
    var maxDays = 31;
    if (month == 2) {
      final isLeap = (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0));
      maxDays = isLeap ? 29 : 28;
    } else if (month == 4 || month == 6 || month == 9 || month == 11) {
      maxDays = 30;
    }

    final safeDay = math.min(day, maxDays);
    return DateTime(year, month, safeDay);
  }
}
