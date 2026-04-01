import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/daos/transactions_dao.dart';
import '../database/daos/accounts_dao.dart';
import '../database/daos/categories_dao.dart';
import '../database/daos/budgets_dao.dart';
import '../../presentation/providers/database_providers.dart';

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

/// Servicio del Asistente IA — responde preguntas en base a los datos reales
class AssistantService {
  final TransactionsDao _transactionsDao;
  final AccountsDao _accountsDao;
  final CategoriesDao _categoriesDao;
  final BudgetsDao _budgetsDao;

  AssistantService({
    required TransactionsDao transactionsDao,
    required AccountsDao accountsDao,
    required CategoriesDao categoriesDao,
    required BudgetsDao budgetsDao,
  })  : _transactionsDao = transactionsDao,
        _accountsDao = accountsDao,
        _categoriesDao = categoriesDao,
        _budgetsDao = budgetsDao;

  /// Procesa la pregunta del usuario y devuelve una respuesta
  Future<String> processQuestion(String question) async {
    final q = question.toLowerCase().trim();

    try {
      // ── Saldo / disponible ─────────────────────────────────────────────
      if (_matches(q, ['cuánto tengo', 'saldo', 'disponible', 'cuanto tengo', 'balance'])) {
        return await _getSaldoResponse();
      }

      // ── Gastos del mes ─────────────────────────────────────────────────
      if (_matches(q, ['gasté este mes', 'gaste este mes', 'gastos del mes', 'gasté en el mes'])) {
        return await _getGastosMesResponse();
      }

      // ── Gastos de esta semana ──────────────────────────────────────────
      if (_matches(q, ['gasté esta semana', 'gaste esta semana', 'gastos de la semana', 'esta semana'])) {
        return await _getGastosSemanResponse();
      }

      // ── Ingresos del mes ───────────────────────────────────────────────
      if (_matches(q, ['ingresé', 'ingresos', 'gané', 'gane', 'cuánto ingresé'])) {
        return await _getIngresosMesResponse();
      }

      // ── Categoría donde más gasto ──────────────────────────────────────
      if (_matches(q, ['categoría', 'categoria', 'más gasto', 'mas gasto', 'dónde gasto', 'donde gasto'])) {
        return await _getTopCategoriaResponse();
      }

      // ── Últimos gastos / transacciones recientes ───────────────────────
      if (_matches(q, ['últimos gastos', 'ultimos gastos', 'últimas transacciones', 'recientes', 'últimos movimientos'])) {
        return await _getUltimosGastosResponse();
      }

      // ── Presupuestos ───────────────────────────────────────────────────
      if (_matches(q, ['presupuesto', 'presupuestos', 'límite', 'limite', 'cómo van', 'como van'])) {
        return await _getPresupuestosResponse();
      }

      // ── Ahorros / cuánto puedo ahorrar ────────────────────────────────
      if (_matches(q, ['ahorrar', 'ahorro', 'puedo ahorrar', 'tasa de ahorro'])) {
        return await _getAhorroResponse();
      }

      // ── Gastos por categoría específica ────────────────────────────────
      if (_matches(q, ['comida', 'alimentación', 'alimentacion', 'restaurante'])) {
        return await _getGastosPorCategoria('cat_alimentacion', 'Alimentación');
      }
      if (_matches(q, ['transporte', 'taxi', 'uber', 'bus'])) {
        return await _getGastosPorCategoria('cat_transporte', 'Transporte');
      }
      if (_matches(q, ['entretenimiento', 'ocio', 'diversión', 'diversion'])) {
        return await _getGastosPorCategoria('cat_entretenimiento', 'Entretenimiento');
      }
      if (_matches(q, ['salud', 'medicina', 'médico', 'medico', 'farmacia'])) {
        return await _getGastosPorCategoria('cat_salud', 'Salud');
      }

      // ── Ayuda ──────────────────────────────────────────────────────────
      if (_matches(q, ['ayuda', 'help', 'qué puedes', 'que puedes', 'qué haces', 'que haces'])) {
        return _getAyudaResponse();
      }

      // ── Saludo ─────────────────────────────────────────────────────────
      if (_matches(q, ['hola', 'buenos días', 'buenas tardes', 'buenas noches', 'hi', 'hey'])) {
        return '¡Hola! 👋 Soy tu asistente financiero. Puedo ayudarte con información sobre tus gastos, ingresos, saldo y presupuestos.\n\nPrueba preguntarme:\n• *"¿Cuánto gasté este mes?"*\n• *"¿Cuánto tengo disponible?"*\n• *"¿En qué categoría gasto más?"*';
      }

      // ── Respuesta por defecto ──────────────────────────────────────────
      return '🤔 No entendí tu pregunta. Puedes preguntarme cosas como:\n\n• *"¿Cuánto gasté este mes?"*\n• *"¿Cuánto tengo disponible?"*\n• *"¿En qué categoría gasto más?"*\n• *"Muéstrame los últimos gastos"*\n• *"¿Cómo van mis presupuestos?"*\n• *"¿Cuánto puedo ahorrar?"*';
    } catch (e) {
      return '❌ Ocurrió un error al consultar tus datos. Intenta de nuevo.';
    }
  }

  bool _matches(String query, List<String> keywords) {
    return keywords.any((k) => query.contains(k));
  }

  // ──────────────────────────────────────────────────────────────────
  // Respuestas
  // ──────────────────────────────────────────────────────────────────

  Future<String> _getSaldoResponse() async {
    final accounts = await _accountsDao.getAllAccounts();
    final total = await _accountsDao.getTotalBalance();
    if (accounts.isEmpty) {
      return '💰 No tienes cuentas registradas aún.';
    }
    final buffer = StringBuffer('💰 **Saldo actual:**\n\n');
    for (final acc in accounts) {
      final icon = acc.type == 'bank' ? '🏦' : acc.type == 'credit' ? '💳' : '💵';
      buffer.writeln('$icon ${acc.name}: S/ ${acc.balance.toStringAsFixed(2)}');
    }
    buffer.writeln('\n**Total disponible: S/ ${total.toStringAsFixed(2)}**');
    return buffer.toString();
  }

  Future<String> _getGastosMesResponse() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final total = await _transactionsDao.getTotalExpenses(start, end);
    final income = await _transactionsDao.getTotalIncome(start, end);
    final balance = income - total;

    return '📊 **Resumen de ${_monthName(now.month)}:**\n\n'
        '🔴 Gastos: S/ ${total.toStringAsFixed(2)}\n'
        '🟢 Ingresos: S/ ${income.toStringAsFixed(2)}\n'
        '${balance >= 0 ? "✅" : "⚠️"} Balance: S/ ${balance.toStringAsFixed(2)}';
  }

  Future<String> _getGastosSemanResponse() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final total = await _transactionsDao.getTotalExpenses(start, end);

    return '📅 **Esta semana** (lun–hoy):\n\n'
        '🔴 Gastos: S/ ${total.toStringAsFixed(2)}\n'
        '📆 Promedio diario: S/ ${(total / now.weekday).toStringAsFixed(2)}';
  }

  Future<String> _getIngresosMesResponse() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final total = await _transactionsDao.getTotalIncome(start, end);

    return '🟢 **Ingresos de ${_monthName(now.month)}:**\n\nTotal: S/ ${total.toStringAsFixed(2)}';
  }

  Future<String> _getTopCategoriaResponse() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final byCategory = await _transactionsDao.getExpensesByCategory(start, end);

    if (byCategory.isEmpty) {
      return '📁 No hay gastos por categoría registrados este mes.';
    }

    final categories = await _categoriesDao.getAllCategories();
    final catMap = {for (var c in categories) c.id: c};

    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final buffer = StringBuffer('📁 **Gastos por categoría este mes:**\n\n');
    for (int i = 0; i < sorted.length && i < 5; i++) {
      final entry = sorted[i];
      final cat = catMap[entry.key];
      final icon = cat?.icon ?? '📦';
      final name = cat?.name ?? entry.key;
      buffer.writeln('${i + 1}. $icon $name: S/ ${entry.value.toStringAsFixed(2)}');
    }

    final top = catMap[sorted.first.key];
    buffer.writeln('\n🏆 **Mayor gasto: ${top?.icon ?? "📦"} ${top?.name ?? sorted.first.key}**');
    return buffer.toString();
  }

  Future<String> _getUltimosGastosResponse() async {
    final txns = await _transactionsDao.getTransactionsByType('expense', limit: 5);
    if (txns.isEmpty) {
      return '📋 No tienes gastos registrados aún.';
    }

    final buffer = StringBuffer('📋 **Últimos 5 gastos:**\n\n');
    for (final t in txns) {
      final fecha = '${t.date.day}/${t.date.month}';
      final desc = t.description ?? 'Sin descripción';
      buffer.writeln('• $fecha — S/ ${t.amount.toStringAsFixed(2)} — $desc');
    }
    return buffer.toString();
  }

  Future<String> _getPresupuestosResponse() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final budgets = await _budgetsDao.getActiveBudgets();

    if (budgets.isEmpty) {
      return '📊 No tienes presupuestos configurados. Ve a "Presupuestos" para crear uno.';
    }

    final categories = await _categoriesDao.getAllCategories();
    final catMap = {for (var c in categories) c.id: c};
    final byCategory = await _transactionsDao.getExpensesByCategory(start, end);

    final buffer = StringBuffer('📊 **Estado de presupuestos (${_monthName(now.month)}):**\n\n');
    for (final b in budgets) {
      final cat = catMap[b.categoryId];
      final spent = byCategory[b.categoryId] ?? 0;
      final pct = b.amount > 0 ? (spent / b.amount * 100).round() : 0;
      final emoji = pct >= 100 ? '🔴' : pct >= 80 ? '🟡' : '🟢';
      final name = cat?.name ?? b.categoryId;
      buffer.writeln('$emoji $name: S/ ${spent.toStringAsFixed(2)} / S/ ${b.amount.toStringAsFixed(2)} ($pct%)');
    }
    return buffer.toString();
  }

  Future<String> _getAhorroResponse() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final income = await _transactionsDao.getTotalIncome(start, end);
    final expense = await _transactionsDao.getTotalExpenses(start, end);
    final ahorro = income - expense;
    final pct = income > 0 ? (ahorro / income * 100).round() : 0;

    if (income == 0) {
      return '💡 No tienes ingresos registrados aún este mes.';
    }

    String emoji = pct >= 20 ? '🎯' : pct > 0 ? '💡' : '⚠️';
    String mensaje = pct >= 20
        ? '¡Excelente! Estás ahorrando bien este mes.'
        : pct > 0
            ? 'Puedes mejorar tu tasa de ahorro reduciendo gastos.'
            : 'Tus gastos superan tus ingresos este mes. ¡Atención!';

    return '$emoji **Análisis de ahorro (${_monthName(now.month)}):**\n\n'
        '🟢 Ingresos: S/ ${income.toStringAsFixed(2)}\n'
        '🔴 Gastos: S/ ${expense.toStringAsFixed(2)}\n'
        '💰 Ahorro: S/ ${ahorro.toStringAsFixed(2)} ($pct%)\n\n'
        '$mensaje';
  }

  Future<String> _getGastosPorCategoria(String categoryId, String categoryName) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final byCategory = await _transactionsDao.getExpensesByCategory(start, end);
    final total = byCategory[categoryId] ?? 0;

    if (total == 0) {
      return '📁 No tienes gastos en **$categoryName** este mes.';
    }

    return '📁 **$categoryName este mes:**\n\nTotal: S/ ${total.toStringAsFixed(2)}';
  }

  String _getAyudaResponse() {
    return '🤖 **¿En qué puedo ayudarte?**\n\n'
        'Puedo responder preguntas como:\n\n'
        '💰 *"¿Cuánto tengo disponible?"*\n'
        '📊 *"¿Cuánto gasté este mes?"*\n'
        '📅 *"¿Cuánto gasté esta semana?"*\n'
        '🟢 *"¿Cuánto ingresé este mes?"*\n'
        '📁 *"¿En qué categoría gasto más?"*\n'
        '📋 *"Muéstrame los últimos gastos"*\n'
        '📈 *"¿Cómo van mis presupuestos?"*\n'
        '💡 *"¿Cuánto puedo ahorrar?"*\n'
        '🍽️ *"¿Cuánto gasté en comida?"*\n'
        '🚗 *"¿Cuánto gasté en transporte?"*';
  }

  String _monthName(int month) {
    const names = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
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
  );
});
