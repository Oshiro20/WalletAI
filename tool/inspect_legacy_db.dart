// ignore_for_file: avoid_print
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final dbPath = 'migration_data/money_android.sqlite';
  final file = File(dbPath);

  if (!file.existsSync()) {
    print('Error: Database file not found at $dbPath');
    return;
  }

  print('Opening database: $dbPath');
  final db = sqlite3.open(dbPath);

  try {
    // 4. Inspect Specific Tables
    final targetTables = ['REPEATTRANSACTION'];
    
    for (final tableName in targetTables) {
      print('\n=== Analyzing Table: $tableName ===');
      try {
        final schema = db.select("SELECT sql FROM sqlite_master WHERE type='table' AND name = ?", [tableName]);
        if (schema.isNotEmpty) {
          print('Schema: ${schema.first['sql']}');
        }

        final samples = db.select('SELECT * FROM "$tableName" LIMIT 3');
        if (samples.isNotEmpty) {
           print('Found ${samples.length} rows.');
           print('Columns: ${samples.first.keys}');
           for (var row in samples) {
             print(row);
           }
        } else {
          print('Table is empty.');
        }
      } catch (e) {
        print('Error analyzing $tableName: $e');
      }
    }

    // 5. List all Category Names for Mapping (Disabled for now)
    // Inspect ZCATEGORY columns and data
  final categoryColumns = db.select('PRAGMA table_info(ZCATEGORY)');
  print('\nColumns in ZCATEGORY:');
  for (final col in categoryColumns) {
    print(' - ${col['name']} (${col['type']})');
  }

  final uuidCat = db.select("SELECT * FROM ZCATEGORY WHERE uid = 'bade2c0c-a8eb-4f8d-afe2-5dcc1f008bd2'");
  print('\nSpecific UUID Category:');
  if (uuidCat.isEmpty) {
    print('Not found.');
  }
  for (final row in uuidCat) {
    print(row);
  }

  final allUids = db.select('SELECT uid FROM ZCATEGORY LIMIT 50');
  print('\nSample UIDs:');
  for (final row in allUids) {
    print(row['uid']);
  }
  } catch (e) {
    print('Error inspecting database: $e');
  } finally {
    db.dispose();
  }
}

