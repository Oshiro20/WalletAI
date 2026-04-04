// ignore_for_file: avoid_print
import 'dart:io';
import 'package:excel/excel.dart';

void main() async {
  final filePath =
      r'D:\Proyectos_Flutter\Aplicativo_Gastos\migration_data\Registro Contable_17-2-2026.xlsx';
  final file = File(filePath);
  var bytes = await file.readAsBytes();
  var excel = Excel.decodeBytes(bytes);

  for (var table in excel.tables.keys) {
    var sheet = excel.tables[table]!;
    if (sheet.maxRows <= 1) continue;

    // Simulate colMap logic
    Map<String, int> colMap = {};
    if (sheet.maxRows > 0) {
      var headerRow = sheet.rows[0];
      for (int i = 0; i < headerRow.length; i++) {
        var val = headerRow[i]?.value;
        if (val != null) {
          // Simulating val.toString().trim()
          print('Header $i raw: $val type: ${val.runtimeType}');
          colMap[val.toString().trim()] = i;
        }
      }
    }
    print('ColMap: $colMap');

    bool isLegacyFormat =
        colMap.containsKey('Ingreso/Gasto') && colMap.containsKey('Importe');
    print('IsLegacy: $isLegacyFormat');

    int idxDate = colMap['Fecha'] ?? 0;
    int idxAccount = colMap['Cuenta'] ?? (isLegacyFormat ? 1 : 5);
    int idxCategory = colMap['CategorÃ­a'] ?? 2;
    // idxSubcategory logic
    int idxSubcategory =
        colMap['SubcategorÃ­a'] ?? colMap['SubcategorÃ­as'] ?? 4;

    int idxNote = colMap['Nota'] ?? (isLegacyFormat ? 4 : 6);
    int idxAmount = colMap['Importe'] ?? colMap['Monto'] ?? 2;
    int idxType = colMap['Ingreso/Gasto'] ?? colMap['Tipo'] ?? 1;

    print(
      'Indices: Date=$idxDate, Acc=$idxAccount, Cat=$idxCategory, Sub=$idxSubcategory, Note=$idxNote, Amt=$idxAmount, Type=$idxType',
    );

    // Simulate Row loop
    for (int i = 1; i < sheet.maxRows; i++) {
      var row = sheet.rows[i];
      if (row.isEmpty) continue;
      print('\nProcessing Row $i');

      try {
        // Helper Safe Text
        String getSafeText(dynamic cell) {
          if (cell is TextCellValue) return cell.value.toString();
          if (cell is IntCellValue) return cell.value.toString();
          if (cell is DoubleCellValue) return cell.value.toString();
          return '';
        }

        var dateVal = (idxDate < row.length) ? row[idxDate]?.value : null;
        var amountVal = (idxAmount < row.length) ? row[idxAmount]?.value : null;

        print(' Raw DateVal: $dateVal (${dateVal.runtimeType})');
        print(' Raw AmountVal: $amountVal (${amountVal.runtimeType})');

        if (dateVal == null || amountVal == null) {
          print('Skipping: null date or amount');
          continue;
        }

        // Date Parse simulation
        String dStr = getSafeText(dateVal);
        print('  Date String: "$dStr"');
        if (dStr.isNotEmpty) {
          try {
            if (dStr.contains(' ')) dStr = dStr.split(' ')[0];
            if (dStr.contains('/')) {
              final parts = dStr.split('/');
              if (parts.length == 3) {
                var d = DateTime(
                  int.parse(parts[2]),
                  int.parse(parts[1]),
                  int.parse(parts[0]),
                );
                print('  Parsed Date: $d');
              }
            }
          } catch (e) {
            print('  Date Parse Error: $e');
          }
        }

        // Amount Parse simulation
        String aStr = getSafeText(amountVal);
        print('  Amount String: "$aStr"');
        aStr = aStr.replaceAll(',', '');
        var amt = double.tryParse(aStr) ?? 0.0;
        print('  Parsed Amount: $amt');
      } catch (e, stack) {
        print('CRASH on row $i: $e');
        print(stack);
      }
    }
  }
}
