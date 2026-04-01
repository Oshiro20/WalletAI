import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_providers.dart';

/// Stream reactivo del balance líquido disponible.
/// Se recalcula automáticamente cuando cualquier cuenta cambia (saldo, creación, eliminación).
/// Excluye: Tarjetas de crédito, Ahorros, Inversiones
/// Incluye: Efectivo, Banco, Billeteras digitales
final liquidBalanceProvider = StreamProvider<double>((ref) {
  final accountsDao = ref.watch(accountsDaoProvider);

  return accountsDao.watchAllAccounts().map((allAccounts) {
    double total = 0.0;
    for (var acc in allAccounts) {
      if (acc.type == 'cash' || acc.type == 'bank' || acc.type == 'wallet') {
        total += acc.balance;
      }
    }
    return total;
  });
});
