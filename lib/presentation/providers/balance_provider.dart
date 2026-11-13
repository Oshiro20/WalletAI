import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/text_search_helper.dart';
import 'database_providers.dart';

/// Stream reactivo del balance líquido disponible (en PEN).
/// Se recalcula automáticamente cuando cualquier cuenta cambia (saldo, creación, eliminación).
/// Excluye: Cuentas inactivas, Tarjetas de crédito, Ahorros, Inversiones
/// Incluye: Efectivo, Banco, Billeteras digitales (convertido a PEN según tasa)
final liquidBalanceProvider = StreamProvider<double>((ref) {
  final accountsDao = ref.watch(accountsDaoProvider);
  final rates =
      ref.watch(exchangeRatesProvider).value ??
      const {'PEN': 1.0, 'USD': 0.2666, 'EUR': 0.2439};

  return accountsDao.watchAllAccounts().map((allAccounts) {
    double total = 0.0;
    for (final acc in allAccounts) {
      if (!acc.isActive) continue;
      if (acc.type == 'cash' || acc.type == 'bank' || acc.type == 'wallet') {
        total += TextSearchHelper.convertToPen(acc.balance, acc.currency, rates);
      }
    }
    return total;
  });
});
