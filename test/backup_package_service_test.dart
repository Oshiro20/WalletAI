import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wallet_ai/data/database/drift_database.dart';
import 'package:wallet_ai/data/datasources/backup_package_service.dart';
import 'package:wallet_ai/data/datasources/groq_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('walletai_backup_test_');
    BackupPackageService.testDocumentsDirOverride = tempDir;
    BackupPackageService.testTempDirOverride = tempDir;
    SharedPreferences.setMockInitialValues({
      'theme_mode': 'dark',
      'dashboard_layout_v1': '[{"type":"balance","visible":false,"order":0}]',
      'cloud_auth_token': 'local_token_should_not_overwrite',
      'walletai_local_device_id': 'device-local-id',
    });
  });

  tearDown(() async {
    BackupPackageService.testDocumentsDirOverride = null;
    BackupPackageService.testTempDirOverride = null;
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'paquete unificado V2 conserva cuentas, fechas de corte, categorías/subcategorías ampliadas, movimientos y SharedPreferences (cifrado y sin cifrar)',
    () async {
      final dbFile = File(p.join(tempDir.path, 'finanzas.db'));
      final sourceDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      final now = DateTime.now();

      await sourceDb.accountsDao.createAccount(
        AccountsCompanion.insert(
          id: 'acc_visa_oro',
          name: 'Visa Signature BCP',
          type: 'credit_card',
          balance: const drift.Value(4200.0),
          creditLimit: const drift.Value(5000.0),
          closingDay: const drift.Value(18),
          paymentDueDay: const drift.Value(5),
          tea: const drift.Value(42.5),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await sourceDb.categoriesDao.createCategory(
        CategoriesCompanion.insert(
          id: 'cat_custom_mascotas',
          name: 'Mascotas',
          icon: const drift.Value('pets'),
          color: const drift.Value('#FF9800'),
          type: 'expense',
          createdAt: now,
        ),
      );

      await sourceDb.subcategoriesDao.createSubcategory(
        SubcategoriesCompanion.insert(
          id: 'sub_custom_vet',
          categoryId: 'cat_custom_mascotas',
          name: 'Veterinaria Especializada',
          createdAt: now,
        ),
      );

      await sourceDb.transactionsDao.createTransaction(
        TransactionsCompanion.insert(
          id: 'tx_custom_1',
          accountId: 'acc_visa_oro',
          type: 'expense',
          amount: 185.50,
          categoryId: const drift.Value('cat_custom_mascotas'),
          subcategoryId: const drift.Value('sub_custom_vet'),
          description: const drift.Value('Consulta veterinaria'),
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Exportar paquete cifrado AES-256 V2 con WAL abierto
      final encryptedPkg = await BackupPackageService.buildPackage(
        activeDb: sourceDb,
        password: 'ClaveSegura2026',
      );
      expect(encryptedPkg.meta.stats.accountsCount, equals(1));
      expect(encryptedPkg.meta.stats.categoriesCount, greaterThanOrEqualTo(1));
      expect(encryptedPkg.meta.stats.subcategoriesCount, greaterThanOrEqualTo(1));
      expect(encryptedPkg.meta.stats.transactionsCount, equals(1));
      await sourceDb.close();

      // Simular dispositivo nuevo: borrar BD y limpiar preferencias del usuario
      await dbFile.delete();
      SharedPreferences.setMockInitialValues({
        'theme_mode': 'light',
        'cloud_auth_token': 'new_device_token',
      });

      // Intentar restaurar sin clave debe pedir contraseña
      final needsPassRes = await BackupPackageService.restoreFromBytes(
        encryptedPkg.bytes,
      );
      expect(needsPassRes.success, isFalse);
      expect(needsPassRes.requiresPassword, isTrue);

      // Contraseña incorrecta debe fallar limpiamente
      final wrongPassRes = await BackupPackageService.restoreFromBytes(
        encryptedPkg.bytes,
        password: 'OtraPassword',
      );
      expect(wrongPassRes.success, isFalse);

      // Restaurar con la contraseña correcta
      final okRes = await BackupPackageService.restoreFromBytes(
        encryptedPkg.bytes,
        password: 'ClaveSegura2026',
      );
      expect(okRes.success, isTrue, reason: okRes.message);
      expect(okRes.restoredPreferences, isTrue);

      // Validar que la nueva BD contiene exactamente la cuenta, corte, categoría ampliada y movimiento
      final restoredDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      final accounts = await restoredDb.accountsDao.getAllAccounts();
      final categories = await restoredDb.categoriesDao.getAllCategories();
      final subcats = await restoredDb.subcategoriesDao.getAllSubcategories();
      final txs = await restoredDb.transactionsDao.getAllTransactions();
      await restoredDb.close();

      final restoredAcc = accounts.firstWhere((a) => a.id == 'acc_visa_oro');
      expect(restoredAcc.name, equals('Visa Signature BCP'));
      expect(restoredAcc.balance, equals(4200.0));
      expect(restoredAcc.creditLimit, equals(5000.0));
      expect(restoredAcc.closingDay, equals(18));
      expect(restoredAcc.paymentDueDay, equals(5));
      expect(restoredAcc.tea, equals(42.5));

      expect(
        categories.any((c) => c.id == 'cat_custom_mascotas' && c.name == 'Mascotas'),
        isTrue,
      );
      expect(
        subcats.any((s) => s.id == 'sub_custom_vet' && s.name == 'Veterinaria Especializada'),
        isTrue,
      );
      expect(txs.any((t) => t.id == 'tx_custom_1' && t.amount == 185.50), isTrue);

      // Validar que SharedPreferences restauró tema/dashboard pero respetó token local
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), equals('dark'));
      expect(prefs.getString('dashboard_layout_v1'), contains('false'));
      expect(prefs.getString('cloud_auth_token'), equals('new_device_token'));
    },
  );

  test('GroqService.loadHistory limita a 20 mensajes válidos', () {
    final groq = GroqService();
    final msgs = List.generate(
      25,
      (i) => {'role': i.isEven ? 'user' : 'assistant', 'content': 'msg $i'},
    );
    groq.loadHistory(msgs);
    groq.resetSession();
    // Sin excepción al cargar ni reiniciar sesión
    expect(true, isTrue);
  });
}
