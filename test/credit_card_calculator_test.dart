import 'package:flutter_test/flutter_test.dart';
import 'package:wallet_ai/core/utils/credit_card_calculator.dart';

void main() {
  group('CreditCardCalculator Tests', () {
    test('Calcula cuotas sin intereses correctamente', () {
      final plan = CreditCardCalculator.calculatePlan(
        principal: 1200.0,
        installments: 3,
        tea: 54.9,
        hasInterest: false,
        purchaseDate: DateTime(2026, 10, 5),
        closingDay: 20,
        paymentDueDay: 10,
      );

      expect(plan.monthlyPayment, equals(400.0));
      expect(plan.totalInterest, equals(0.0));
      expect(plan.totalToPay, equals(1200.0));
      expect(plan.schedule.length, equals(3));
      expect(plan.schedule.last.remainingBalance, equals(0.0));
    });

    test('Calcula cuotas con intereses (Sistema Francés)', () {
      final plan = CreditCardCalculator.calculatePlan(
        principal: 1000.0,
        installments: 12,
        tea: 60.0,
        hasInterest: true,
        purchaseDate: DateTime(2026, 10, 5),
        closingDay: 20,
        paymentDueDay: 10,
      );

      expect(plan.monthlyPayment, greaterThan(1000.0 / 12));
      expect(plan.totalInterest, greaterThan(0.0));
      expect(plan.totalToPay, greaterThan(1000.0));
      expect(plan.schedule.length, equals(12));
      expect(plan.schedule.last.remainingBalance, closeTo(0.0, 0.05));
    });

    test('Determina fecha de pago antes del corte', () {
      // Compra el 5 de octubre, corte 20, pago 10 del mes siguiente (noviembre)
      final dueDate = CreditCardCalculator.calculateFirstDueDate(
        purchaseDate: DateTime(2026, 10, 5),
        closingDay: 20,
        paymentDueDay: 10,
      );

      expect(dueDate.year, equals(2026));
      expect(dueDate.month, equals(11));
      expect(dueDate.day, equals(10));
    });

    test('Determina fecha de pago después del corte', () {
      // Compra el 22 de octubre (ya pasó el corte del 20). Pasa al corte del 20 de noviembre, pago el 10 de diciembre
      final dueDate = CreditCardCalculator.calculateFirstDueDate(
        purchaseDate: DateTime(2026, 10, 22),
        closingDay: 20,
        paymentDueDay: 10,
      );

      expect(dueDate.year, equals(2026));
      expect(dueDate.month, equals(12));
      expect(dueDate.day, equals(10));
    });
  });
}
