import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_providers.dart';

class AccountSelector extends ConsumerWidget {
  final String? selectedAccountId;
  final Function(String) onAccountSelected;
  final String? accountIdToExclude;
  final String labelText;

  const AccountSelector({
    super.key,
    required this.selectedAccountId,
    required this.onAccountSelected,
    this.accountIdToExclude,
    this.labelText = 'Cuenta',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsStreamProvider);

    return accountsAsync.when(
      data: (accounts) {
        final availableAccounts = accountIdToExclude != null
            ? accounts.where((a) => a.id != accountIdToExclude).toList()
            : accounts;

        if (availableAccounts.isEmpty) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.warning, color: Colors.orange),
              title: const Text('No hay cuentas disponibles'),
              subtitle: const Text('Crea una cuenta primero'),
            ),
          );
        }

        return DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: labelText,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            prefixIcon: const Icon(Icons.account_balance_wallet),
          ),
          initialValue: selectedAccountId,
          items: availableAccounts.map<DropdownMenuItem<String>>((account) {
            return DropdownMenuItem(
              value: account.id,
              child: Text(account.name),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onAccountSelected(value);
            }
          },
          validator: (value) {
            if (value == null) {
              return 'Selecciona una cuenta';
            }
            return null;
          },
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
