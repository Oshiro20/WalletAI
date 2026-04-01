import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/net_worth_entity.dart';
import 'database_providers.dart';

/// Provider que calcula el Patrimonio Neto en tiempo real
final netWorthProvider = StreamProvider<NetWorthEntity>((ref) {
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
              final debt = acc.balance < 0 ? acc.balance.abs() : 0;
              if (debt > 0) {
                totalLiabilities += debt;
                liabilityAccounts.add(
                  AccountBreakdown(
                    id: acc.id,
                    name: acc.name,
                    type: acc.type,
                    institution: acc.institution,
                    balance: debt.toDouble(),
                    creditLimit: acc.creditLimit,
                    currency: acc.currency,
                    percentage: 0.0,
                  ),
                );
              }
            } else if (acc.balance > 0) {
              totalAssets += acc.balance;
              assetAccounts.add(
                AccountBreakdown(
                  id: acc.id,
                  name: acc.name,
                  type: acc.type,
                  institution: acc.institution,
                  balance: acc.balance,
                  currency: acc.currency,
                  percentage: 0,
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

/// Provider de snapshots históricos para sparkline (últimos 6 meses)
final netWorthHistoryProvider = FutureProvider<List<NetWorthSnapshot>>((
  ref,
) async {
  final accountsDao = ref.watch(accountsDaoProvider);
  final now = DateTime.now();
  final snapshots = <NetWorthSnapshot>[];

  for (int i = 5; i >= 0; i--) {
    final month = DateTime(now.year, now.month - i, 1);
    final accounts = await accountsDao.getAllAccounts();
    double assets = 0;
    double liabilities = 0;

    for (final acc in accounts.where((a) => a.isActive)) {
      if (acc.type == 'credit_card') {
        liabilities += acc.balance < 0 ? acc.balance.abs() : 0;
      } else {
        assets += acc.balance > 0 ? acc.balance : 0;
      }
    }

    snapshots.add(
      NetWorthSnapshot(
        date: month,
        netWorth: assets - liabilities,
        assets: assets,
        liabilities: liabilities,
      ),
    );
  }

  return snapshots;
});
