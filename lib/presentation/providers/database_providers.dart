import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/drift_database.dart';
import '../../data/datasources/currency_service.dart';

import '../../core/utils/period_filter.dart';

/// Filtros para transacciones
class TransactionFilters {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? type;
  final String? accountId;
  final String? categoryId;
  final TimePeriod period;

  TransactionFilters({
    this.startDate,
    this.endDate,
    this.type,
    this.accountId,
    this.categoryId,
    this.period = TimePeriod.month,
  });

  TransactionFilters copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? type,
    String? accountId,
    String? categoryId,
    TimePeriod? period,
  }) {
    return TransactionFilters(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      period: period ?? this.period,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TransactionFilters &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.type == type &&
        other.accountId == accountId &&
        other.categoryId == categoryId &&
        other.period == period;
  }

  @override
  int get hashCode {
    return startDate.hashCode ^
        endDate.hashCode ^
        type.hashCode ^
        accountId.hashCode ^
        categoryId.hashCode ^
        period.hashCode;
  }
}

/// Provider de estado de filtros
final transactionFiltersProvider = StateProvider<TransactionFilters>((ref) {
  final now = DateTime.now();
  final range = TimePeriod.month.calculateRange(now);
  return TransactionFilters(
    startDate: range.start,
    endDate: range.end,
    period: TimePeriod.month,
  );
});

/// Provider de transacciones filtradas
final filteredTransactionsProvider =
    StreamProvider.autoDispose<List<Transaction>>((ref) {
      final dao = ref.watch(transactionsDaoProvider);
      final filters = ref.watch(transactionFiltersProvider);

      return dao
          .watchFilteredTransactions(
            startDate: filters.startDate,
            endDate: filters.endDate,
            type: filters.type,
            accountId: filters.accountId,
            categoryId: filters.categoryId,
          )
          .handleError((error) {
            return <Transaction>[];
          });
    });

/// Provider de transacciones filtradas para una categoría específica (family)
final categoricalTransactionsProvider = StreamProvider.autoDispose
    .family<List<Transaction>, TransactionFilters>((ref, filters) {
      final dao = ref.watch(transactionsDaoProvider);
      return dao.watchFilteredTransactions(
        startDate: filters.startDate,
        endDate: filters.endDate,
        type: filters.type,
        accountId: filters.accountId,
        categoryId: filters.categoryId,
      );
    });

/// Provider de tasas de cambio (Base PEN)
final exchangeRatesProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    return await CurrencyService().getRatesBasePEN();
  } catch (e) {
    return {
      'PEN': 1.0,
    }; // Fallback: evitar crashes, aunque la conversión fallará para otros
  }
});

/// Helper para convertir moneda
double _convertToPen(
  double amount,
  String? currency,
  Map<String, double> rates,
) {
  if (currency == null || currency == 'PEN') return amount;
  if (!rates.containsKey(currency)) {
    return amount; // Si no hay tasa, retornamos monto original (mejor que 0)
  }

  // rates['USD'] = 0.26 (1 PEN = 0.26 USD)
  // X PEN * 0.26 = Y USD  => X = Y / 0.26
  final rate = rates[currency]!;
  if (rate == 0) return amount;
  return amount / rate;
}

/// Provider de balance filtrado (con conversión)
/// Provider de balance filtrado (con conversión) - Refactored to avoid Future hanging
final filteredBalanceProvider =
    Provider.autoDispose<AsyncValue<Map<String, double>>>((ref) {
      final transactionsAsync = ref.watch(filteredTransactionsProvider);
      final ratesAsync = ref.watch(exchangeRatesProvider);

      if (transactionsAsync.isLoading || ratesAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (transactionsAsync.hasError) {
        return AsyncValue.error(
          transactionsAsync.error!,
          transactionsAsync.stackTrace ?? StackTrace.current,
        );
      }

      // Rates error falls back to default usually, but if it errors here:
      if (ratesAsync.hasError) {
        return AsyncValue.error(
          ratesAsync.error!,
          ratesAsync.stackTrace ?? StackTrace.current,
        );
      }

      final transactions = transactionsAsync.value ?? [];
      final rates = ratesAsync.value ?? {'PEN': 1.0};

      double income = 0;
      double expense = 0;

      for (var t in transactions) {
        final currency = t.currency;
        final amountInPen = _convertToPen(t.amount, currency, rates);

        if (t.type == 'income') {
          income += amountInPen;
        } else if (t.type == 'expense') {
          expense += amountInPen;
        }
      }

      return AsyncValue.data({
        'income': income,
        'expense': expense,
        'total': income - expense,
      });
    });

/// Provider global de la base de datos
final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() => database.close());
  return database;
});

/// Provider de AccountsDao
final accountsDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.accountsDao;
});

/// Provider de TransactionsDao
final transactionsDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.transactionsDao;
});

/// Provider de CategoriesDao
final categoriesDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.categoriesDao;
});

/// Provider de BudgetsDao
final budgetsDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.budgetsDao;
});

/// Provider de SavingsGoalsDao
final savingsGoalsDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.savingsGoalsDao;
});

/// Provider de RecurringPaymentsDao
final recurringPaymentsDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.recurringPaymentsDao;
});

/// Provider de SubcategoriesDao
final subcategoriesDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.subcategoriesDao;
});

/// Provider de SyncQueueDao
final syncQueueDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.syncQueueDao;
});

/// Provider de TravelsDao
final travelsDaoProvider = Provider((ref) {
  final database = ref.watch(databaseProvider);
  return database.travelsDao;
});

/// Provider de stream del viaje activo
final activeTravelProvider = StreamProvider((ref) {
  final dao = ref.watch(travelsDaoProvider);
  return dao.watchActiveTravel();
});

/// Provider de stream de todos los viajes
final allTravelsStreamProvider = StreamProvider((ref) {
  final dao = ref.watch(travelsDaoProvider);
  return dao.watchAllTravels();
});

/// Provider de stream de subcategorías por categoría (family provider)
final subcategoriesStreamProvider =
    StreamProvider.family<List<Subcategory>, String>((ref, categoryId) {
      final dao = ref.watch(subcategoriesDaoProvider);
      return dao.watchSubcategoriesByCategoryId(categoryId);
    });

/// Provider de stream de TODAS las subcategorías
final allSubcategoriesStreamProvider = StreamProvider<List<Subcategory>>((ref) {
  final dao = ref.watch(subcategoriesDaoProvider);
  return dao.watchAllSubcategories();
});

/// Provider de stream de cuentas
final accountsStreamProvider = StreamProvider((ref) {
  final dao = ref.watch(accountsDaoProvider);
  return dao.watchAllAccounts();
});

/// Provider de stream de pagos recurrentes activos
final recurringPaymentsStreamProvider = StreamProvider((ref) {
  final dao = ref.watch(recurringPaymentsDaoProvider);
  return dao.watchAllRecurringPayments();
});

/// Provider de TODAS las transacciones (para búsqueda)
final allTransactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final dao = ref.watch(transactionsDaoProvider);
  return dao.watchAllTransactions(limit: 10000);
});

/// Provider de stream de transacciones
final transactionsStreamProvider = StreamProvider((ref) {
  final dao = ref.watch(transactionsDaoProvider);
  return dao.watchAllTransactions(limit: 50);
});

/// Provider de stream de categorías de gastos
final expenseCategoriesStreamProvider = StreamProvider((ref) {
  final dao = ref.watch(categoriesDaoProvider);
  return dao.watchCategoriesByType('expense');
});

/// Provider de stream de categorías de ingresos
final incomeCategoriesStreamProvider = StreamProvider((ref) {
  final dao = ref.watch(categoriesDaoProvider);
  return dao.watchCategoriesByType('income');
});

/// Provider de todas las categorías (Future)
final allCategoriesFutureProvider = FutureProvider<List<Category>>((ref) async {
  final dao = ref.watch(categoriesDaoProvider);
  return dao.getAllCategories();
});

/// Provider de todas las cuentas (Future) - para voz y búsqueda
final allAccountsFutureProvider = FutureProvider<List<Account>>((ref) async {
  final dao = ref.watch(accountsDaoProvider);
  return dao.getAllAccounts();
});

/// Provider de todas las subcategorías (Future) - para voz
final allSubcategoriesFutureProvider = FutureProvider<List<Subcategory>>((
  ref,
) async {
  final dao = ref.watch(subcategoriesDaoProvider);
  return dao.getAllSubcategories();
});

/// Provider de balance total
final totalBalanceProvider = FutureProvider<double>((ref) async {
  final dao = ref.watch(accountsDaoProvider);
  return dao.getTotalBalance();
});

/// Provider CONSOLIDADO del mes actual — hace UNA sola query DB y retorna income+expense+balance.
/// Los tres providers individuales derivan de éste sin tocar la BD de nuevo.
final currentMonthSummaryProvider = StreamProvider<Map<String, double>>((ref) {
  final dao = ref.watch(transactionsDaoProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  return dao
      .watchFilteredTransactions(startDate: startOfMonth, endDate: endOfMonth)
      .map((transactions) {
        double income = 0;
        double expense = 0;
        final rates = ref.read(exchangeRatesProvider).value ?? {'PEN': 1.0};

        for (final t in transactions) {
          final amount = _convertToPen(t.amount, t.currency, rates);
          if (t.type == 'income') income += amount;
          if (t.type == 'expense') expense += amount;
        }
        return {
          'income': income,
          'expense': expense,
          'balance': income - expense,
        };
      });
});

/// Provider de balance del mes actual (derivado del provider consolidado)
final currentMonthBalanceProvider = Provider<AsyncValue<double>>((ref) {
  return ref
      .watch(currentMonthSummaryProvider)
      .whenData((s) => s['balance'] ?? 0.0);
});

/// Provider de ingresos del mes actual (derivado del provider consolidado)
final currentMonthIncomeProvider = Provider<AsyncValue<double>>((ref) {
  return ref
      .watch(currentMonthSummaryProvider)
      .whenData((s) => s['income'] ?? 0.0);
});

/// Provider de gastos del mes actual (derivado del provider consolidado)
final currentMonthExpensesProvider = Provider<AsyncValue<double>>((ref) {
  return ref
      .watch(currentMonthSummaryProvider)
      .whenData((s) => s['expense'] ?? 0.0);
});

/// Provider CONSOLIDADO del mes anterior
final previousMonthSummaryProvider = StreamProvider<Map<String, double>>((ref) {
  final dao = ref.watch(transactionsDaoProvider);
  final now = DateTime.now();
  final prevMonth = now.month == 1 ? 12 : now.month - 1;
  final prevYear = now.month == 1 ? now.year - 1 : now.year;
  final startOfPrevMonth = DateTime(prevYear, prevMonth, 1);
  final endOfPrevMonth = DateTime(prevYear, prevMonth + 1, 0, 23, 59, 59);

  return dao
      .watchFilteredTransactions(
        startDate: startOfPrevMonth,
        endDate: endOfPrevMonth,
      )
      .map((transactions) {
        double income = 0;
        double expense = 0;
        final rates = ref.read(exchangeRatesProvider).value ?? {'PEN': 1.0};

        for (final t in transactions) {
          final amount = _convertToPen(t.amount, t.currency, rates);
          if (t.type == 'income') income += amount;
          if (t.type == 'expense') expense += amount;
        }
        return {
          'income': income,
          'expense': expense,
          'balance': income - expense,
        };
      });
});

/// Provider de ingresos del mes anterior
final previousMonthIncomeProvider = Provider<AsyncValue<double>>((ref) {
  return ref
      .watch(previousMonthSummaryProvider)
      .whenData((s) => s['income'] ?? 0.0);
});

/// Provider de gastos del mes anterior
final previousMonthExpensesProvider = Provider<AsyncValue<double>>((ref) {
  return ref
      .watch(previousMonthSummaryProvider)
      .whenData((s) => s['expense'] ?? 0.0);
});

/// Provider de gastos por categoría del mes actual
/// Provider de gastos por categoría del mes actual (con conversión)
final currentMonthExpensesByCategoryProvider = StreamProvider<Map<String, double>>((
  ref,
) {
  final dao = ref.watch(transactionsDaoProvider);
  final rates = ref.watch(exchangeRatesProvider).value ?? {'PEN': 1.0};

  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

  // Usamos watchFilteredTransactions para obtener la lista y procesarla en Dart
  return dao
      .watchFilteredTransactions(
        startDate: startOfMonth,
        endDate: endOfMonth,
        type: 'expense',
      )
      .map((transactions) {
        final Map<String, double> totals = {};
        for (final t in transactions) {
          if (t.categoryId != null) {
            final amount = _convertToPen(t.amount, t.currency, rates);
            totals[t.categoryId!] = (totals[t.categoryId!] ?? 0) + amount;
          }
        }
        return totals;
      });
});

/// Provider del mes seleccionado para análisis (Fecha ancla)
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Provider del periodo seleccionado para análisis
final selectedAnalyticsPeriodProvider = StateProvider<TimePeriod>((ref) {
  return TimePeriod.month;
});

/// Provider de resumen del periodo seleccionado (con conversión)
final analyticsSummaryProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
      final date = ref.watch(selectedDateProvider);
      final period = ref.watch(selectedAnalyticsPeriodProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final rates = await ref.watch(exchangeRatesProvider.future);

      final range = period.calculateRange(date);

      // Obtenemos TODAS las transacciones del rango para convertirlas
      final transactions = await dao.getTransactionsByDateRange(
        range.start,
        range.end,
      );

      double income = 0;
      double expense = 0;

      for (var t in transactions) {
        final amountInPen = _convertToPen(t.amount, t.currency, rates);
        if (t.type == 'income') {
          income += amountInPen;
        } else if (t.type == 'expense') {
          expense += amountInPen;
        }
      }

      return {
        'income': income,
        'expense': expense,
        'balance': income - expense,
      };
    });

/// Provider de gastos por categoría del periodo seleccionado (con conversión)
final analyticsExpensesByCategoryProvider =
    StreamProvider.autoDispose<Map<String, double>>((ref) {
      final date = ref.watch(selectedDateProvider);
      final period = ref.watch(selectedAnalyticsPeriodProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final rates = ref.watch(exchangeRatesProvider).value ?? {'PEN': 1.0};

      final range = period.calculateRange(date);

      return dao
          .watchFilteredTransactions(
            startDate: range.start,
            endDate: range.end,
            type: 'expense',
          )
          .map((transactions) {
            final Map<String, double> result = {};
            for (final t in transactions) {
              if (t.categoryId != null) {
                final amount = _convertToPen(t.amount, t.currency, rates);
                result[t.categoryId!] = (result[t.categoryId!] ?? 0) + amount;
              }
            }
            return result;
          });
    });

/// Provider de ingresos por categoría del periodo seleccionado (con conversión)
final analyticsIncomeByCategoryProvider =
    StreamProvider.autoDispose<Map<String, double>>((ref) {
      final date = ref.watch(selectedDateProvider);
      final period = ref.watch(selectedAnalyticsPeriodProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final rates = ref.watch(exchangeRatesProvider).value ?? {'PEN': 1.0};

      final range = period.calculateRange(date);

      return dao
          .watchFilteredTransactions(
            startDate: range.start,
            endDate: range.end,
            type: 'income',
          )
          .map((transactions) {
            final Map<String, double> result = {};
            for (final t in transactions) {
              if (t.categoryId != null) {
                final amount = _convertToPen(t.amount, t.currency, rates);
                result[t.categoryId!] = (result[t.categoryId!] ?? 0) + amount;
              }
            }
            return result;
          });
    });

/// Provider de totales diarios del mes actual (con conversión)
final currentMonthDailyTotalsProvider =
    StreamProvider<Map<DateTime, Map<String, double>>>((ref) {
      final dao = ref.watch(transactionsDaoProvider);
      final rates = ref.watch(exchangeRatesProvider).value ?? {'PEN': 1.0};

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      return dao
          .watchFilteredTransactions(
            startDate: startOfMonth,
            endDate: endOfMonth,
          )
          .map((transactions) {
            final Map<DateTime, Map<String, double>> dailyTotals = {};

            for (var t in transactions) {
              final date = DateTime(t.date.year, t.date.month, t.date.day);
              if (!dailyTotals.containsKey(date)) {
                dailyTotals[date] = {'income': 0.0, 'expense': 0.0};
              }

              final amount = _convertToPen(t.amount, t.currency, rates);

              if (t.type == 'income') {
                dailyTotals[date]!['income'] =
                    (dailyTotals[date]!['income'] ?? 0) + amount;
              } else if (t.type == 'expense') {
                dailyTotals[date]!['expense'] =
                    (dailyTotals[date]!['expense'] ?? 0) + amount;
              }
            }
            return dailyTotals;
          });
    });

/// Provider de gastos por subcategoría del periodo seleccionado (con conversión)
final analyticsSubcategoriesProvider = StreamProvider.autoDispose
    .family<Map<String, double>, String>((ref, categoryId) {
      final date = ref.watch(selectedDateProvider);
      final period = ref.watch(selectedAnalyticsPeriodProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final rates = ref.watch(exchangeRatesProvider).value ?? {'PEN': 1.0};

      final range = period.calculateRange(date);

      return dao
          .watchFilteredTransactions(
            startDate: range.start,
            endDate: range.end,
            type: 'expense',
            categoryId: categoryId,
          )
          .map((transactions) {
            final Map<String, double> result = {};
            for (final t in transactions) {
              if (t.subcategoryId != null) {
                final amount = _convertToPen(t.amount, t.currency, rates);
                result[t.subcategoryId!] =
                    (result[t.subcategoryId!] ?? 0) + amount;
              }
            }
            return result;
          });
    });

// ─────────────────────────────────────────────────────────────────────────────
// STATISTICS PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Datos mensuales de los últimos N meses (para gráfico de tendencia)
/// Datos mensuales de los últimos N meses (para gráfico de tendencia, con conversión)
final monthlyTrendProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final dao = ref.watch(transactionsDaoProvider);
      final rates = await ref.watch(exchangeRatesProvider.future);
      final now = DateTime.now();

      // Optimización: Traer TODAS las transacciones del último año en una sola query
      final startOfYear = DateTime(now.year, now.month - 11, 1);
      final endOfTime = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final allTransactions = await dao.getTransactionsByDateRange(
        startOfYear,
        endOfTime,
      );

      final result = <Map<String, dynamic>>[];

      for (int i = 11; i >= 0; i--) {
        final monthStart = DateTime(now.year, now.month - i, 1);
        final monthEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);

        double income = 0;
        double expense = 0;

        // Filtrar en memoria
        final monthlyTransactions = allTransactions.where(
          (t) =>
              t.date.isAfter(monthStart.subtract(const Duration(seconds: 1))) &&
              t.date.isBefore(monthEnd.add(const Duration(seconds: 1))),
        );

        for (var t in monthlyTransactions) {
          final amount = _convertToPen(t.amount, t.currency, rates);
          if (t.type == 'income') income += amount;
          if (t.type == 'expense') expense += amount;
        }

        result.add({'month': monthStart, 'expense': expense, 'income': income});
      }
      return result;
    });

/// Top N transacciones de gasto del periodo seleccionado
final topExpensesProvider = FutureProvider.autoDispose<List<Transaction>>((
  ref,
) async {
  final date = ref.watch(selectedDateProvider);
  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final dao = ref.watch(transactionsDaoProvider);
  final range = period.calculateRange(date);

  final all = await dao.getTransactionsByDateRange(range.start, range.end);
  final expenses = all.where((t) => t.type == 'expense').toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return expenses.take(5).toList();
});

/// Promedio diario de gastos del periodo seleccionado (con conversión)
final dailyAverageExpenseProvider = FutureProvider.autoDispose<double>((
  ref,
) async {
  final date = ref.watch(selectedDateProvider);
  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final dao = ref.watch(transactionsDaoProvider);
  final rates = await ref.watch(exchangeRatesProvider.future);

  final range = period.calculateRange(date);

  final transactions = await dao.getTransactionsByDateRange(
    range.start,
    range.end,
  );
  double total = 0;
  for (final t in transactions) {
    if (t.type == 'expense') {
      total += _convertToPen(t.amount, t.currency, rates);
    }
  }

  final days = range.end.difference(range.start).inDays + 1;
  return days > 0 ? total / days : 0;
});

/// Comparativa: periodo actual vs periodo anterior
/// Comparativa: periodo actual vs periodo anterior (con conversión)
final periodComparisonProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
      final date = ref.watch(selectedDateProvider);
      final period = ref.watch(selectedAnalyticsPeriodProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final rates = await ref.watch(exchangeRatesProvider.future);

      final currentRange = period.calculateRange(date);
      final duration = currentRange.end.difference(currentRange.start);
      final prevEnd = currentRange.start.subtract(const Duration(seconds: 1));
      final prevStart = prevEnd.subtract(duration);

      // Helper para sumar gastos/ingresos de un rango
      Future<Map<String, double>> getTotals(
        DateTime start,
        DateTime end,
      ) async {
        final txs = await dao.getTransactionsByDateRange(start, end);
        double inc = 0;
        double exp = 0;
        for (final t in txs) {
          final amt = _convertToPen(t.amount, t.currency, rates);
          if (t.type == 'income') inc += amt;
          if (t.type == 'expense') exp += amt;
        }
        return {'income': inc, 'expense': exp};
      }

      final current = await getTotals(currentRange.start, currentRange.end);
      final prev = await getTotals(prevStart, prevEnd);

      final currentExpense = current['expense']!;
      final prevExpense = prev['expense']!;
      final currentIncome = current['income']!;
      final prevIncome = prev['income']!;

      final expenseChange = prevExpense > 0
          ? ((currentExpense - prevExpense) / prevExpense * 100)
          : 0.0;
      final incomeChange = prevIncome > 0
          ? ((currentIncome - prevIncome) / prevIncome * 100)
          : 0.0;

      return {
        'currentExpense': currentExpense,
        'prevExpense': prevExpense,
        'expenseChange': expenseChange,
        'currentIncome': currentIncome,
        'prevIncome': prevIncome,
        'incomeChange': incomeChange,
      };
    });

/// Gastos por cuenta del periodo seleccionado (con conversión)
final expensesByAccountProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
      final date = ref.watch(selectedDateProvider);
      final period = ref.watch(selectedAnalyticsPeriodProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final rates = await ref.watch(exchangeRatesProvider.future);

      final range = period.calculateRange(date);

      final all = await dao.getTransactionsByDateRange(range.start, range.end);
      final result = <String, double>{};
      for (final t in all) {
        if (t.type == 'expense') {
          final amount = _convertToPen(t.amount, t.currency, rates);
          result[t.accountId] = (result[t.accountId] ?? 0) + amount;
        }
      }
      return result;
    });

/// Día de la semana con más gastos (0=Lunes, 6=Domingo) (con conversión)
final spendingByDayOfWeekProvider =
    FutureProvider.autoDispose<Map<int, double>>((ref) async {
      final date = ref.watch(selectedDateProvider);
      final period = ref.watch(selectedAnalyticsPeriodProvider);
      final dao = ref.watch(transactionsDaoProvider);
      final rates = await ref.watch(exchangeRatesProvider.future);

      final range = period.calculateRange(date);

      final all = await dao.getTransactionsByDateRange(range.start, range.end);
      final result = <int, double>{for (int i = 1; i <= 7; i++) i: 0.0};
      for (final t in all) {
        if (t.type == 'expense') {
          final dow = t.date.weekday; // 1=Mon, 7=Sun
          final amount = _convertToPen(t.amount, t.currency, rates);
          result[dow] = (result[dow] ?? 0) + amount;
        }
      }
      return result;
    });

/// Insights financieros automáticos
final financialInsightsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final comparison = await ref.watch(periodComparisonProvider.future);
  final topExpenses = await ref.watch(topExpensesProvider.future);
  final dailyAvg = await ref.watch(dailyAverageExpenseProvider.future);
  final dowData = await ref.watch(spendingByDayOfWeekProvider.future);

  final insights = <String>[];
  const dayNames = {
    1: 'lunes',
    2: 'martes',
    3: 'miércoles',
    4: 'jueves',
    5: 'viernes',
    6: 'sábado',
    7: 'domingo',
  };

  // Comparativa de gastos
  final expChange = comparison['expenseChange'] ?? 0;
  if (expChange > 10) {
    insights.add(
      '📈 Gastaste ${expChange.toStringAsFixed(0)}% más que el período anterior.',
    );
  } else if (expChange < -10) {
    insights.add(
      '📉 ¡Bien! Gastaste ${expChange.abs().toStringAsFixed(0)}% menos que el período anterior.',
    );
  } else if (expChange != 0) {
    insights.add(
      '✅ Tus gastos se mantienen estables respecto al período anterior.',
    );
  }

  // Promedio diario
  if (dailyAvg > 0) {
    insights.add(
      '💰 Gastas en promedio S/ ${dailyAvg.toStringAsFixed(2)} por día.',
    );
  }

  // Día más caro
  if (dowData.isNotEmpty) {
    final maxDay = dowData.entries.reduce((a, b) => a.value > b.value ? a : b);
    if (maxDay.value > 0) {
      insights.add(
        '📅 Los ${dayNames[maxDay.key] ?? ''}s son tu día de mayor gasto.',
      );
    }
  }

  // Mayor gasto individual
  if (topExpenses.isNotEmpty) {
    final top = topExpenses.first;
    final displayValue =
        (top.productName != null && top.productName!.isNotEmpty)
        ? top.productName!
        : (top.description ?? 'Sin descripción');
    insights.add(
      '🏆 Tu mayor gasto fue S/ ${top.amount.toStringAsFixed(2)}: "$displayValue".',
    );
  }

  // Balance
  final currentExpense = comparison['currentExpense'] ?? 0;
  final currentIncome = comparison['currentIncome'] ?? 0;
  if (currentIncome > 0 && currentExpense > 0) {
    final savingsRate =
        ((currentIncome - currentExpense) / currentIncome * 100);
    if (savingsRate > 20) {
      insights.add(
        '🎯 ¡Excelente! Estás ahorrando el ${savingsRate.toStringAsFixed(0)}% de tus ingresos.',
      );
    } else if (savingsRate > 0) {
      insights.add(
        '💡 Estás ahorrando el ${savingsRate.toStringAsFixed(0)}% de tus ingresos. ¡Puedes mejorar!',
      );
    } else {
      insights.add(
        '⚠️ Tus gastos superan tus ingresos este período. Revisa tus categorías.',
      );
    }
  }

  if (insights.isEmpty) {
    insights.add(
      '📊 Registra más transacciones para obtener insights personalizados.',
    );
  }

  return insights;
});
