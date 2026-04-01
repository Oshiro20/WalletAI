import 'dart:io';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/drift_database.dart';
import '../../core/theme/app_colors.dart';
import 'package:logger/logger.dart';

class LegacyImportService {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();
  final _logger = Logger();

  // Maps to store legacy_id -> new_uuid
  final Map<String, String> _accountMap = {};
  final Map<String, String> _categoryMap = {}; // Legacy UID -> New Category ID (Roots)
  final Map<String, String> _subcategoryMap = {}; // Legacy UID -> New Subcategory ID (Children)
  final Map<String, String> _subcategoryParentMap = {}; // Legacy Subcategory UID -> New Parent Category ID

  // Smart Mapping: Legacy Name -> App Category ID
  final Map<String, String> _smartCategoryMap = {
    'Alimentación': 'cat_alimentacion',
    'Comida': 'cat_alimentacion',
    'Cena': 'cat_alimentacion',
    'Restaurante': 'cat_alimentacion',
    'Mercado': 'cat_alimentacion',
    'Transporte': 'cat_transporte',
    'Pasaje': 'cat_transporte',
    'Taxi': 'cat_transporte',
    'Gasolina': 'cat_transporte',
    'Salud': 'cat_salud',
    'Medicinas': 'cat_salud',
    'Farmacia': 'cat_salud',
    'Citas Médicas': 'cat_salud',
    'Educación': 'cat_educacion',
    'Libros': 'cat_educacion',
    'Entretenimiento': 'cat_entretenimiento',
    'Cine': 'cat_entretenimiento',
    'Ropa': 'cat_ropa',
    'Vestimenta': 'cat_ropa',
    'Regalos': 'cat_familia', 
    'Familia': 'cat_familia',
    'Pareja': 'cat_pareja', // Mapped to existing "Pareja"
    'Alojamiento': 'cat_alojamiento', // Mapped to existing
    'Hogar': 'cat_alojamiento',
    'Luz': 'cat_servicios_digitales',
    'Agua': 'cat_servicios_digitales',
    'Internet': 'cat_servicios_digitales',
    'Servicios Digitales': 'cat_servicios_digitales', // Mapped to existing
    'Spotify': 'cat_entretenimiento', 
    'Netflix': 'cat_entretenimiento',
    'Salario': 'cat_salario',
    'Sueldo': 'cat_salario',
    'Dinero extra': 'cat_dinero_extra',
    'Mascotas': 'cat_mascotas',
    'Cuidado Personal': 'cat_cuidado_personal',
    'Belleza': 'cat_cuidado_personal',
    'Antojos': 'cat_antojos',
  };

  // Keyword to Icon mapping
  final Map<String, String> _keywordIconMap = {
    'Spotify': '🎵',
    'Youtube': '📺',
    'Netflix': '🎬',
    'Internet': '🌐',
    'Movil': '📱',
    'Celular': '📱',
    'Luz': '💡',
    'Agua': '💧',
    'Gas': '🔥',
    'Gym': '💪',
    'Deporte': '⚽',
    'Mascota': '🐾',
    'Perro': '🐶',
    'Gato': '🐱',
    'Uber': '🚖',
    'Taxi': '🚕',
    'Bus': '🚌',
    'Avion': '✈️',
    'Viaje': '🧳',
    'Hotel': '🏨',
    'Cine': '🍿',
    'Juego': '🎮',
    'Steam': '🎮',
    'Ropa': '👕',
    'Zapatos': '👟',
    'Regalo': '🎁',
    'Pareja': '❤️',
    'Amor': '❤️',
    'Cerveza': '🍺',
    'Bar': '🍻',
    'Café': '☕',
    'Pan': '🥖',
    'Pizza': '🍕',
    'Burger': '🍔',
    'Salud': '🏥',
    'Doctor': '👨‍⚕️',
    'Farmacia': '💊',
    'Mercado': '🛒',
    'Supermercado': '🛒',
  };

  LegacyImportService(this._db);

  Future<void> importLegacyData(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Archivo no encontrado: $filePath');
    }

    _logger.i('Abriendo base de datos legacy: $filePath');
    final legacyDb = sqlite.sqlite3.open(filePath);

    try {
      await _db.transaction(() async {
        await _importAccounts(legacyDb);
        await _importCategories(legacyDb);
        await _importTransactions(legacyDb);
      });
      _logger.i('Migración completada con éxito.');
    } catch (e) {
      _logger.e('Error en migración: $e');
      rethrow;
    } finally {
      legacyDb.dispose();
    }
  }

  Future<void> _importAccounts(sqlite.Database legacyDb) async {
    final results = legacyDb.select('SELECT * FROM ASSETS');
    _logger.i('Importando ${results.length} cuentas...');

    for (final row in results) {
      final legacyUid = row['uid'].toString();
      final name = (row['NIC_NAME'] as String?) ?? 'Cuenta sin nombre';
      // ASSETS don't seem to have type in samples provided, assuming 'cash' or generic
      // We can check if name contains "Visa" or "Card" to guess type, but 'cash' is safe default.
      final newId = _uuid.v4();
      
      final accountCompanion = AccountsCompanion.insert(
        id: newId,
        name: name,
        type: 'cash', // Default
        balance: const Value(0.0), // Will be recalculated
        currency: const Value('PEN'),
        color: Value(AppColors.primary.toARGB32().toString()),
        icon: const Value('account_balance_wallet'),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.into(_db.accounts).insert(accountCompanion);
      _accountMap[legacyUid] = newId;
    }
    _logger.i('Cuentas importadas.');
  }

  Future<void> _importCategories(sqlite.Database legacyDb) async {
    final results = legacyDb.select('SELECT * FROM ZCATEGORY');
    _logger.i('Procesando ${results.length} categorías...');

    // Separate Roots and Children
    final List<Map<String, dynamic>> roots = [];
    final List<Map<String, dynamic>> children = [];

    for (final row in results) {
      final pUid = row['pUid'];
      // Determine if root: pUid is null, 0, "0", or empty
      bool isRoot = pUid == null || pUid == 0 || pUid == '0' || pUid == '';
      
      if (isRoot) {
        roots.add(row);
      } else {
        children.add(row);
      }
    }

    _logger.i('Roots: ${roots.length}, Children: ${children.length}');

    // Pass 1: Import Roots (Categories Table)
    for (final row in roots) {
      await _importRootCategory(row);
    }

    // Pass 2: Import Children (Subcategories Table)
    for (final row in children) {
      await _importChildCategory(row);
    }

    _logger.i('Categorías importadas (Roots: ${_categoryMap.length}, Subs: ${_subcategoryMap.length}).');
  }

  Future<void> _importRootCategory(Map<String, dynamic> row) async {
      final legacyUid = row['uid'].toString();
      final name = (row['NAME'] as String?) ?? 'Categoría sin nombre';
      final typeInt = (row['TYPE'] as int?) ?? 0;
      final type = typeInt == 0 ? 'income' : 'expense';

      // Smart Mapping (Roots)
      final normalizedName = name.trim();
      final mappedId = _smartCategoryMap[normalizedName];

      if (mappedId != null) {
        _categoryMap[legacyUid] = mappedId;
        // print('Mapped Root "$name" -> $mappedId');
        return; 
      }

      // 3. Check for Existing Category in DB by Name (Prevent Duplicates)
      // This handles cases where "Ropa" exists in both Legacy and App, but isn't in _smartCategoryMap
      // Use limit(1) to avoid "Too many elements" if DB already has duplicates
      final existingCategory = await (_db.select(_db.categories)..where((tbl) => tbl.name.equals(name))..limit(1)).getSingleOrNull();
      
      if (existingCategory != null) {
        _categoryMap[legacyUid] = existingCategory.id;
        // print('Merged "$name" -> Existing App Category (${existingCategory.id})');
        return;
      }

      // 4. Create New Category
      String icon = 'category'; 
      String? guessedIcon;
      
      for (final key in _keywordIconMap.keys) {
        if (normalizedName.toLowerCase().contains(key.toLowerCase())) {
          guessedIcon = _keywordIconMap[key];
          break;
        }
      }
      
      if (guessedIcon != null) {
        icon = guessedIcon;
      } else {
         if (type == 'income') {
           icon = '💰';
         } else {
           icon = '🏷️';
         }
      }

      final newId = _uuid.v4();

      final categoryCompanion = CategoriesCompanion.insert(
        id: newId,
        name: name,
        type: type,
        color: Value(AppColors.primary.toARGB32().toString()), 
        icon: Value(icon),
        createdAt: DateTime.now(),
      );

      await _db.into(_db.categories).insert(categoryCompanion);
      _categoryMap[legacyUid] = newId;
  }

  Future<void> _importChildCategory(Map<String, dynamic> row) async {
      final legacyUid = row['uid'].toString();
      final name = (row['NAME'] as String?) ?? 'Subcategoría sin nombre';
      final legacyParentUid = row['pUid'].toString();
      
      // Find Parent Category
      final parentId = _categoryMap[legacyParentUid];
      
      if (parentId == null) {
        // Orphaned child: Treat as root fallback? or skip?
        // Let's import as root to be safe
        await _importRootCategory(row);
        return;
      }

      // Create New Subcategory
      final newSubId = _uuid.v4();
      
      // Guess Icon (optional, subcats might abuse generic icons)
      // Usually subcategories in this app have specific icons defined in seed, but custom ones might not.
      // let's try to guess or use generic.
      String icon = 'label'; 
      String? guessedIcon;
       final normalizedName = name.trim();
      for (final key in _keywordIconMap.keys) {
        if (normalizedName.toLowerCase().contains(key.toLowerCase())) {
          guessedIcon = _keywordIconMap[key];
          break;
        }
      }
      if (guessedIcon != null) icon = guessedIcon;

      final subcategoryCompanion = SubcategoriesCompanion.insert(
        id: newSubId,
        categoryId: parentId,
        name: name,
        icon: Value(icon),
        createdAt: DateTime.now(),
      );

      await _db.into(_db.subcategories).insert(subcategoryCompanion);
      _subcategoryMap[legacyUid] = newSubId;
      _subcategoryParentMap[legacyUid] = parentId;
  }

  Future<void> _importTransactions(sqlite.Database legacyDb) async {
    final results = legacyDb.select('SELECT * FROM INOUTCOME');
    _logger.i('Importando ${results.length} transacciones...');

    final List<TransactionsCompanion> importedCompanions = [];

    int importedCount = 0;
    for (final row in results) {
      // Campos Clave
      final legacyAssetUid = row['assetUid'].toString();
      final legacyCtgUid = row['ctgUid'].toString();
      
      final zDateInt = _parseInt(row['ZDATE']);
      final zDate = zDateInt != null 
          ? DateTime.fromMillisecondsSinceEpoch(zDateInt) 
          : DateTime.now();

      final zMoney = _parseDouble(row['ZMONEY']) ?? 0.0;
      final doType = _parseInt(row['DO_TYPE']) ?? 0; // 0=Income?, 1=Expense?
      final description = row['ZCONTENT'] as String?;
      
      // Mapeo
      final accountId = _accountMap[legacyAssetUid];
      
      // Determine Category & Subcategory
      String? categoryId;
      String? subcategoryId;

      // Check if it matches a Subcategory first
      if (_subcategoryMap.containsKey(legacyCtgUid)) {
        subcategoryId = _subcategoryMap[legacyCtgUid];
        categoryId = _subcategoryParentMap[legacyCtgUid];
      } else {
        // Must be a Root Category
        categoryId = _categoryMap[legacyCtgUid];
      }

      if (accountId == null) {
        _logger.w('Skipping transaction: Account not found for assetUid $legacyAssetUid');
        continue;
      }

      final type = doType == 0 ? 'income' : 'expense';
      
      final newTransactionId = _uuid.v4();
      final transactionCompanion = TransactionsCompanion.insert(
        id: newTransactionId,
        type: type,
        amount: zMoney,
        accountId: accountId,
        categoryId: categoryId != null ? Value(categoryId) : const Value.absent(), 
        subcategoryId: subcategoryId != null ? Value(subcategoryId) : const Value.absent(),
        date: zDate,
        description: description != null ? Value(description) : const Value.absent(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.into(_db.transactions).insert(transactionCompanion);
      importedCompanions.add(transactionCompanion);
      
      // Simple balance update
      final multiplier = type == 'income' ? 1 : -1;
      await _db.customStatement(
        'UPDATE accounts SET balance = balance + ? WHERE id = ?',
        [zMoney * multiplier, accountId]
      );

      importedCount++;
    }
    _logger.i('Importadas $importedCount transacciones.');

    // Run Heuristic Analysis
    await _detectAndImportRecurring(legacyDb, importedCompanions);
  }

  Future<void> _detectAndImportRecurring(sqlite.Database legacyDb, List<TransactionsCompanion> importedTransactions) async {
    _logger.i('Analizando ${importedTransactions.length} transacciones para detectar recurrencia...');
    
    // Group by Description + Amount (Value Key)
    final Map<String, List<TransactionsCompanion>> groups = {};

    for (final tx in importedTransactions) {
      if (tx.description.present && tx.amount.value != 0) {
        final key = '${tx.description.value}|${tx.amount.value}';
        groups.putIfAbsent(key, () => []).add(tx);
      }
    }

    int recurringCount = 0;
    
    for (final entry in groups.entries) {
      final txs = entry.value;
      // Filter out those with less than 3 occurrences (arbitrary threshold for "recurring")
      if (txs.length < 3) continue;

      // Sort by date
      txs.sort((a, b) => a.date.value.compareTo(b.date.value));

      // Check intervals
      bool isMonthly = true;
      for (int i = 0; i < txs.length - 1; i++) {
        final diff = txs[i+1].date.value.difference(txs[i].date.value).inDays;
        // Allow slack: 26 to 35 days for "monthly"
        if (diff < 26 || diff > 35) {
          isMonthly = false;
          break;
        }
      }

      if (isMonthly) {
        // Create Recurring Payment
        final lastTx = txs.last;
        // Project next date
        final nextDate = lastTx.date.value.add(const Duration(days: 30)); 
        
        // Only if next date is in future or recent past (to be relevant)
        // actually, let's just import it as active.
        
        final recurringId = _uuid.v4();
        final recurring = RecurringPaymentsCompanion.insert(
          id: recurringId,
          name: lastTx.description.value ?? 'Pago Recurrente',
          amount: lastTx.amount.value,
          accountId: lastTx.accountId.value,
          categoryId: lastTx.categoryId, // Carry over mapped category
          frequency: 'monthly',
          nextDueDate: nextDate,
          isActive: const Value(true),
          createdAt: DateTime.now(),
        );

        await _db.into(_db.recurringPayments).insert(recurring);
        recurringCount++;
        _logger.i('Detectado Recurrente: ${lastTx.description.value} (${lastTx.amount.value})');
      }
    }
    _logger.i('Pagos recurrentes detectados e importados: $recurringCount');
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
// ... rest of file

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
