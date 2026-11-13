import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/credit_card_calculator.dart';
import '../../core/utils/text_search_helper.dart';
import '../../domain/entities/net_worth_entity.dart';
import 'database_providers.dart';

/// Provider que calcula el Patrimonio Neto en tiempo real (unificado en PEN)
final netWorthProvider = StreamProvider<NetWorthEntity>((ref) {
  final rates =
      ref.watch(exchangeRatesProvider).value ??
      const {'PEN': 1.0, 'USD': 0.2666, 'EUR': 0.2439};

  return ref
      .watch(accountsStreamProvider)
      .maybeWhen(
        data: (accounts) {
          double totalAssets = 0;
          double totalLiabilities = 0;
          final assetAccounts = <AccountBreakdown>[];
          final liabilityAccounts = <AccountBreakdown>[];

          for (final acc in accounts.where((a) => a.isActive)) {
            if (acc.type == 'credit_card') {
              final card = CreditCardCalculator.calculateCardBalance(
                balance: acc.balance,
                creditLimit: acc.creditLimit,
              );
              final debtInPen = TextSearchHelper.convertToPen(
                card.debt,
                acc.currency,
                rates,
              );
              if (debtInPen > 0) {
                totalLiabilities += debtInPen;
                liabilityAccounts.add(
                  AccountBreakdown(
                    id: acc.id,
                    name: acc.name,
                    type: acc.type,
                    institution: acc.institution,
                    balance: debtInPen,
                    creditLimit: acc.creditLimit != null
                        ? TextSearchHelper.convertToPen(
                            acc.creditLimit!,
                            acc.currency,
                            rates,
                          )
                        : null,
                    currency: 'PEN',
                    percentage: 0.0,
                  ),
                );
              }
            } else if (acc.balance > 0) {
              final balanceInPen = TextSearchHelper.convertToPen(
                acc.balance,
                acc.currency,
                rates,
              );
              totalAssets += balanceInPen;
              assetAccounts.add(
                AccountBreakdown(
                  id: acc.id,
                  name: acc.name,
                  type: acc.type,
                  institution: acc.institution,
                  balance: balanceInPen,
                  currency: 'PEN',
                  percentage: 0,
                ),
              );
            } else if (acc.balance < 0) {
              final debtInPen = TextSearchHelper.convertToPen(
                acc.balance.abs(),
                acc.currency,
                rates,
              );
              totalLiabilities += debtInPen;
              liabilityAccounts.add(
                AccountBreakdown(
                  id: acc.id,
                  name: acc.name,
                  type: acc.type,
                  institution: acc.institution,
                  balance: debtInPen,
                  currency: 'PEN',
                  percentage: 0.0,
                ),
              );
            }
          }

          final totalForPercent = totalAssets + totalLiabilities;
          final updatedAssets = assetAccounts
              .map(
                (a) => AccountBreakdown(
                  id: a.id,
                  name: a.name,
                  type: a.type,
                  institution: a.institution,
                  balance: a.balance,
                  creditLimit: a.creditLimit,
                  currency: a.currency,
                  percentage: totalForPercent > 0
                      ? (a.balance / totalForPercent * 100).toDouble()
                      : 0.0,
                ),
              )
              .toList();

          final updatedLiabilities = liabilityAccounts
              .map(
                (a) => AccountBreakdown(
                  id: a.id,
                  name: a.name,
                  type: a.type,
                  institution: a.institution,
                  balance: a.balance,
                  creditLimit: a.creditLimit,
                  currency: a.currency,
                  percentage: totalForPercent > 0
                      ? (a.balance / totalForPercent * 100).toDouble()
                      : 0.0,
                ),
              )
              .toList();

          return Stream.value(
            NetWorthEntity(
              totalAssets: totalAssets,
              totalLiabilities: totalLiabilities,
              assetAccounts: updatedAssets,
              liabilityAccounts: updatedLiabilities,
            ),
          );
        },
        orElse: () => const Stream.empty(),
      );
});

/// Provider de snapshots históricos reales para sparkline (últimos 6 meses)
/// Reconstruye hacia atrás el patrimonio neto a fin de cada mes a partir de las transacciones reales.
final netWorthHistoryProvider = FutureProvider<List<NetWorthSnapshot>>((
  ref,
) async {
  final accountsDao = ref.watch(accountsDaoProvider);
  final txDao = ref.watch(transactionsDaoProvider);
  final rates = await ref.watch(exchangeRatesProvider.future);

  final now = DateTime.now();
  final sixMonthsStart = DateTime(now.year, now.month - 5, 1);
  final accounts = await accountsDao.getAllAccounts();
  final recentTxs = await txDao.getTransactionsByDateRange(
    sixMonthsStart,
    DateTime(now.year, now.month + 1, 0, 23, 59, 59),
  );

  // Balances actuales por cuenta (en moneda propia de la cuenta)
  final activeAccounts = accounts.where((a) => a.isActive).toList();
  final runningBalances = <String, double>{
    for (final a in activeAccounts) a.id: a.balance,
  };
  final accountCurrencies = <String, String>{
    for (final a in activeAccounts) a.id: a.currency,
  };

  double convertToAccountCurrency(
    double amount,
    String txCurrency,
    String targetCurrency,
  ) {
    if (txCurrency == targetCurrency) return amount;
    final inPen = TextSearchHelper.convertToPen(amount, txCurrency, rates);
    if (targetCurrency == 'PEN') return inPen;
    final targetRate = rates[targetCurrency];
    if (targetRate == null || targetRate == 0) return inPen;
    return inPen * targetRate;
  }

  // Agrupar transacciones por año-mes (YYYY-MM)
  final txsByMonth = <String, List<dynamic>>{};
  for (final tx in recentTxs) {
    final key = '${tx.date.year}-${tx.date.month}';
    txsByMonth.putIfAbsent(key, () => []).add(tx);
  }

  final snapshotsReversed = <NetWorthSnapshot>[];
  // Caminar del mes actual hacia atrás 5 meses
  for (int i = 0; i <= 5; i++) {
    final targetMonth = DateTime(now.year, now.month - i, 1);
    double assets = 0;
    double liabilities = 0;

    for (final acc in activeAccounts) {
      final bal = runningBalances[acc.id] ?? 0.0;
      if (acc.type == 'credit_card') {
        final card = CreditCardCalculator.calculateCardBalance(
          balance: bal,
          creditLimit: acc.creditLimit,
        );
        liabilities += TextSearchHelper.convertToPen(
          card.debt,
          acc.currency,
          rates,
        );
      } else if (bal >= 0) {
        assets += TextSearchHelper.convertToPen(bal, acc.currency, rates);
      } else {
        liabilities += TextSearchHelper.convertToPen(
          bal.abs(),
          acc.currency,
          rates,
        );
      }
    }

    snapshotsReversed.add(
      NetWorthSnapshot(
        date: targetMonth,
        netWorth: assets - liabilities,
        assets: assets,
        liabilities: liabilities,
      ),
    );

    // Revertir las transacciones de `targetMonth` para obtener el saldo al cierre del mes anterior
    final key = '${targetMonth.year}-${targetMonth.month}';
    final monthTxs = txsByMonth[key] ?? const [];
    for (final tx in monthTxs) {
      final srcCurr = accountCurrencies[tx.accountId];
      if (srcCurr != null) {
        final srcAmt = convertToAccountCurrency(tx.amount, tx.currency, srcCurr);
        if (tx.type == 'income') {
          runningBalances[tx.accountId] =
              (runningBalances[tx.accountId] ?? 0) - srcAmt;
        } else {
          runningBalances[tx.accountId] =
              (runningBalances[tx.accountId] ?? 0) + srcAmt;
        }
      }
      if (tx.type == 'transfer' && tx.destinationAccountId != null) {
        final destCurr = accountCurrencies[tx.destinationAccountId];
        if (destCurr != null) {
          final destAmt = convertToAccountCurrency(
            tx.amount,
            tx.currency,
            destCurr,
          );
          runningBalances[tx.destinationAccountId!] =
              (runningBalances[tx.destinationAccountId] ?? 0) - destAmt;
        }
      }
    }
  }

  return snapshotsReversed.reversed.toList();
});
