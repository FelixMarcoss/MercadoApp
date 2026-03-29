import 'package:pocketbase/pocketbase.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

Future<void> main() async {
  // Setup sqflite for dart standalone
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  var db = await databaseFactory.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(
      version: 4,
      onCreate: (db, version) async {
        await db.execute('''
        CREATE TABLE purchases (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          total_value REAL NOT NULL,
          url TEXT NOT NULL UNIQUE,
          synced INTEGER NOT NULL DEFAULT 0,
          avulsa INTEGER NOT NULL DEFAULT 0
        )
        ''');
        await db.execute('''
        CREATE TABLE products (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          quantity REAL NOT NULL,
          unit_type TEXT NOT NULL,
          unit_price REAL NOT NULL,
          total_price REAL NOT NULL,
          image_path TEXT,
          FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
        )
        ''');
      }
  ));

  // Simulate data returned by PB matching generate_mock_data.dart
  final now = DateTime.now().toUtc();
  final mes3 = now.subtract(const Duration(days: 90)).toIso8601String();
  final mes2 = now.subtract(const Duration(days: 60)).toIso8601String();
  final mes1 = now.subtract(const Duration(days: 30)).toIso8601String();
  final hoje = now.toIso8601String();

  final records = [
    {'produto': 'Leite Integral 1L', 'ultima_compra': mes3, 'preco_medio': 4.50},
    {'produto': 'Leite Integral 1L', 'ultima_compra': mes2, 'preco_medio': 5.20},
    {'produto': 'Leite Integral 1L', 'ultima_compra': mes1, 'preco_medio': 5.80},
    {'produto': 'Leite Integral 1L', 'ultima_compra': hoje, 'preco_medio': 6.10},
  ];

  // Grouping logic from app_state.dart
  final Map<String, List<Map<String, dynamic>>> groupedRecords = {};
  for (var r in records) {
    final String purchaseKey = r['ultima_compra']?.toString() ?? '';
    groupedRecords.putIfAbsent(purchaseKey, () => []).add(r);
  }

  // Insert mock purchases
  for (var entry in groupedRecords.entries) {
    final dateStr = entry.key;
    final items = entry.value;

    int purchaseId = await db.insert('purchases', {
      'date': dateStr,
      'total_value': 100.0,
      'url': 'sync_pb_\$dateStr',
      'synced': 1,
      'avulsa': 0
    });

    for (var r in items) {
      await db.insert('products', {
        'purchase_id': purchaseId,
        'name': r['produto'],
        'quantity': 1,
        'unit_type': 'un',
        'unit_price': r['preco_medio'],
        'total_price': r['preco_medio'],
      });
    }
  }

  // Get price history for Leite
  final sql = '''
      SELECT p.unit_price, p2.date
      FROM products p
      INNER JOIN purchases p2 ON p.purchase_id = p2.id
      WHERE p.name = ?
      ORDER BY p2.date ASC
  ''';
  final result = await db.rawQuery(sql, ['Leite Integral 1L']);
  
  print('Result from DB history: \${result.length} rows.');
  for(var row in result) {
    print(row);
  }
}
