import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/datasources/receipt_scanner_service.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/transaction_repository_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:uuid/uuid.dart';
import '../../../../data/database/drift_database.dart';

class AddReceiptItemsScreen extends ConsumerStatefulWidget {
  final ScannedReceipt receipt;

  const AddReceiptItemsScreen({super.key, required this.receipt});

  @override
  ConsumerState<AddReceiptItemsScreen> createState() =>
      _AddReceiptItemsScreenState();
}

class _AddReceiptItemsScreenState extends ConsumerState<AddReceiptItemsScreen> {
  final List<ReceiptItem> _items = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.receipt.items != null) {
      _items.addAll(widget.receipt.items!);
    }
  }

  Future<void> _saveAll() async {
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(transactionRepositoryProvider);
      final categoriesDao = ref.read(categoriesDaoProvider);
      final accountsDao = ref.read(accountsDaoProvider);

      final categories = await categoriesDao.getAllCategories();
      final accounts = await accountsDao.getAllAccounts();

      if (accounts.isEmpty) {
        throw Exception('No hay cuentas disponibles');
      }

      final defaultAccountId = accounts.first.id;

      final now = DateTime.now();

      for (final item in _items) {
        String? catId;

        // Match category
        if (item.category != null) {
          for (final c in categories) {
            if (c.type == 'expense' &&
                c.name.toLowerCase() == item.category!.toLowerCase()) {
              catId = c.id;
              break;
            }
          }
        }

        // Fallback cat
        if (catId == null) {
          for (final c in categories) {
            if (c.type == 'expense' && c.name.toLowerCase() == 'otro') {
              catId = c.id;
              break;
            }
          }
        }

        if (catId == null && categories.isNotEmpty) {
          catId = categories.firstWhere((c) => c.type == 'expense').id;
        }

        final txId = const Uuid().v4();
        await repo.addTransaction(
          accountId: defaultAccountId,
          amount: item.price,
          type: 'expense',
          transaction: TransactionsCompanion(
            id: drift.Value(txId),
            accountId: drift.Value(defaultAccountId),
            categoryId: drift.Value(catId ?? ''),
            type: const drift.Value('expense'),
            amount: drift.Value(item.price),
            description: drift.Value(widget.receipt.merchant ?? 'Supermercado'),
            productName: drift.Value(item.name),
            date: drift.Value(widget.receipt.date ?? now),
            currency: const drift.Value('PEN'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_items.length} transacciones guardadas')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos Escaneados'),
        actions: [
          if (_items.isNotEmpty)
            _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Guardar Todo',
                    onPressed: _saveAll,
                  ),
        ],
      ),
      body: _items.isEmpty
          ? const Center(child: Text('No se encontraron ítems en la boleta.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.shopping_bag),
                    ),
                    title: Text(item.name),
                    subtitle: Text(
                      '${item.category ?? "Sin categoría"} • Cantidad: ${item.quantity ?? 1}',
                    ),
                    trailing: Text(
                      'S/ ${item.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    onLongPress: () {
                      setState(() {
                        _items.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
    );
  }
}
