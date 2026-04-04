import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/database_providers.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/search_widgets.dart';

class TransactionSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  TransactionSearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Buscar transacciones, categorías...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchContent(context, showCharts: true);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text('Empieza a escribir para buscar...'));
    }
    return _buildSearchContent(context, showCharts: false);
  }

  Widget _buildSearchContent(BuildContext context, {required bool showCharts}) {
    final allTransactionsAsync = ref.watch(allTransactionsProvider);

    return allTransactionsAsync.when(
      data: (transactions) {
        final results = transactions.where((t) {
          final q = query.toLowerCase();
          final matchesDescription =
              t.description?.toLowerCase().contains(q) ?? false;
          final matchesAmount = t.amount.toString().contains(q);
          return matchesDescription || matchesAmount;
        }).toList();

        if (results.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No se encontraron resultados para "$query"'),
              ],
            ),
          );
        }

        double totalAmount = 0;
        for (var t in results) {
          if (t.type == 'expense') {
            totalAmount += t.amount;
          }
        }

        return ListView(
          children: [
            if (showCharts) ...[
              SearchSummaryCard(
                totalAmount: totalAmount,
                count: results.length,
                query: query,
              ),
              SearchTrendChart(transactions: results),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Transacciones',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            ...results.map((transaction) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getTypeColor(
                    transaction.type,
                  ).withValues(alpha: 0.1),
                  child: Icon(
                    _getTypeIcon(transaction.type),
                    color: _getTypeColor(transaction.type),
                    size: 20,
                  ),
                ),
                title: Text(
                  transaction.description ?? 'Sin descripción',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  DateFormat('dd/MM/yyyy').format(transaction.date),
                ),
                trailing: Text(
                  'S/ ${transaction.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: _getTypeColor(transaction.type),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  // Navigate to details or edit
                },
              );
            }),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'income':
        return AppColors.income;
      case 'expense':
        return AppColors.expense;
      case 'transfer':
        return AppColors.transfer;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward;
      case 'expense':
        return Icons.arrow_upward;
      case 'transfer':
        return Icons.swap_horiz;
      default:
        return Icons.help_outline;
    }
  }
}
