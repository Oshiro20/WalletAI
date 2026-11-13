import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/text_search_helper.dart';
import '../../../data/database/drift_database.dart';
import '../../providers/database_providers.dart';
import 'widgets/search_widgets.dart';

class TransactionSearchDelegate extends SearchDelegate<void> {
  // Parámetro opcional mantenido por compatibilidad con llamadas existentes
  TransactionSearchDelegate([WidgetRef? _]);

  @override
  String get searchFieldLabel => 'Buscar producto, comercio, categoría...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        iconTheme: IconThemeData(color: cs.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: cs.onSurfaceVariant),
        border: InputBorder.none,
        filled: false,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: theme.textTheme.titleMedium?.copyWith(
          color: cs.onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: 'Limpiar',
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Volver',
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchContent(showCharts: true);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_rounded,
                size: 56,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 12),
              Text(
                'Busca por producto, comercio, categoría,\nsubcategoría, cuenta, monto o fecha',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _buildSearchContent(showCharts: false);
  }

  Widget _buildSearchContent({required bool showCharts}) {
    return Consumer(
      builder: (context, ref, _) {
        final allTransactionsAsync = ref.watch(allTransactionsProvider);
        final categories =
            ref.watch(allCategoriesStreamProvider).valueOrNull ??
            const <Category>[];
        final subcategories =
            ref.watch(allSubcategoriesStreamProvider).valueOrNull ??
            const <Subcategory>[];
        final accounts =
            ref.watch(accountsStreamProvider).valueOrNull ?? const <Account>[];
        final rates =
            ref.watch(exchangeRatesProvider).valueOrNull ??
            const <String, double>{'PEN': 1.0};

        final categoriesMap = {for (final c in categories) c.id: c};
        final subcategoriesMap = {for (final s in subcategories) s.id: s};
        final accountsMap = {for (final a in accounts) a.id: a};

        return allTransactionsAsync.when(
          data: (transactions) {
            final tokens = TextSearchHelper.tokenize(query);

            final results = transactions.where((t) {
              if (tokens.isEmpty) return true;
              final cat = t.categoryId != null
                  ? categoriesMap[t.categoryId]
                  : null;
              final sub = t.subcategoryId != null
                  ? subcategoriesMap[t.subcategoryId]
                  : null;
              final acc = accountsMap[t.accountId];
              final destAcc = t.destinationAccountId != null
                  ? accountsMap[t.destinationAccountId]
                  : null;

              final typeLabel = switch (t.type) {
                'income' => 'ingreso',
                'expense' => 'gasto',
                'transfer' => 'transferencia',
                _ => t.type,
              };

              final formattedDate = DateFormat('dd/MM/yyyy').format(t.date);
              final monthLabel = DateFormat('MMMM yyyy', 'es_PE').format(t.date);

              return TextSearchHelper.matchesAllTokens(tokens, [
                t.productName,
                t.description,
                t.notes,
                t.locationName,
                t.amount.toString(),
                t.amount.toStringAsFixed(2),
                t.currency,
                typeLabel,
                cat?.name,
                cat?.aliases,
                sub?.name,
                acc?.name,
                destAcc?.name,
                formattedDate,
                monthLabel,
              ]);
            }).toList();

            if (results.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey[500]),
                      const SizedBox(height: 16),
                      Text(
                        'No se encontraron resultados para "$query"',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              );
            }

            double totalExpense = 0;
            double totalIncome = 0;
            double totalTransfer = 0;
            for (final t in results) {
              final penAmount = TextSearchHelper.convertToPen(
                t.amount,
                t.currency,
                rates,
              );
              if (t.type == 'expense') {
                totalExpense += penAmount;
              } else if (t.type == 'income') {
                totalIncome += penAmount;
              } else if (t.type == 'transfer') {
                totalTransfer += penAmount;
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: results.length + (showCharts ? 3 : 0),
              itemBuilder: (context, index) {
                if (showCharts) {
                  if (index == 0) {
                    return SearchSummaryCard(
                      totalExpense: totalExpense,
                      totalIncome: totalIncome,
                      totalTransfer: totalTransfer,
                      count: results.length,
                      query: query,
                    );
                  }
                  if (index == 1) {
                    return SearchTrendChart(
                      transactions: results,
                      rates: rates,
                    );
                  }
                  if (index == 2) {
                    return const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Transacciones',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  }
                }

                final txIndex = showCharts ? index - 3 : index;
                final transaction = results[txIndex];
                final cat = transaction.categoryId != null
                    ? categoriesMap[transaction.categoryId]
                    : null;
                final sub = transaction.subcategoryId != null
                    ? subcategoriesMap[transaction.subcategoryId]
                    : null;
                final acc = accountsMap[transaction.accountId];

                final hasProduct =
                    transaction.productName != null &&
                    transaction.productName!.trim().isNotEmpty;
                final hasDescription =
                    transaction.description != null &&
                    transaction.description!.trim().isNotEmpty;

                final titleText = transaction.type == 'transfer'
                    ? (hasDescription
                          ? transaction.description!
                          : 'Transferencia')
                    : (hasProduct
                          ? transaction.productName!
                          : (hasDescription
                                ? transaction.description!
                                : 'Sin descripción'));

                final subtitleParts = <String>[
                  DateFormat('dd/MM/yyyy').format(transaction.date),
                  if (hasProduct && hasDescription) transaction.description!,
                  if (cat != null)
                    sub != null ? '${cat.name} > ${sub.name}' : cat.name,
                  if (acc != null) acc.name,
                ];

                final symbol = TextSearchHelper.currencySymbol(
                  transaction.currency,
                );

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getTypeColor(
                      transaction.type,
                    ).withValues(alpha: 0.12),
                    child: Icon(
                      _getTypeIcon(transaction.type),
                      color: _getTypeColor(transaction.type),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    titleText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitleParts.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '$symbol ${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: _getTypeColor(transaction.type),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    final router = GoRouter.of(context);
                    close(context, null);
                    router.push('/transactions/edit/${transaction.id}');
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        );
      },
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
