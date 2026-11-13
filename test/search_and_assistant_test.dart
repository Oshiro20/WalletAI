import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:wallet_ai/core/services/financial_context_builder.dart';
import 'package:wallet_ai/core/utils/text_search_helper.dart';
import 'package:wallet_ai/data/database/drift_database.dart';
import 'package:wallet_ai/data/datasources/assistant_service.dart';
import 'package:wallet_ai/data/datasources/currency_service.dart';

class _FakeCurrencyService extends CurrencyService {
  @override
  Future<Map<String, double>> getRatesBasePEN() async {
    return const {'PEN': 1.0, 'USD': 0.27};
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_PE', null);
  });

  group('TextSearchHelper Tests', () {
    test('normaliza acentos y mayúsculas', () {
      expect(TextSearchHelper.normalize('Alimentación'), equals('alimentacion'));
      expect(TextSearchHelper.normalize('  Café  Con Ñoquis '), equals('cafe  con noquis'));
    });

    test('matchesAllTokens busca múltiples palabras entre distintos campos', () {
      final tokens = TextSearchHelper.tokenize('pollo mercado bcp');
      final matched = TextSearchHelper.matchesAllTokens(tokens, [
        'Pollo entero',
        'Mercado Central',
        'Alimentación',
        'Cuenta BCP',
      ]);
      expect(matched, isTrue);

      final notMatched = TextSearchHelper.matchesAllTokens(
        TextSearchHelper.tokenize('pollo interbank'),
        ['Pollo entero', 'Mercado Central', 'Cuenta BCP'],
      );
      expect(notMatched, isFalse);
    });

    test('convertToPen convierte monedas correctamente', () {
      final rates = {'PEN': 1.0, 'USD': 0.25};
      expect(TextSearchHelper.convertToPen(100, 'PEN', rates), equals(100.0));
      expect(TextSearchHelper.convertToPen(25, 'USD', rates), equals(100.0));
    });
  });

  group('FinancialContextBuilder & AssistantService Tests', () {
    late AppDatabase db;
    late FinancialContextBuilder contextBuilder;
    late AssistantService assistantService;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final fakeCurrency = _FakeCurrencyService();
      contextBuilder = FinancialContextBuilder(
        transactionsDao: db.transactionsDao,
        accountsDao: db.accountsDao,
        categoriesDao: db.categoriesDao,
        subcategoriesDao: db.subcategoriesDao,
        budgetsDao: db.budgetsDao,
        savingsGoalsDao: db.savingsGoalsDao,
        recurringPaymentsDao: db.recurringPaymentsDao,
        creditInstallmentsDao: db.creditInstallmentsDao,
        travelsDao: db.travelsDao,
        currencyService: fakeCurrency,
      );
      assistantService = AssistantService(
        transactionsDao: db.transactionsDao,
        accountsDao: db.accountsDao,
        categoriesDao: db.categoriesDao,
        budgetsDao: db.budgetsDao,
        savingsGoalsDao: db.savingsGoalsDao,
        recurringPaymentsDao: db.recurringPaymentsDao,
        creditInstallmentsDao: db.creditInstallmentsDao,
        currencyService: fakeCurrency,
      );

      final now = DateTime.now();

      await db.accountsDao.createAccount(
        AccountsCompanion.insert(
          id: 'acc_bcp',
          name: 'Cuenta BCP',
          type: 'bank',
          balance: const drift.Value(2500.0),
          createdAt: now,
          updatedAt: now,
        ),
      );
      await db.accountsDao.createAccount(
        AccountsCompanion.insert(
          id: 'acc_tc',
          name: 'Visa BBVA',
          type: 'credit_card',
          balance: const drift.Value(-600.0),
          creditLimit: const drift.Value(3000.0),
          tea: const drift.Value(55.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Insertar más de 25 transacciones para verificar que no se trunca el cálculo a 20
      for (int i = 1; i <= 25; i++) {
        await db.transactionsDao.createTransaction(
          TransactionsCompanion.insert(
            id: 'tx_$i',
            accountId: 'acc_bcp',
            type: 'expense',
            amount: 10.0,
            categoryId: const drift.Value('cat_alimentacion'),
            productName: drift.Value(i == 25 ? 'Uber Aeropuerto' : 'Menu diario $i'),
            description: const drift.Value('Restaurante Lima'),
            date: now.subtract(Duration(hours: i)),
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      await db.transactionsDao.createTransaction(
        TransactionsCompanion.insert(
          id: 'tx_inc',
          accountId: 'acc_bcp',
          type: 'income',
          amount: 4000.0,
          categoryId: const drift.Value('cat_salario'),
          description: const drift.Value('Sueldo mensual'),
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.budgetsDao.createBudget(
        BudgetsCompanion.insert(
          id: 'bud_food',
          categoryId: 'cat_alimentacion',
          amount: 500.0,
          period: 'monthly',
          startDate: DateTime(now.year, now.month, 1),
          createdAt: now,
        ),
      );

      await db.savingsGoalsDao.createGoal(
        SavingsGoalsCompanion.insert(
          id: 'goal_laptop',
          name: 'Laptop nueva',
          targetAmount: 3000.0,
          currentAmount: const drift.Value(1200.0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.recurringPaymentsDao.createRecurringPayment(
        RecurringPaymentsCompanion.insert(
          id: 'rec_netflix',
          name: 'Netflix',
          amount: 44.90,
          accountId: 'acc_tc',
          frequency: 'monthly',
          nextDueDate: now.add(const Duration(days: 5)),
          createdAt: now,
        ),
      );

      await db.creditInstallmentsDao.insertInstallment(
        CreditInstallmentsCompanion.insert(
          id: 'inst_tv',
          accountId: 'acc_tc',
          title: 'Televisor OLED',
          totalAmount: 2400.0,
          totalInstallments: 12,
          monthlyPayment: 200.0,
          purchaseDate: now,
          firstDueDate: now.add(const Duration(days: 20)),
          createdAt: now,
          updatedAt: now,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('incluye todas las entidades reales y total exacto >20 txs en el contexto', () async {
      final context = await contextBuilder.buildContext(
        userQuery: '¿Cuánto gasté en Uber?',
      );

      expect(context, contains('Cuenta BCP'));
      expect(context, contains('Visa BBVA'));
      expect(context, contains('S/ 250.00')); // 25 * 10 = 250 exactos (no truncado a 20)
      expect(context, contains('S/ 4,000.00'));
      expect(context, contains('gastado S/ 250.00 / límite S/ 500.00 (50%'));
      expect(context, contains('Laptop nueva: S/ 1,200.00 / S/ 3,000.00 (40%'));
      expect(context, contains('Netflix: S/ 44.90'));
      expect(context, contains('Televisor OLED'));
      expect(context, contains('Uber Aeropuerto'));
    });

    test('AssistantService offline responde usando datos reales de cuentas, metas, cuotas y búsqueda', () async {
      final saldoResp = await assistantService.processQuestion('¿Cuál es mi saldo?');
      expect(saldoResp, contains('Cuenta BCP'));
      expect(saldoResp, contains('2500.00'));

      final metasResp = await assistantService.processQuestion('¿Cómo van mis metas?');
      expect(metasResp, contains('Laptop nueva'));
      expect(metasResp, contains('40%'));

      final cuotasResp = await assistantService.processQuestion('¿Qué cuotas tengo?');
      expect(cuotasResp, contains('Televisor OLED'));

      final uberResp = await assistantService.processQuestion('¿Cuánto gasté en Uber?');
      expect(uberResp, contains('Uber Aeropuerto'));
      expect(uberResp, contains('10.00'));
    });
  });
}

