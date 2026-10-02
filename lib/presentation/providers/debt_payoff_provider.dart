import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/debt_payoff_entity.dart';
import 'net_worth_provider.dart';
import 'database_providers.dart';

/// Provider que calcula la estrategia de liquidación de deudas
final debtPayoffProvider = StreamProvider.family<DebtPayoffEntity, DebtStrategy>((
  ref,
  strategy,
) {
  final accountsAsync = ref.watch(accountsStreamProvider);

  return accountsAsync.maybeWhen(
    data: (accounts) {
      final liabilityAccounts = accounts
          .where((a) => a.isActive && (a.type == 'credit_card' || a.balance < 0))
          .toList();
      final debts = <DebtAccount>[];

      for (final acc in liabilityAccounts) {
        final debtBalance = acc.type == 'credit_card'
            ? (acc.balance < 0 ? acc.balance.abs() : 0.0)
            : acc.balance.abs();

        if (debtBalance <= 0) continue;

        // Si la tarjeta tiene TEA configurada por el usuario en la BD, la usamos. Si no, estimado por defecto.
        final annualRate = (acc.tea != null && acc.tea! > 0)
            ? (acc.tea! / 100.0)
            : _estimateTeaForType(acc.type);

        // Pago mínimo estimado: 5% del saldo o S/50, lo que sea mayor
        final minPayment = (debtBalance * 0.05).clamp(50.0, double.infinity);

        debts.add(
          DebtAccount(
            id: acc.id,
            name: acc.name,
            institution: acc.institution,
            balance: debtBalance,
            annualInterestRate: annualRate,
            minimumPayment: minPayment,
            creditLimit: acc.creditLimit,
          ),
        );
      }

      // Pago extra estimado: 10% de la deuda total
      final extraPayment = debts.fold(0.0, (sum, d) => sum + d.balance) * 0.1;

      return Stream.value(
        DebtPayoffEntity(
          debts: debts,
          extraPayment: extraPayment,
          strategy: strategy,
        ),
      );
    },
    orElse: () => const Stream.empty(),
  );
});

/// Provider combinado con ambas estrategias para comparación
final debtComparisonProvider =
    Provider<
      ({DebtPayoffEntity avalanche, DebtPayoffEntity snowball, double savings})
    >((ref) {
      final avalancheAsync = ref.watch(
        debtPayoffProvider(DebtStrategy.avalanche),
      );
      final snowballAsync = ref.watch(
        debtPayoffProvider(DebtStrategy.snowball),
      );

      final avalanche =
          avalancheAsync.valueOrNull ??
          DebtPayoffEntity(debts: [], extraPayment: 0);
      final snowball =
          snowballAsync.valueOrNull ??
          DebtPayoffEntity(debts: [], extraPayment: 0);

      return (
        avalanche: avalanche,
        snowball: snowball,
        savings: avalanche.savingsVsOtherStrategy,
      );
    });

/// Provider de insights financieros basados en datos reales
final financialInsightsProvider = FutureProvider<List<String>>((ref) async {
  final netWorthAsync = ref.watch(netWorthProvider);
  final currentMonthExpensesAsync = ref.watch(currentMonthExpensesProvider);
  final currentMonthIncomeAsync = ref.watch(currentMonthIncomeProvider);

  final netWorth = netWorthAsync.valueOrNull;
  final expenses = currentMonthExpensesAsync.valueOrNull ?? 0;
  final income = currentMonthIncomeAsync.valueOrNull ?? 0;
  final insights = <String>[];

  if (netWorth != null) {
    if (netWorth.financialHealthScore >= 80) {
      insights.add(
        'Tu salud financiera es excelente. Considera invertir el excedente.',
      );
    } else if (netWorth.financialHealthScore < 40) {
      insights.add(
        'Tu nivel de endeudamiento es alto. Prioriza reducir pasivos.',
      );
    }

    if (netWorth.debtToAssetRatio > 0.5) {
      insights.add('Más del 50% de tus activos están financiados con deuda.');
    }

    for (final acc in netWorth.liabilityAccounts) {
      if (acc.isOverutilized) {
        insights.add(
          '${acc.name} tiene ${acc.creditUtilization.toStringAsFixed(0)}% de su límite utilizado. Intenta mantenerlo bajo 30%.',
        );
      }
    }
  }

  if (income > 0 && expenses > 0) {
    final savingsRate = (income - expenses) / income * 100;
    if (savingsRate >= 20) {
      insights.add(
        '¡Bien! Ahorras el ${savingsRate.toStringAsFixed(0)}% de tus ingresos. La meta ideal es 20%.',
      );
    } else if (savingsRate < 0) {
      insights.add(
        'Tus gastos superan tus ingresos este mes. Revisa tus categorías de mayor gasto.',
      );
    } else {
      insights.add(
        'Tu tasa de ahorro es ${savingsRate.toStringAsFixed(0)}%. Intenta llegar al 20%.',
      );
    }
  }

  if (insights.isEmpty) {
    insights.add(
      'Agrega más transacciones para recibir insights personalizados.',
    );
  }

  return insights;
});

double _estimateTeaForType(String type) {
  // TEA estimadas por tipo (en producción vendrían de la DB)
  switch (type) {
    case 'credit_card':
      return 0.72; // 72% TEA promedio en Perú
    default:
      return 0.15;
  }
}
