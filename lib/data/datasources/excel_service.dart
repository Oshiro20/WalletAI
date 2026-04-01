import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import 'package:flutter/foundation.dart' show debugPrint;
import '../../presentation/providers/database_providers.dart';
import '../database/drift_database.dart';

class ExcelService {
  final Ref ref;

  ExcelService(this.ref);

  /// Exportar transacciones a Excel
  Future<File> exportTransactions() async {
    final transactions = await ref.read(transactionsDaoProvider).getAllTransactions();
    final accounts = await ref.read(accountsDaoProvider).getAllAccounts();
    final categories = await ref.read(categoriesDaoProvider).getAllCategories();
    final subcategories = await ref.read(subcategoriesDaoProvider).getAllSubcategories();

    // Crear libro
    var excel = Excel.createExcel();
    // Renombrar hoja por defecto
    String defaultSheetName = excel.getDefaultSheet()!;
    excel.rename(defaultSheetName, 'Transacciones');
    
    Sheet sheet = excel['Transacciones'];

    // Encabezados
    final headers = [
      TextCellValue('Fecha'),
      TextCellValue('Tipo'),
      TextCellValue('Monto'),
      TextCellValue('Categoría'),
      TextCellValue('Subcategoría'),
      TextCellValue('Cuenta'),
      TextCellValue('Nota')
    ];
    sheet.appendRow(headers);

    // Datos
    for (var t in transactions) {
      final category = categories.firstWhere(
        (c) => c.id == t.categoryId,
        orElse: () => Category(
          id: '', 
          name: 'Sin categoría', 
          type: 'expense', 
          isSystem: false, 
          sortOrder: 0, 
          createdAt: DateTime.now()
        )
      );
      
      String subcategoryName = '';
      if (t.subcategoryId != null) {
        final sub = subcategories.where((s) => s.id == t.subcategoryId).firstOrNull;
        if (sub != null) subcategoryName = sub.name;
      }
      
      final account = accounts.firstWhere(
        (a) => a.id == t.accountId,
        orElse: () => Account(
          id: '', 
          name: 'Desconocida', 
          balance: 0, 
          type: 'cash', 
          currency: 'PEN', 
          isActive: true, 
          sortOrder: 0, 
          createdAt: DateTime.now(), 
          updatedAt: DateTime.now()
        )
      );

      final rowData = [
        TextCellValue(DateFormat('dd/MM/yyyy').format(t.date)),
        TextCellValue(t.type == 'expense' ? 'Gasto' : (t.type == 'income' ? 'Ingreso' : 'Transferencia')),
        DoubleCellValue(t.amount),
        TextCellValue(category.name),
        TextCellValue(subcategoryName),
        TextCellValue(account.name),
        TextCellValue(t.description ?? ''),
      ];
      sheet.appendRow(rowData);
    }

    // Guardar archivo
    var fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Error al generar archivo Excel');
    }

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/transacciones_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes);

    return file;
  }

  /// Generar plantilla con el formato del usuario (Registro Contable)
  Future<File> generateTemplate() async {
    var excel = Excel.createExcel();
    String defaultSheetName = excel.getDefaultSheet()!;
    excel.rename(defaultSheetName, 'Transacciones');
    Sheet sheet = excel['Transacciones'];

    // Encabezados exactos del usuario
    final headers = [
      TextCellValue('Fecha'),          // Col A
      TextCellValue('Cuenta'),         // Col B
      TextCellValue('Categoría'),      // Col C
      TextCellValue('Subcategorías'),  // Col D
      TextCellValue('Nota'),           // Col E
      TextCellValue('PEN'),            // Col F
      TextCellValue('Ingreso/Gasto'),  // Col G
      TextCellValue('Descripción'),    // Col H
      TextCellValue('Importe'),        // Col I 
      TextCellValue('Moneda'),         // Col J
      TextCellValue('Cuenta'),         // Col K
    ];
    sheet.appendRow(headers);

       // Guardar archivo
    var fileBytes = excel.save();
    if (fileBytes == null) {
      throw Exception('Error al generar plantilla');
    }

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/plantilla_gastos.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes);

    return file;
  }

  /// Helper: Normalizar texto para fuzzy match (minusculas, sin tildes)
  String _normalize(String input) {
    return input.toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .trim();
  }

  /// Importar transacciones desde Excel
  Future<int> importTransactions(File file) async {
    var bytes = await file.readAsBytes();
    var excel = Excel.decodeBytes(bytes);

    final transactionsDao = ref.read(transactionsDaoProvider);
    final accountsDao = ref.read(accountsDaoProvider);
    final categoriesDao = ref.read(categoriesDaoProvider);
    final subcategoriesDao = ref.read(subcategoriesDaoProvider);
    final uuid = const Uuid();

    int importedCount = 0;
    
    // Cargar mapas para búsqueda rápida (se actualizarán dinámicamente)
    var accounts = await accountsDao.getAllAccounts();
    var categories = await categoriesDao.getAllCategories();
    var subcategories = await subcategoriesDao.getAllSubcategories();
    
    // Iterar hojas
    for (var table in excel.tables.keys) {
      var sheet = excel.tables[table]!;
      
      // Buscar índices de columnas dinámicamente
      Map<String, int> colMap = {};
      
      // Leer primera fila como encabezados
      if (sheet.maxRows > 0) {
        var headerRow = sheet.rows[0];
        for (int i = 0; i < headerRow.length; i++) {
          var val = headerRow[i]?.value;
          if (val != null) {
             final key = val.toString().trim();
             // Important: Only add if not present to prioritize LEFTMOST columns
             // Fixes issue where "Cuenta" appears twice (Col B and Col K) and we want Col B.
             if (!colMap.containsKey(key)) {
                colMap[key] = i;
             }
          }
        }
      }

      // Validar si es el formato esperado (Legacy o Nuevo)
      bool isLegacyFormat = colMap.containsKey('Ingreso/Gasto') && colMap.containsKey('Importe');
      
      // Mapeo de columnas (Legacy vs Estándar)
      
      int idxDate = colMap['Fecha'] ?? 0;
      int idxAccount = colMap['Cuenta'] ?? (isLegacyFormat ? 1 : 5);
      int idxCategory = colMap['Categoría'] ?? 2; // O 3 en estandar
      int idxSubcategory = colMap['Subcategoría'] ?? colMap['Subcategorías'] ?? 4;
      int idxNote = colMap['Nota'] ?? (isLegacyFormat ? 4 : 6); // Legacy: E=4, Stnd: G=6
      int idxAmount = colMap['Importe'] ?? colMap['Monto'] ?? 2; // Legacy: I, Stnd: C=2
      int idxType = colMap['Ingreso/Gasto'] ?? colMap['Tipo'] ?? 1; // Legacy: G, Stnd: B=1

      // Empezar desde la fila 1 (saltar encabezados)
      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty) continue;

        try {
           // Helper Safe Text local scope
           String getSafeText(dynamic cell) {
             if (cell is TextCellValue) return cell.value.toString();
             if (cell is IntCellValue) return cell.value.toString();
             if (cell is DoubleCellValue) return cell.value.toString();
             return '';
           }

          // 1. Obtener valores usando el mapa de columnas
          var dateVal = (idxDate < row.length) ? row[idxDate]?.value : null;
          var typeVal = (idxType < row.length) ? row[idxType]?.value : null;
          var amountVal = (idxAmount < row.length) ? row[idxAmount]?.value : null;
          var categoryVal = (idxCategory < row.length) ? row[idxCategory]?.value : null;
          var subcategoryVal = (idxSubcategory < row.length) ? row[idxSubcategory]?.value : null;
          var accountVal = (idxAccount < row.length) ? row[idxAccount]?.value : null;
          var noteVal = (idxNote < row.length) ? row[idxNote]?.value : null;

          // Si falta fecha o monto, saltar
          if (dateVal == null || amountVal == null) continue;

          // 2. Parsers
          DateTime date = DateTime.now();
          if (dateVal is DateCellValue) {
             date = dateVal.asDateTimeLocal();
          } else {
             // Fallback to text parsing
             String dStr = getSafeText(dateVal);
             if (dStr.isNotEmpty) {
                 try {
                    // Remove time if present "16/02/2026 14:42:16" -> "16/02/2026"
                    if (dStr.contains(' ')) {
                      dStr = dStr.split(' ')[0];
                    }
                    
                    if (dStr.contains('/')) {
                       final parts = dStr.split('/');
                       if (parts.length == 3) {
                          // dd/MM/yyyy
                          date = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                       } else {
                          date = DateTime.parse(dStr);
                       }
                    } else {
                       date = DateTime.parse(dStr);
                    }
                 } catch (_) {
                   date = DateTime.now();
                 }
             }
          }

          double amount = 0.0;
          if (amountVal is DoubleCellValue) {
             amount = amountVal.value;
          } else if (amountVal is IntCellValue) {
             amount = amountVal.value.toDouble();
          } else {
             String aStr = getSafeText(amountVal);
             // Remove currency symbols or comas if needed
             // Assuming "1,200.50" or "1200.50"
             aStr = aStr.replaceAll(',', ''); 
             amount = double.tryParse(aStr) ?? 0.0;
          }

          // Normalizar Tipo
          String type = 'expense'; // default
          String tStr = getSafeText(typeVal).toLowerCase();
          if (tStr.contains('ingreso') || tStr == 'income') {
            type = 'income';
          } else if (tStr.contains('gasto') || tStr == 'expense') {
             type = 'expense';
          }
          if (tStr.contains('gastad')) type = 'expense';


          // 3. Buscar/Crear Cuenta
          final accName = getSafeText(accountVal);
          String accountId;
          
          if (accName.isNotEmpty) {
               Account? foundAcc;
               try {
                  foundAcc = accounts.firstWhere(
                    (a) => _normalize(a.name) == _normalize(accName) || _normalize(a.name).contains(_normalize(accName))
                  );
               } catch(_) {}
               
               if (foundAcc != null) {
                  accountId = foundAcc.id;
               } else {
                   final newAccId = uuid.v4();
                   
                   // Infer type from name
                   String accType = 'bank'; // Default
                   final lowerName = _normalize(accName);
                   if (lowerName.contains('efectivo') || lowerName.contains('cash')) {
                     accType = 'cash';
                   } else if (lowerName.contains('ahorro') || lowerName.contains('saving')) { accType = 'savings'; }
                   else if (lowerName.contains('tarjeta') || lowerName.contains('card') || lowerName.contains('credito')) { accType = 'credit_card'; }
                   else if (lowerName.contains('yape') || lowerName.contains('plin') || lowerName.contains('wallet')) { accType = 'wallet'; }
                   else if (lowerName.contains('inversion') || lowerName.contains('deposito')) { accType = 'investment'; }
                   


                   await accountsDao.createAccount(
                    AccountsCompanion.insert(
                      id: newAccId,
                      name: accName,
                      type: accType, 
                      icon: const drift.Value('account_balance_wallet'),
                      balance: const drift.Value(0.0), // Will be recalculated
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    )
                  );
                  accounts = await accountsDao.getAllAccounts();
                  accountId = newAccId;
               }
          } else {
             if (accounts.isEmpty) {
                 final newAccId = uuid.v4();
                 await accountsDao.createAccount(
                   AccountsCompanion.insert(
                     id: newAccId, 
                     name: 'Efectivo', 
                     type: 'cash', 
                     icon: const drift.Value('money'), 
                     balance: const drift.Value(0.0), 
                     createdAt: DateTime.now(),
                     updatedAt: DateTime.now(),
                   )
                 );
                 accounts = await accountsDao.getAllAccounts();
                 accountId = newAccId;
             } else {
               accountId = accounts.first.id;
             }
          }

          // 4. Buscar/Crear Categoría
          String? categoryId;
          
          if (type != 'transfer' && categoryVal != null) {
              final rawCatName = getSafeText(categoryVal);
              
              // Clean Category Name (Remove Emojis and excess whitespace)
              // Keeps letters, numbers, spaces, and common accents/punctuation
              final catName = rawCatName.replaceAll(RegExp(r'[^\w\s\u00C0-\u017F\-]'), '').trim();

              if (catName.isNotEmpty) {
                
                // CRITICAL: Prevent creating Categories that are actually Accounts
                // Check if an account with this name already exists
                bool isAccountName = accounts.any((a) => _normalize(a.name) == _normalize(catName));
                
                if (isAccountName) {
                   // If it's an account name, it's likely a transfer or mislabeled. 
                   // We skip category creation/assignment or default to 'Transferencia' if logic permits.
                   // For now, let's just NOT create it as a category.
                   debugPrint('Skipping Category creation for "$catName" as it matches an Account name.');
                } else {
                    final normCatName = _normalize(catName);
                    Category? foundCat;
                    
                    try {
                      foundCat = categories.firstWhere(
                        (c) => _normalize(c.name) == normCatName && c.type == type
                      );
                    } catch (_) {}

                    if (foundCat == null) {
                       try {
                         foundCat = categories.firstWhere(
                           (c) => _normalize(c.name).contains(normCatName) && c.type == type
                         );
                       } catch (_) {}
                    }
                    
                    if (foundCat != null) {
                       categoryId = foundCat.id;
                    } else {
                       // Create new Category
                       final newCatId = uuid.v4();
                       // Determine icon based on name keywords (simple heuristic)
                       String? icon = 'label_outline'; // Default
                       
                       await categoriesDao.createCategory(
                         CategoriesCompanion.insert(
                           id: newCatId,
                           name: catName, // Use cleaned name
                           type: type,
                           icon: drift.Value(icon),
                           color: const drift.Value('0xFF9E9E9E'),
                           createdAt: DateTime.now(),
                         )
                       );
                       // Update local cache
                       categories = await categoriesDao.getAllCategories();
                       categoryId = newCatId;
                    }
                }
              } else {
                 try {
                  categoryId = categories.firstWhere((c) => c.type == type).id;
                 } catch(_) {
                   if (categories.isNotEmpty) categoryId = categories.first.id;
                 }
              }
          }

          // 5. Buscar/Crear Subcategoría
          String? subcategoryId;
          if (categoryId != null && subcategoryVal != null) {
             final subName = getSafeText(subcategoryVal);
             if (subName.isNotEmpty) {
                final normSubName = _normalize(subName);
                Subcategory? foundSub;
                try {
                   foundSub = subcategories.firstWhere(
                     (s) => s.categoryId == categoryId && (_normalize(s.name) == normSubName || _normalize(s.name).contains(normSubName))
                   );
                } catch (_) {}

                if (foundSub != null) {
                   subcategoryId = foundSub.id;
                } else {
                   final newSubId = uuid.v4();
                   await subcategoriesDao.createSubcategory(
                      SubcategoriesCompanion.insert(
                        id: newSubId,
                        categoryId: categoryId,
                        name: subName,
                        icon: const drift.Value('label_outline'),
                        createdAt: DateTime.now(),
                      )
                   );
                   subcategories = await subcategoriesDao.getAllSubcategories();
                   subcategoryId = newSubId;
                }
             }
          }
          
          final description = getSafeText(noteVal);

          // 7. Insertar Transacción
          await transactionsDao.createTransaction(
            TransactionsCompanion.insert(
              id: uuid.v4(),
              type: type,
              amount: amount,
              accountId: accountId,
              categoryId: categoryId != null ? drift.Value(categoryId) : const drift.Value.absent(),
              subcategoryId: subcategoryId != null ? drift.Value(subcategoryId) : const drift.Value.absent(),
              date: date,
              description: drift.Value(description),
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          );
          
          importedCount++;

          // Yield to UI every 50 rows to prevent ANR
          if (i % 50 == 0) {
            await Future.delayed(Duration.zero);
          }

        } catch (e, stack) {
          debugPrint('Error importando fila $i: $e');
          debugPrint(stack.toString());
          continue;
        }
    }
  }

    // Recalculate Balances for ALL accounts
    await _recalculateAccountBalances(accountsDao, transactionsDao);

    return importedCount;
  }

  Future<void> _recalculateAccountBalances(dynamic accountsDao, dynamic transactionsDao) async {
       final allAccounts = await accountsDao.getAllAccounts();
       for (var acc in allAccounts) {
           final transactions = await transactionsDao.getTransactionsByAccount(acc.id);
           double newBalance = 0.0;
           for (var t in transactions) {
               if (t.type == 'income') newBalance += t.amount;
               if (t.type == 'expense') newBalance -= t.amount;
           }
           await accountsDao.updateAccountBalance(acc.id, newBalance);
       }
  }
}

final excelServiceProvider = Provider((ref) => ExcelService(ref));
