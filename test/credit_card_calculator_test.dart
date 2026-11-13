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

    test('Calcula cuotas ingresadas manualmente no predefinidas (ej. 5 cuotas)', () {
      final plan = CreditCardCalculator.calculatePlan(
        principal: 1000.0,
        installments: 5,
        tea: 54.9,
        hasInterest: true,
        purchaseDate: DateTime(2026, 10, 5),
        closingDay: 20,
        paymentDueDay: 10,
      );

      expect(plan.installments, equals(5));
      expect(plan.schedule.length, equals(5));
      expect(plan.monthlyPayment, greaterThan(200.0));
      expect(plan.totalInterest, greaterThan(0.0));
      expect(plan.schedule.last.remainingBalance, closeTo(0.0, 0.05));
    });

    test('Calcula TEA implícita e intereses desde cuota fija del banco', () {
      final forward = CreditCardCalculator.calculatePlan(
        principal: 1200.0,
        installments: 7,
        tea: 60.0,
        hasInterest: true,
        purchaseDate: DateTime(2026, 10, 5),
        closingDay: 20,
        paymentDueDay: 10,
      );

      final reverse = CreditCardCalculator.calculateFromMonthlyPayment(
        principal: 1200.0,
        installments: 7,
        monthlyPayment: forward.monthlyPayment,
        purchaseDate: DateTime(2026, 10, 5),
        closingDay: 20,
        paymentDueDay: 10,
      );

      expect(reverse.hasInterest, isTrue);
      expect(reverse.tea, closeTo(60.0, 0.1));
      expect(reverse.totalInterest, closeTo(forward.totalInterest, 0.01));
      expect(reverse.schedule.length, equals(7));
    });

    test('calculateCardBalance soporta saldo negativo y línea positiva disponible', () {
      final neg = CreditCardCalculator.calculateCardBalance(
        balance: -1200.0,
        creditLimit: 5000.0,
      );
      expect(neg.debt, equals(1200.0));
      expect(neg.available, equals(3800.0));

      final pos = CreditCardCalculator.calculateCardBalance(
        balance: 3800.0,
        creditLimit: 5000.0,
      );
      expect(pos.debt, equals(1200.0));
      expect(pos.available, equals(3800.0));
    });

    test('addMonthsToDay ajusta fin de mes sin desbordar febrero', () {
      final next = CreditCardCalculator.addMonthsToDay(
        DateTime(2026, 1, 31),
        1,
        31,
      );
      expect(next.year, equals(2026));
      expect(next.month, equals(2));
      expect(next.day, equals(28));
    });
  });
}
