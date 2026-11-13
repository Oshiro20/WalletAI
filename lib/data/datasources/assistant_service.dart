import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/text_search_helper.dart';
import '../../presentation/providers/database_providers.dart';
import '../database/daos/accounts_dao.dart';
import '../database/daos/budgets_dao.dart';
import '../database/daos/categories_dao.dart';
import '../database/daos/credit_installments_dao.dart';
import '../database/daos/recurring_payments_dao.dart';
import '../database/daos/savings_goals_dao.dart';
import '../database/daos/transactions_dao.dart';
import '../database/drift_database.dart';
import 'currency_service.dart';

/// Modelo de mensaje de chat
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

/// Servicio local del Asistente — responde preguntas en base a los datos reales
/// almacenados en Drift (usado como respaldo offline / cuando el servidor IA no responde).
class AssistantService {
  final TransactionsDao _transactionsDao;
  final AccountsDao _accountsDao;
  final CategoriesDao _categoriesDao;
  final BudgetsDao _budgetsDao;
  final SavingsGoalsDao? _savingsGoalsDao;
  final RecurringPaymentsDao? _recurringPaymentsDao;
  final CreditInstallmentsDao? _creditInstallmentsDao;
  final CurrencyService _currencyService;

  AssistantService({
    required TransactionsDao transactionsDao,
    required AccountsDao accountsDao,
    required CategoriesDao categoriesDao,
    required BudgetsDao budgetsDao,
    SavingsGoalsDao? savingsGoalsDao,
    RecurringPaymentsDao? recurringPaymentsDao,
    CreditInstallmentsDao? creditInstallmentsDao,
    CurrencyService? currencyService,
  }) : _transactionsDao = transactionsDao,
       _accountsDao = accountsDao,
       _categoriesDao = categoriesDao,
       _budgetsDao = budgetsDao,
       _savingsGoalsDao = savingsGoalsDao,
       _recurringPaymentsDao = recurringPaymentsDao,
       _creditInstallmentsDao = creditInstallmentsDao,
       _currencyService = currencyService ?? CurrencyService();

  Future<Map<String, double>> _safeRates() async {
    try {
      return await _currencyService.getRatesBasePEN().timeout(
        const Duration(seconds: 2),
        onTimeout: () => const {'PEN': 1.0},
      );
    } catch (_) {
      return const {'PEN': 1.0};
    }
  }

  /// Procesa la pregunta del usuario y devuelve una respuesta basada en datos reales.
  Future<String> processQuestion(String question) async {
    final q = TextSearchHelper.normalize(question);

    try {
      // ── Cuotas / Tarjetas de crédito ────────────────────────────────────
      if (_matches(q, ['cuota', 'cuotas', 'tarjeta', 'deuda', 'deudas'])) {
        return await _getDeudasYCuotasResponse();
      }

      // ── Metas de ahorro ─────────────────────────────────────────────────
      if (_matches(q, ['meta', 'metas', 'objetivo'])) {
        return await _getMetasResponse();
      }

      // ── Pagos recurrentes / suscripciones ───────────────────────────────
      if (_matches(q, [
        'recurrente',
        'recurrentes',
        'suscripcion',
        'suscripciones',
        'pago fijo',
        'pagos fijos',
        'proximo pago',
      ])) {
        return await _getRecurrentesResponse();
      }

      // ── Saldo / disponible ──────────────────────────────────────────────
      if (_matches(q, [
        'cuanto tengo',
        'saldo',
        'disponible',
        'balance',
        'cuentas',
        'patrimonio',
      ])) {
        return await _getSaldoResponse();
      }

      // ── Mes pasado / comparativa ────────────────────────────────────────
      if (_matches(q, ['mes pasado', 'mes anterior', 'compara', 'comparativa'])) {
        return await _getComparativaMesesResponse();
      }

      // ── Gastos del mes ──────────────────────────────────────────────────
      if (_matches(q, [
        'gaste este mes',
        'gastos del mes',
        'gaste en el mes',
        'analiza mis gastos',
        'resumen del mes',
        'resumen',
      ])) {
        return await _getGastosMesResponse();
      }

      // ── Gastos de esta semana ───────────────────────────────────────────
      if (_matches(q, [
        'gaste esta semana',
        'gastos de la semana',
        'esta semana',
      ])) {
        return await _getGastosSemanaResponse();
      }

      // ── Ingresos del mes ────────────────────────────────────────────────
      if (_matches(q, ['ingrese', 'ingresos', 'gane', 'sueldo'])) {
        return await _getIngresosMesResponse();
      }

      // ── Categoría donde más gasto ───────────────────────────────────────
      if (_matches(q, [
        'categoria',
        'categorias',
        'mas gasto',
        'donde gasto',
        'en que gasto',
      ])) {
        return await _getTopCategoriaResponse();
      }

      // ── Últimos gastos / transacciones recientes ────────────────────────
      if (_matches(q, [
        'ultimos gastos',
        'ultimas transacciones',
        'recientes',
        'ultimos movimientos',
        'movimientos',
      ])) {
        return await _getUltimosGastosResponse();
      }

      // ── Presupuestos ────────────────────────────────────────────────────
      if (_matches(q, ['presupuesto', 'presupuestos', 'limite', 'como van'])) {
        return await _getPresupuestosResponse();
      }

      // ── Ahorros / cuánto puedo ahorrar ──────────────────────────────────
      if (_matches(q, ['ahorrar', 'ahorro', 'tasa de ahorro'])) {
        return await _getAhorroResponse();
      }

      // ── Coincidencia dinámica con cualquier categoría o producto/comercio ──
      final dynamicMatch = await _tryDynamicCategoryOrProductMatch(q);
      if (dynamicMatch != null) {
        return dynamicMatch;
      }

      // ── Ayuda ───────────────────────────────────────────────────────────
      if (_matches(q, ['ayuda', 'help', 'que puedes', 'que haces'])) {
        return _getAyudaResponse();
      }

      // ── Saludo ──────────────────────────────────────────────────────────
      if (_matches(q, ['hola', 'buenos dias', 'buenas tardes', 'buenas noches'])) {
        return await _getResumenRapidoSaludo();
      }

      // ── Resumen con datos reales si la pregunta es abierta ──────────────
      return await _getFallbackConResumen();
    } catch (_) {
      return '❌ Ocurrió un error al consultar tus datos locales. Intenta de nuevo.';
    }
  }

  bool _matches(String query, List<String> keywords) {
    return keywords.any((k) => query.contains(k));
  }

  // ──────────────────────────────────────────────────────────────────
  // Respuestas con datos reales
  // ──────────────────────────────────────────────────────────────────

  Future<String> _getResumenRapidoSaludo() async {
    final rates = await _safeRates();
    final accounts = await _accountsDao.getAllAccounts();
    double liquid = 0;
    for (final acc in accounts) {
      if (acc.type != 'credit_card') {
        liquid += TextSearchHelper.convertToPen(acc.balance, acc.currency, rates);
      }
    }
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final txs = await _transactionsDao.getTransactionsByDateRange(start, end);
    double monthExp = 0;
    for (final t in txs.where((t) => t.type == 'expense')) {
      monthExp += TextSearchHelper.convertToPen(t.amount, t.currency, rates);
    }

    return '¡Hola! 👋 Aquí tienes un vistazo rápido de tus finanzas hoy:\n\n'
        '💰 Saldo en cuentas: **S/ ${liquid.toStringAsFixed(2)}**\n'
        '🔴 Gastos de ${_monthName(now.month)}: **S/ ${monthExp.toStringAsFixed(2)}**\n\n'
        'Puedes preguntarme por tus categorías, presupuestos, metas, cuotas, pagos recurrentes o cualquier gasto específico.';
  }

  Future<String> _getSaldoResponse() async {
    final rates = await _safeRates();
    final accounts = await _accountsDao.getAllAccounts();
    if (accounts.isEmpty) {
      return '💰 No tienes cuentas registradas aún en la app.';
    }
    final buffer = StringBuffer('💰 **Tus cuentas actuales:**\n\n');
    double liquidTotal = 0;
    double debtTotal = 0;

    for (final acc in accounts) {
      final icon = acc.type == 'bank'
          ? '🏦'
          : acc.type == 'credit_card'
          ? '💳'
          : acc.type == 'savings' || acc.type == 'investment'
          ? '📈'
          : '💵';
      final sym = TextSearchHelper.currencySymbol(acc.currency);
      final penVal = TextSearchHelper.convertToPen(
        acc.balance,
        acc.currency,
        rates,
      );
      if (acc.type == 'credit_card') {
        final debt = penVal < 0 ? penVal.abs() : 0.0;
        debtTotal += debt;
        buffer.writeln(
          '$icon ${acc.name}: deuda $sym ${acc.balance < 0 ? acc.balance.abs().toStringAsFixed(2) : "0.00"}',
        );
      } else {
        liquidTotal += penVal;
        buffer.writeln(
          '$icon ${acc.name}: $sym ${acc.balance.toStringAsFixed(2)}',
        );
      }
    }
    buffer.writeln('\n**Disponible total (cuentas/efectivo): S/ ${liquidTotal.toStringAsFixed(2)}**');
    if (debtTotal > 0) {
      buffer.writeln('**Deuda total en tarjetas: S/ ${debtTotal.toStringAsFixed(2)}**');
    }
    return buffer.toString();
  }

  Future<String> _getGastosMesResponse() async {
    final rates = await _safeRates();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final txs = await _transactionsDao.getTransactionsByDateRange(start, end);

    double total = 0;
    double income = 0;
    for (final t in txs) {
      final amt = TextSearchHelper.convertToPen(t.amount, t.currency, rates);
      if (t.type == 'expense') total += amt;
      if (t.type == 'income') income += amt;
    }
    final balance = income - total;

    return '📊 **Resumen de ${_monthName(now.month)} (${txs.length} movimientos):**\n\n'
        '🔴 Gastos: S/ ${total.toStringAsFixed(2)}\n'
        '🟢 Ingresos: S/ ${income.toStringAsFixed(2)}\n'
        '${balance >= 0 ? "✅" : "⚠️"} Balance: S/ ${balance.toStringAsFixed(2)}';
  }

  Future<String> _getComparativaMesesResponse() async {
    final rates = await _safeRates();
    final now = DateTime.now();
    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final prevStart = DateTime(now.year, now.month - 1, 1);
    final prevEnd = DateTime(now.year, now.month, 0, 23, 59, 59);

    final curTxs = await _transactionsDao.getTransactionsByDateRange(
      curStart,
      curEnd,
    );
    final prevTxs = await _transactionsDao.getTransactionsByDateRange(
      prevStart,
      prevEnd,
    );

    double sumType(List<Transaction> list, String type) => list
        .where((t) => t.type == type)
        .fold(
          0.0,
          (s, t) =>
              s + TextSearchHelper.convertToPen(t.amount, t.currency, rates),
        );

    final curExp = sumType(curTxs, 'expense');
    final prevExp = sumType(prevTxs, 'expense');
    final curInc = sumType(curTxs, 'income');
    final prevInc = sumType(prevTxs, 'income');

    final diff = curExp - prevExp;
    final pctStr = prevExp > 0
        ? ' (${(diff / prevExp * 100).toStringAsFixed(1)}%)'
        : '';

    return '📊 **Comparativa mensual:**\n\n'
        '• **${_monthName(now.month)}:** Gastos S/ ${curExp.toStringAsFixed(2)} | Ingresos S/ ${curInc.toStringAsFixed(2)}\n'
        '• **${_monthName(prevStart.month)}:** Gastos S/ ${prevExp.toStringAsFixed(2)} | Ingresos S/ ${prevInc.toStringAsFixed(2)}\n\n'
        '${diff <= 0 ? "📉" : "📈"} Diferencia en gastos: ${diff >= 0 ? "+" : ""}S/ ${diff.toStringAsFixed(2)}$pctStr';
  }

  Future<String> _getGastosSemanaResponse() async {
    final rates = await _safeRates();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(
      startOfWeek.year,
      startOfWeek.month,
      startOfWeek.day,
    );
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final txs = await _transactionsDao.getTransactionsByDateRange(start, end);
    double total = 0;
    for (final t in txs.where((t) => t.type == 'expense')) {
      total += TextSearchHelper.convertToPen(t.amount, t.currency, rates);
    }

    return '📅 **Esta semana** (lun–hoy):\n\n'
        '🔴 Gastos: S/ ${total.toStringAsFixed(2)}\n'
        '📆 Promedio diario: S/ ${(total / now.weekday).toStringAsFixed(2)}';
  }

  Future<String> _getIngresosMesResponse() async {
    final rates = await _safeRates();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final txs = await _transactionsDao.getTransactionsByDateRange(start, end);
    double total = 0;
    for (final t in txs.where((t) => t.type == 'income')) {
      total += TextSearchHelper.convertToPen(t.amount, t.currency, rates);
    }

    return '🟢 **Ingresos de ${_monthName(now.month)}:**\n\nTotal: S/ ${total.toStringAsFixed(2)}';
  }

  Future<String> _getTopCategoriaResponse() async {
    final rates = await _safeRates();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final txs = await _transactionsDao.getTransactionsByDateRange(start, end);

    final byCategory = <String, double>{};
    for (final t in txs.where((t) => t.type == 'expense')) {
      final key = t.categoryId ?? 'sin_categoria';
      byCategory[key] =
          (byCategory[key] ?? 0) +
          TextSearchHelper.convertToPen(t.amount, t.currency, rates);
    }

    if (byCategory.isEmpty) {
      return '📁 No hay gastos por categoría registrados este mes.';
    }

    final categories = await _categoriesDao.getAllCategories();
    final catMap = {for (final c in categories) c.id: c};
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer('📁 **Gastos por categoría este mes:**\n\n');
    for (int i = 0; i < sorted.length && i < 6; i++) {
      final entry = sorted[i];
      final cat = catMap[entry.key];
      final icon = cat?.icon ?? '📦';
      final name = cat?.name ?? 'Otros';
      buffer.writeln(
        '${i + 1}. $icon $name: S/ ${entry.value.toStringAsFixed(2)}',
      );
    }

    final top = catMap[sorted.first.key];
    buffer.writeln(
      '\n🏆 **Mayor gasto: ${top?.icon ?? "📦"} ${top?.name ?? "Otros"}**',
    );
    return buffer.toString();
  }

  Future<String> _getUltimosGastosResponse() async {
    final txns = await _transactionsDao.getTransactionsByType(
      'expense',
      limit: 6,
    );
    if (txns.isEmpty) {
      return '📋 No tienes gastos registrados aún.';
    }

    final buffer = StringBuffer('📋 **Últimos ${txns.length} gastos:**\n\n');
    for (final t in txns) {
      final fecha = '${t.date.day}/${t.date.month}';
      final label = (t.productName != null && t.productName!.trim().isNotEmpty)
          ? t.productName!
          : (t.description ?? 'Sin descripción');
      final sym = TextSearchHelper.currencySymbol(t.currency);
      buffer.writeln('• $fecha — $sym ${t.amount.toStringAsFixed(2)} — $label');
    }
    return buffer.toString();
  }

  Future<String> _getPresupuestosResponse() async {
    final rates = await _safeRates();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final budgets = await _budgetsDao.getActiveBudgets();

    if (budgets.isEmpty) {
      return '📊 No tienes presupuestos configurados. Ve a "Presupuestos" para crear uno.';
    }

    final categories = await _categoriesDao.getAllCategories();
    final catMap = {for (final c in categories) c.id: c};
    final txs = await _transactionsDao.getTransactionsByDateRange(start, end);
    final byCategory = <String, double>{};
    for (final t in txs.where((t) => t.type == 'expense' && t.categoryId != null)) {
      byCategory[t.categoryId!] =
          (byCategory[t.categoryId!] ?? 0) +
          TextSearchHelper.convertToPen(t.amount, t.currency, rates);
    }

    final buffer = StringBuffer(
      '📊 **Estado de presupuestos (${_monthName(now.month)}):**\n\n',
    );
    for (final b in budgets) {
      final cat = catMap[b.categoryId];
      final spent = byCategory[b.categoryId] ?? 0;
      final pct = b.amount > 0 ? (spent / b.amount * 100).round() : 0;
      final emoji = pct >= 100
          ? '🔴'
          : pct >= 80
          ? '🟡'
          : '🟢';
      final name = cat?.name ?? b.categoryId;
      buffer.writeln(
        '$emoji $name: S/ ${spent.toStringAsFixed(2)} / S/ ${b.amount.toStringAsFixed(2)} ($pct%)',
      );
    }
    return buffer.toString();
  }

  Future<String> _getMetasResponse() async {
    if (_savingsGoalsDao == null) {
      return '🚩 No se pudo consultar tus metas de ahorro en este momento.';
    }
    final goals = await _savingsGoalsDao.getActiveGoals();
    if (goals.isEmpty) {
      return '🚩 No tienes metas de ahorro activas actualmente.';
    }
    final buffer = StringBuffer('🚩 **Tus metas de ahorro activas:**\n\n');
    for (final g in goals) {
      final pct = g.targetAmount > 0
          ? (g.currentAmount / g.targetAmount * 100).toStringAsFixed(0)
          : '0';
      buffer.writeln(
        '• ${g.name}: S/ ${g.currentAmount.toStringAsFixed(2)} / S/ ${g.targetAmount.toStringAsFixed(2)} ($pct%)',
      );
    }
    return buffer.toString();
  }

  Future<String> _getRecurrentesResponse() async {
    if (_recurringPaymentsDao == null) {
      return '🔁 No se pudo consultar tus pagos recurrentes en este momento.';
    }
    final list = await _recurringPaymentsDao.getAllRecurringPayments();
    if (list.isEmpty) {
      return '🔁 No tienes pagos recurrentes o suscripciones activas.';
    }
    final buffer = StringBuffer('🔁 **Pagos recurrentes activos:**\n\n');
    for (final r in list) {
      final fecha = '${r.nextDueDate.day}/${r.nextDueDate.month}/${r.nextDueDate.year}';
      buffer.writeln(
        '• ${r.name}: S/ ${r.amount.toStringAsFixed(2)} (${r.frequency}) — próx: $fecha',
      );
    }
    return buffer.toString();
  }

  Future<String> _getDeudasYCuotasResponse() async {
    final accounts = await _accountsDao.getAllAccounts();
    final cards = accounts.where((a) => a.type == 'credit_card').toList();
    final installments = _creditInstallmentsDao != null
        ? (await _creditInstallmentsDao.getAllInstallments())
              .where((c) => c.status == 'active')
              .toList()
        : <CreditInstallment>[];

    if (cards.isEmpty && installments.isEmpty) {
      return '💳 No tienes tarjetas de crédito ni compras en cuotas registradas.';
    }

    final buffer = StringBuffer('💳 **Resumen de tarjetas y cuotas:**\n\n');
    for (final c in cards) {
      final debt = c.balance < 0 ? c.balance.abs() : 0.0;
      buffer.writeln('• ${c.name}: deuda S/ ${debt.toStringAsFixed(2)}');
    }
    if (installments.isNotEmpty) {
      buffer.writeln('\n📌 **Cuotas activas:**');
      for (final inst in installments) {
        buffer.writeln(
          '• ${inst.title}: S/ ${inst.monthlyPayment.toStringAsFixed(2)}/mes (${inst.paidInstallments}/${inst.totalInstallments} pagadas)',
        );
      }
    }
    return buffer.toString();
  }

  Future<String> _getAhorroResponse() async {
    final rates = await _safeRates();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final txs = await _transactionsDao.getTransactionsByDateRange(start, end);

    double income = 0;
    double expense = 0;
    for (final t in txs) {
      final amt = TextSearchHelper.convertToPen(t.amount, t.currency, rates);
      if (t.type == 'income') income += amt;
      if (t.type == 'expense') expense += amt;
    }

    final ahorro = income - expense;
    final pct = income > 0 ? (ahorro / income * 100).round() : 0;

    if (income == 0) {
      return '💡 No tienes ingresos registrados este mes (gastos actuales: S/ ${expense.toStringAsFixed(2)}).';
    }

    final emoji = pct >= 20
        ? '🎯'
        : pct > 0
        ? '💡'
        : '⚠️';
    final mensaje = pct >= 20
        ? '¡Excelente! Estás ahorrando bien este mes.'
        : pct > 0
        ? 'Puedes mejorar tu tasa de ahorro reduciendo gastos.'
        : 'Tus gastos superan tus ingresos este mes. ¡Atención!';

    return '$emoji **Análisis de ahorro (${_monthName(now.month)}):**\n\n'
        '🟢 Ingresos: S/ ${income.toStringAsFixed(2)}\n'
        '🔴 Gastos: S/ ${expense.toStringAsFixed(2)}\n'
        '💰 Balance/Ahorro: S/ ${ahorro.toStringAsFixed(2)} ($pct%)\n\n'
        '$mensaje';
  }

  Future<String?> _tryDynamicCategoryOrProductMatch(String normalizedQuery) async {
    final rates = await _safeRates();
    final categories = await _categoriesDao.getAllCategories();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    Future<String> formatCategoryTotal(Category cat) async {
      final txs = await _transactionsDao.getTransactionsByDateRange(start, end);
      double total = 0;
      int count = 0;
      for (final t in txs) {
        if (t.categoryId == cat.id) {
          total += TextSearchHelper.convertToPen(t.amount, t.currency, rates);
          count++;
        }
      }
      if (count == 0) {
        return '📁 No tienes movimientos en **${cat.name}** este mes (${_monthName(now.month)}).';
      }
      return '📁 **${cat.name} en ${_monthName(now.month)}:**\n\n'
          'Total ($count movs): **S/ ${total.toStringAsFixed(2)}**';
    }

    // 1. Coincidencia directa por nombre de categoría real de la BD
    for (final cat in categories) {
      final catNorm = TextSearchHelper.normalize(cat.name);
      if (catNorm.length >= 3 && normalizedQuery.contains(catNorm)) {
        return formatCategoryTotal(cat);
      }
    }

    // 2. Buscar palabras clave en productName / description / notes del historial
    final tokens = TextSearchHelper.tokenize(normalizedQuery)
        .where((t) =>
            t.length >= 4 &&
            !{
              'cuanto',
              'gaste',
              'gasto',
              'gastos',
              'ingrese',
              'dinero',
              'soles',
              'tengo',
              'sobre',
              'dime',
              'muestrame',
              'cuales',
              'donde',
              'cuando',
              'compre',
            }.contains(t))
        .toList();

    if (tokens.isNotEmpty) {
      final allTxs = await _transactionsDao.getAllTransactions(limit: 2000);
      final matches = allTxs.where((t) {
        final text = TextSearchHelper.normalize(
          '${t.productName ?? ''} ${t.description ?? ''} ${t.notes ?? ''}',
        );
        return tokens.any((tok) => text.contains(tok));
      }).toList();

      if (matches.isNotEmpty) {
        double total = 0;
        for (final t in matches) {
          total += TextSearchHelper.convertToPen(t.amount, t.currency, rates);
        }

        final buffer = StringBuffer(
          '🔍 **Encontré ${matches.length} movimientos relacionados** (total: **S/ ${total.toStringAsFixed(2)}**):\n\n',
        );
        for (final t in matches.take(5)) {
          final fecha = '${t.date.day}/${t.date.month}/${t.date.year}';
          final title = (t.productName != null && t.productName!.trim().isNotEmpty)
              ? t.productName!
              : (t.description ?? 'Sin detalle');
          buffer.writeln('• $fecha — S/ ${t.amount.toStringAsFixed(2)} — $title');
        }
        return buffer.toString();
      }
    }

    // 3. Fallback por aliases de categoría
    for (final cat in categories) {
      final aliasesNorm = cat.aliases != null
          ? TextSearchHelper.normalize(cat.aliases!)
          : '';
      if (aliasesNorm.isNotEmpty &&
          aliasesNorm.split(',').any((a) {
            final al = a.trim();
            return al.length >= 3 && normalizedQuery.contains(al);
          })) {
        return formatCategoryTotal(cat);
      }
    }

    return null;
  }

  Future<String> _getFallbackConResumen() async {
    final gastosMes = await _getGastosMesResponse();
    return '$gastosMes\n\n💡 _Modo sin conexión / respaldo local. Puedes preguntarme por tus cuentas, deudas, categorías, presupuestos, metas o pagos recurrentes._';
  }

  String _getAyudaResponse() {
    return '🤖 **¿En qué puedo ayudarte con tus datos?**\n\n'
        '💰 *"¿Cuál es mi saldo y mis deudas?"*\n'
        '📊 *"¿Cuánto gasté este mes?"*\n'
        '📉 *"Compara mis gastos con el mes pasado"*\n'
        '📁 *"¿En qué categoría gasto más?"*\n'
        '📈 *"¿Cómo van mis presupuestos y metas?"*\n'
        '💳 *"¿Qué cuotas o tarjetas tengo activas?"*\n'
        '🔁 *"¿Cuáles son mis pagos recurrentes?"*';
  }

  String _monthName(int month) {
    const names = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return names[month];
  }
}

/// Provider del AssistantService
final assistantServiceProvider = Provider<AssistantService>((ref) {
  final db = ref.watch(databaseProvider);
  return AssistantService(
    transactionsDao: db.transactionsDao,
    accountsDao: db.accountsDao,
    categoriesDao: db.categoriesDao,
    budgetsDao: db.budgetsDao,
    savingsGoalsDao: db.savingsGoalsDao,
    recurringPaymentsDao: db.recurringPaymentsDao,
    creditInstallmentsDao: db.creditInstallmentsDao,
  );
});
