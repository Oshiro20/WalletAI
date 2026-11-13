import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/database/daos/accounts_dao.dart';
import '../../data/database/daos/budgets_dao.dart';
import '../../data/database/daos/categories_dao.dart';
import '../../data/database/daos/credit_installments_dao.dart';
import '../../data/database/daos/recurring_payments_dao.dart';
import '../../data/database/daos/savings_goals_dao.dart';
import '../../data/database/daos/subcategories_dao.dart';
import '../../data/database/daos/transactions_dao.dart';
import '../../data/database/daos/travels_dao.dart';
import '../../data/database/drift_database.dart';
import '../../data/datasources/currency_service.dart';
import '../../presentation/providers/database_providers.dart';
import '../utils/text_search_helper.dart';

/// Construye un contexto financiero completo y actualizado a partir de todas las
/// tablas reales de WalletAI (cuentas, transacciones históricas, categorías,
/// presupuestos, metas de ahorro, pagos recurrentes, cuotas y viajes).
class FinancialContextBuilder {
  final TransactionsDao _transactionsDao;
  final AccountsDao _accountsDao;
  final CategoriesDao _categoriesDao;
  final SubcategoriesDao _subcategoriesDao;
  final BudgetsDao _budgetsDao;
  final SavingsGoalsDao _savingsGoalsDao;
  final RecurringPaymentsDao _recurringPaymentsDao;
  final CreditInstallmentsDao _creditInstallmentsDao;
  final TravelsDao _travelsDao;
  final CurrencyService _currencyService;

  FinancialContextBuilder({
    required TransactionsDao transactionsDao,
    required AccountsDao accountsDao,
    required CategoriesDao categoriesDao,
    required SubcategoriesDao subcategoriesDao,
    required BudgetsDao budgetsDao,
    required SavingsGoalsDao savingsGoalsDao,
    required RecurringPaymentsDao recurringPaymentsDao,
    required CreditInstallmentsDao creditInstallmentsDao,
    required TravelsDao travelsDao,
    CurrencyService? currencyService,
  }) : _transactionsDao = transactionsDao,
       _accountsDao = accountsDao,
       _categoriesDao = categoriesDao,
       _subcategoriesDao = subcategoriesDao,
       _budgetsDao = budgetsDao,
       _savingsGoalsDao = savingsGoalsDao,
       _recurringPaymentsDao = recurringPaymentsDao,
       _creditInstallmentsDao = creditInstallmentsDao,
       _travelsDao = travelsDao,
       _currencyService = currencyService ?? CurrencyService();

  static const Set<String> _stopWords = {
    'a', 'al', 'algo', 'algun', 'alguna', 'algunas', 'algunos', 'ante',
    'ano', 'anos', 'asi', 'aun', 'bajo', 'bien', 'cada', 'casi', 'como',
    'con', 'contra', 'cual', 'cuales', 'cuando', 'cuanta', 'cuantas',
    'cuanto', 'cuantos', 'de', 'del', 'desde', 'donde', 'dime', 'dame',
    'el', 'ella', 'ellas', 'ellos', 'en', 'entre', 'era', 'es', 'esa',
    'esas', 'ese', 'eso', 'esos', 'esta', 'estaba', 'estado', 'estan',
    'estas', 'este', 'esto', 'estos', 'estoy', 'fue', 'fueron', 'gaste',
    'gasto', 'gastos', 'general', 'hacer', 'hace', 'hacia', 'han', 'hasta',
    'hay', 'he', 'hola', 'hoy', 'ingrese', 'ingreso', 'ingresos', 'la',
    'las', 'le', 'les', 'lo', 'los', 'mas', 'me', 'mejor', 'menos', 'mes',
    'meses', 'mi', 'mis', 'mucho', 'muy', 'nada', 'ni', 'no', 'nos',
    'nosotros', 'nuestro', 'o', 'para', 'pasado', 'pero', 'poco', 'por',
    'porque', 'puede', 'puedo', 'que', 'quien', 'quiero', 'real', 'resumen',
    'saber', 'se', 'sea', 'segun', 'semana', 'ser', 'si', 'sin', 'sobre',
    'soles', 'solo', 'son', 'soy', 'su', 'sus', 'tal', 'tambien', 'te',
    'tengo', 'tiene', 'tienen', 'todo', 'todos', 'total', 'tu', 'tus', 'un',
    'una', 'unas', 'uno', 'unos', 'va', 'van', 'ver', 'vez', 'y', 'ya', 'yo',
  };

  static const Map<String, int> _monthKeywords = {
    'enero': 1,
    'febrero': 2,
    'marzo': 3,
    'abril': 4,
    'mayo': 5,
    'junio': 6,
    'julio': 7,
    'agosto': 8,
    'septiembre': 9,
    'setiembre': 9,
    'octubre': 10,
    'noviembre': 11,
    'diciembre': 12,
  };

  Future<Map<String, double>> _safeGetRates() async {
    try {
      return await _currencyService.getRatesBasePEN().timeout(
        const Duration(seconds: 3),
        onTimeout: () => const {'PEN': 1.0},
      );
    } catch (_) {
      return const {'PEN': 1.0};
    }
  }

  /// Genera el bloque completo de contexto financiero personalizado.
  Future<String> buildContext({String? userQuery}) async {
    try {
      final now = DateTime.now();
      final fmt = NumberFormat('S/ #,##0.00', 'en_US');

      final rates = await _safeGetRates();
      final accounts = await _accountsDao.getAllAccounts();
      final categories = await _categoriesDao.getAllCategories();
      final subcategories = await _subcategoriesDao.getAllSubcategories();
      final budgets = await _budgetsDao.getActiveBudgets();
      final goals = await _savingsGoalsDao.getActiveGoals();
      final recurring = await _recurringPaymentsDao.getAllRecurringPayments();
      final installments = await _creditInstallmentsDao.getAllInstallments();
      final travels = await _travelsDao.getAllTravels();
      final allTxs = await _transactionsDao.getAllTransactions(limit: 5000);

      final catMap = {for (final c in categories) c.id: c};
      final subMap = {for (final s in subcategories) s.id: s};
      final accMap = {for (final a in accounts) a.id: a};

      final sb = StringBuffer();
      sb.writeln('Fecha actual: ${DateFormat('dd/MM/yyyy HH:mm').format(now)}');
      sb.writeln('Moneda base del usuario: Soles peruanos (PEN / S/)');

      // ── 1. Cuentas y Patrimonio Neto ────────────────────────────────────────
      double liquidTotal = 0;
      double savingsInvestTotal = 0;
      double totalDebt = 0;

      for (final acc in accounts) {
        final penBalance = TextSearchHelper.convertToPen(
          acc.balance,
          acc.currency,
          rates,
        );
        if (acc.type == 'credit_card') {
          if (penBalance < 0) totalDebt += penBalance.abs();
        } else if (acc.type == 'savings' || acc.type == 'investment') {
          if (penBalance > 0) savingsInvestTotal += penBalance;
        } else {
          liquidTotal += penBalance;
        }
      }

      final totalAssets = liquidTotal + savingsInvestTotal;
      final netWorth = totalAssets - totalDebt;

      sb.writeln('\n=== CUENTAS Y PATRIMONIO ===');
      sb.writeln('Saldo líquido disponible (efectivo/banco/billetera): ${fmt.format(liquidTotal)}');
      if (savingsInvestTotal > 0) {
        sb.writeln('Ahorros e inversiones: ${fmt.format(savingsInvestTotal)}');
      }
      sb.writeln('Deuda total en tarjetas de crédito: ${fmt.format(totalDebt)}');
      sb.writeln('Patrimonio neto estimado: ${fmt.format(netWorth)}');

      if (accounts.isEmpty) {
        sb.writeln('No hay cuentas registradas.');
      } else {
        sb.writeln('Detalle de cuentas (${accounts.length}):');
        for (final a in accounts) {
          final penBal = TextSearchHelper.convertToPen(
            a.balance,
            a.currency,
            rates,
          );
          final sym = TextSearchHelper.currencySymbol(a.currency);
          final origStr = a.currency == 'PEN'
              ? fmt.format(a.balance)
              : '$sym ${a.balance.toStringAsFixed(2)} (≈ ${fmt.format(penBal)})';
          if (a.type == 'credit_card') {
            final debt = a.balance < 0 ? a.balance.abs() : 0.0;
            final limitStr = a.creditLimit != null
                ? ', límite: $sym ${a.creditLimit!.toStringAsFixed(2)}'
                : '';
            final utilStr =
                (a.creditLimit != null && a.creditLimit! > 0)
                    ? ', utilización: ${(debt / a.creditLimit! * 100).toStringAsFixed(0)}%'
                    : '';
            final teaStr = a.tea != null ? ', TEA: ${a.tea!.toStringAsFixed(1)}%' : '';
            final datesStr =
                (a.closingDay != null || a.paymentDueDay != null)
                    ? ', corte día ${a.closingDay ?? "-"}, pago día ${a.paymentDueDay ?? "-"}'
                    : '';
            sb.writeln(
              '  - ${a.name} [Tarjeta de Crédito]: deuda actual $sym ${debt.toStringAsFixed(2)}$limitStr$utilStr$teaStr$datesStr',
            );
          } else {
            sb.writeln('  - ${a.name} [${a.type}]: $origStr');
          }
        }
      }

      // ── 2. Resumen mensual (últimos 6 meses) ────────────────────────────────
      sb.writeln('\n=== RESUMEN MENSUAL (ÚLTIMOS 6 MESES) ===');
      final startCurrentMonth = DateTime(now.year, now.month, 1);
      final endCurrentMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      final startPrevMonth = DateTime(now.year, now.month - 1, 1);
      final endPrevMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

      final Map<String, double> currentCatExpenses = {};
      final Map<String, double> currentSubExpenses = {};
      final Map<String, double> currentCatIncome = {};
      final Map<String, double> prevCatExpenses = {};
      final List<Transaction> currentMonthTxs = [];

      for (int i = 0; i < 6; i++) {
        final mStart = DateTime(now.year, now.month - i, 1);
        final mEnd = DateTime(now.year, now.month - i + 1, 0, 23, 59, 59);
        double inc = 0;
        double exp = 0;
        int count = 0;

        for (final tx in allTxs) {
          if (!tx.date.isBefore(mStart) && !tx.date.isAfter(mEnd)) {
            count++;
            final amt = TextSearchHelper.convertToPen(
              tx.amount,
              tx.currency,
              rates,
            );
            if (tx.type == 'income') inc += amt;
            if (tx.type == 'expense') exp += amt;

            if (i == 0) {
              currentMonthTxs.add(tx);
              if (tx.type == 'expense') {
                final catKey = tx.categoryId ?? 'sin_categoria';
                currentCatExpenses[catKey] =
                    (currentCatExpenses[catKey] ?? 0) + amt;
                if (tx.subcategoryId != null) {
                  currentSubExpenses[tx.subcategoryId!] =
                      (currentSubExpenses[tx.subcategoryId!] ?? 0) + amt;
                }
              } else if (tx.type == 'income') {
                final catKey = tx.categoryId ?? 'sin_categoria';
                currentCatIncome[catKey] =
                    (currentCatIncome[catKey] ?? 0) + amt;
              }
            } else if (i == 1 && tx.type == 'expense') {
              final catKey = tx.categoryId ?? 'sin_categoria';
              prevCatExpenses[catKey] = (prevCatExpenses[catKey] ?? 0) + amt;
            }
          }
        }

        final label = DateFormat('MMMM yyyy', 'es_PE').format(mStart);
        final balance = inc - exp;
        final savingsRate = inc > 0
            ? ' (ahorro ${(balance / inc * 100).toStringAsFixed(0)}%)'
            : '';
        sb.writeln(
          '  - $label: Ingresos ${fmt.format(inc)} | Gastos ${fmt.format(exp)} | Balance ${fmt.format(balance)}$savingsRate | $count movs',
        );
      }

      // Totales exactos mes actual y anterior (para consistencia)
      final currentTotalExp = currentCatExpenses.values.fold(0.0, (a, b) => a + b);
      final prevTotalExp = prevCatExpenses.values.fold(0.0, (a, b) => a + b);
      if (prevTotalExp > 0) {
        final diffPct = ((currentTotalExp - prevTotalExp) / prevTotalExp * 100);
        final trend = diffPct >= 0
            ? '+${diffPct.toStringAsFixed(1)}% más'
            : '${diffPct.toStringAsFixed(1)}% menos';
        sb.writeln(
          'Comparativa de gastos este mes vs mes pasado: $trend (${fmt.format(currentTotalExp)} vs ${fmt.format(prevTotalExp)})',
        );
      }

      // ── 3. Desglose por Categoría y Subcategoría (TODAS las del mes) ────────
      if (currentCatExpenses.isNotEmpty) {
        sb.writeln('\n=== GASTOS POR CATEGORÍA ESTE MES ===');
        final sortedCats = currentCatExpenses.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedCats) {
          final catName = catMap[entry.key]?.name ?? 'Otros';
          final pct = currentTotalExp > 0
              ? (entry.value / currentTotalExp * 100).toStringAsFixed(1)
              : '0.0';
          sb.writeln('  - $catName: ${fmt.format(entry.value)} ($pct%)');
        }
      }

      if (currentSubExpenses.isNotEmpty) {
        sb.writeln('\n=== TOP SUBCATEGORÍAS DE GASTO ESTE MES ===');
        final sortedSubs = currentSubExpenses.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedSubs.take(10)) {
          final sub = subMap[entry.key];
          final catName = sub != null ? (catMap[sub.categoryId]?.name ?? '') : '';
          final label = sub != null
              ? (catName.isNotEmpty ? '$catName > ${sub.name}' : sub.name)
              : entry.key;
          sb.writeln('  - $label: ${fmt.format(entry.value)}');
        }
      }

      if (currentCatIncome.isNotEmpty) {
        sb.writeln('\n=== INGRESOS POR CATEGORÍA ESTE MES ===');
        final sortedInc = currentCatIncome.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedInc) {
          final catName = catMap[entry.key]?.name ?? 'Otros ingresos';
          sb.writeln('  - $catName: ${fmt.format(entry.value)}');
        }
      }

      if (prevCatExpenses.isNotEmpty) {
        sb.writeln('\n=== TOP GASTOS POR CATEGORÍA MES PASADO ===');
        final sortedPrev = prevCatExpenses.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sortedPrev.take(6)) {
          final catName = catMap[entry.key]?.name ?? 'Otros';
          sb.writeln('  - $catName: ${fmt.format(entry.value)}');
        }
      }

      // ── 4. Presupuestos activos con consumo real ────────────────────────────
      if (budgets.isNotEmpty) {
        sb.writeln('\n=== PRESUPUESTOS ACTIVOS (MES ACTUAL) ===');
        for (final b in budgets) {
          final catName = catMap[b.categoryId]?.name ?? b.categoryId;
          final spent = currentCatExpenses[b.categoryId] ?? 0.0;
          final pct = b.amount > 0 ? (spent / b.amount * 100) : 0.0;
          final remaining = b.amount - spent;
          final status = remaining >= 0
              ? 'restan ${fmt.format(remaining)}'
              : 'EXCEDIDO por ${fmt.format(remaining.abs())}';
          sb.writeln(
            '  - $catName: gastado ${fmt.format(spent)} / límite ${fmt.format(b.amount)} (${pct.toStringAsFixed(0)}%, $status)',
          );
        }
      }

      // ── 5. Metas de ahorro ──────────────────────────────────────────────────
      if (goals.isNotEmpty) {
        sb.writeln('\n=== METAS DE AHORRO ACTIVAS ===');
        for (final g in goals) {
          final pct = g.targetAmount > 0
              ? (g.currentAmount / g.targetAmount * 100).toStringAsFixed(0)
              : '0';
          final deadlineStr = g.deadline != null
              ? ', fecha límite: ${DateFormat('dd/MM/yyyy').format(g.deadline!)}'
              : '';
          sb.writeln(
            '  - ${g.name}: ${fmt.format(g.currentAmount)} / ${fmt.format(g.targetAmount)} ($pct%$deadlineStr)',
          );
        }
      }

      // ── 6. Pagos recurrentes / suscripciones ────────────────────────────────
      if (recurring.isNotEmpty) {
        sb.writeln('\n=== PAGOS RECURRENTES Y SUSCRIPCIONES ACTIVAS ===');
        for (final r in recurring) {
          final catName = r.categoryId != null
              ? (catMap[r.categoryId]?.name ?? '')
              : '';
          final catPart = catName.isNotEmpty ? ' [$catName]' : '';
          sb.writeln(
            '  - ${r.name}: ${fmt.format(r.amount)} (${r.frequency})$catPart — próximo pago: ${DateFormat('dd/MM/yyyy').format(r.nextDueDate)}',
          );
        }
      }

      // ── 7. Compras en cuotas con tarjeta ────────────────────────────────────
      final activeInstallments = installments
          .where((c) => c.status == 'active')
          .toList();
      if (activeInstallments.isNotEmpty) {
        sb.writeln('\n=== COMPRAS EN CUOTAS ACTIVAS ===');
        for (final inst in activeInstallments) {
          final cardName = accMap[inst.accountId]?.name ?? 'Tarjeta';
          final remainingQuota = inst.totalInstallments - inst.paidInstallments;
          final remainingAmount = remainingQuota * inst.monthlyPayment;
          final teaStr = inst.tea != null
              ? ', TEA ${inst.tea!.toStringAsFixed(1)}%'
              : '';
          sb.writeln(
            '  - ${inst.title} ($cardName): cuota ${fmt.format(inst.monthlyPayment)}/mes | ${inst.paidInstallments}/${inst.totalInstallments} cuotas pagadas | pendiente aprox. ${fmt.format(remainingAmount)}$teaStr',
          );
        }
      }

      // ── 8. Viajes ───────────────────────────────────────────────────────────
      if (travels.isNotEmpty) {
        sb.writeln('\n=== VIAJES ===');
        for (final tr in travels.take(5)) {
          final travelSpent = allTxs
              .where((t) => t.contextId == tr.id && t.type == 'expense')
              .fold<double>(
                0.0,
                (sum, t) =>
                    sum + TextSearchHelper.convertToPen(t.amount, t.currency, rates),
              );
          final status = tr.isActive ? 'ACTIVO' : 'Inactivo';
          sb.writeln(
            '  - ${tr.name} [$status]: gastado ${fmt.format(travelSpent)} / presupuesto ${fmt.format(tr.budget)} (${DateFormat('dd/MM').format(tr.startDate)} - ${DateFormat('dd/MM/yyyy').format(tr.endDate)})',
          );
        }
      }

      // ── 9. Búsqueda dinámica en TODO el historial para la pregunta actual ───
      if (userQuery != null && userQuery.trim().isNotEmpty && allTxs.isNotEmpty) {
        final queryMatches = _findQueryMatches(
          userQuery: userQuery,
          now: now,
          allTxs: allTxs,
          catMap: catMap,
          subMap: subMap,
          accMap: accMap,
        );
        if (queryMatches.isNotEmpty) {
          double matchExpense = 0;
          double matchIncome = 0;
          for (final tx in queryMatches) {
            final amt = TextSearchHelper.convertToPen(
              tx.amount,
              tx.currency,
              rates,
            );
            if (tx.type == 'expense') matchExpense += amt;
            if (tx.type == 'income') matchIncome += amt;
          }
          sb.writeln('\n=== COINCIDENCIAS HISTÓRICAS PARA LA PREGUNTA ===');
          sb.writeln(
            'Total movimientos coincidentes encontrados en historial: ${queryMatches.length} | Suma gastos: ${fmt.format(matchExpense)} | Suma ingresos: ${fmt.format(matchIncome)}',
          );
          for (final tx in queryMatches.take(20)) {
            sb.writeln(
              '  - ${_formatTxLine(tx, catMap, subMap, accMap, fmt)}',
            );
          }
        }
      }

      // ── 10. Movimientos más recientes ───────────────────────────────────────
      final recentSource = currentMonthTxs.isNotEmpty ? currentMonthTxs : allTxs;
      if (recentSource.isNotEmpty) {
        sb.writeln('\n=== ÚLTIMOS MOVIMIENTOS REGISTRADOS ===');
        for (final tx in recentSource.take(15)) {
          sb.writeln('  - ${_formatTxLine(tx, catMap, subMap, accMap, fmt)}');
        }
      } else {
        sb.writeln(
          '\nNota: El usuario aún no tiene transacciones registradas en la base de datos.',
        );
      }

      // Limpiar referencias sin usar
      assert(startCurrentMonth.isBefore(endCurrentMonth));
      assert(startPrevMonth.isBefore(endPrevMonth));

      return sb.toString();
    } catch (e, st) {
      debugPrint('[FinancialContextBuilder] Error construyendo contexto: $e\n$st');
      return 'No se pudo cargar el detalle financiero completo por un error interno ($e).';
    }
  }

  String _formatTxLine(
    Transaction tx,
    Map<String, Category> catMap,
    Map<String, Subcategory> subMap,
    Map<String, Account> accMap,
    NumberFormat fmt,
  ) {
    final catName = tx.categoryId != null
        ? (catMap[tx.categoryId]?.name ?? 'Varios')
        : 'Varios';
    final subName = tx.subcategoryId != null
        ? subMap[tx.subcategoryId]?.name
        : null;
    final accName = accMap[tx.accountId]?.name ?? 'Cuenta';
    final catDisplay = subName != null ? '$catName > $subName' : catName;

    final sign = tx.type == 'expense'
        ? '-'
        : tx.type == 'income'
        ? '+'
        : '⇄';
    final sym = TextSearchHelper.currencySymbol(tx.currency);
    final amountStr = tx.currency == 'PEN'
        ? fmt.format(tx.amount)
        : '$sym ${tx.amount.toStringAsFixed(2)}';

    final detailParts = <String>[
      if (tx.productName != null && tx.productName!.trim().isNotEmpty)
        tx.productName!.trim(),
      if (tx.description != null && tx.description!.trim().isNotEmpty)
        tx.description!.trim(),
    ];
    final detail = detailParts.isNotEmpty
        ? detailParts.join(' / ')
        : 'Sin detalle';

    return '${DateFormat('dd/MM/yyyy').format(tx.date)}: $sign$amountStr [$catDisplay | $accName] - $detail';
  }

  List<Transaction> _findQueryMatches({
    required String userQuery,
    required DateTime now,
    required List<Transaction> allTxs,
    required Map<String, Category> catMap,
    required Map<String, Subcategory> subMap,
    required Map<String, Account> accMap,
  }) {
    final normalized = TextSearchHelper.normalize(userQuery);
    final rawTokens = TextSearchHelper.tokenize(normalized);

    int? targetMonth;
    int? targetYear;
    if (normalized.contains('mes pasado') || normalized.contains('mes anterior')) {
      final prev = DateTime(now.year, now.month - 1, 1);
      targetMonth = prev.month;
      targetYear = prev.year;
    } else {
      for (final entry in _monthKeywords.entries) {
        if (rawTokens.contains(entry.key)) {
          targetMonth = entry.value;
          targetYear = entry.value > now.month ? now.year - 1 : now.year;
          break;
        }
      }
    }

    final keywords = rawTokens
        .where((t) =>
            t.length >= 3 &&
            !_stopWords.contains(t) &&
            !_monthKeywords.containsKey(t))
        .toList();

    if (keywords.isEmpty && targetMonth == null) return const [];

    return allTxs.where((tx) {
      if (targetMonth != null) {
        if (tx.date.month != targetMonth) return false;
        if (targetYear != null && tx.date.year != targetYear) return false;
      }
      if (keywords.isEmpty) return true;

      final cat = tx.categoryId != null ? catMap[tx.categoryId] : null;
      final sub = tx.subcategoryId != null ? subMap[tx.subcategoryId] : null;
      final acc = accMap[tx.accountId];
      final searchable = TextSearchHelper.normalize(
        [
          tx.productName,
          tx.description,
          tx.notes,
          tx.locationName,
          cat?.name,
          cat?.aliases,
          sub?.name,
          acc?.name,
        ].whereType<String>().join(' '),
      );

      // Coincide si al menos una palabra clave relevante aparece en la transacción
      return keywords.any((k) => searchable.contains(k));
    }).toList();
  }
}

final financialContextBuilderProvider = Provider<FinancialContextBuilder>((ref) {
  final db = ref.watch(databaseProvider);
  return FinancialContextBuilder(
    transactionsDao: db.transactionsDao,
    accountsDao: db.accountsDao,
    categoriesDao: db.categoriesDao,
    subcategoriesDao: db.subcategoriesDao,
    budgetsDao: db.budgetsDao,
    savingsGoalsDao: db.savingsGoalsDao,
    recurringPaymentsDao: db.recurringPaymentsDao,
    creditInstallmentsDao: db.creditInstallmentsDao,
    travelsDao: db.travelsDao,
  );
});

