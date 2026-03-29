import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/product.dart';
import '../models/purchase.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mercado_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      var tableInfo = await db.rawQuery('PRAGMA table_info(purchases)');
      if (!tableInfo.any((column) => column['name'] == 'synced')) {
        await db.execute(
          'ALTER TABLE purchases ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 3) {
      var tableInfo = await db.rawQuery('PRAGMA table_info(purchases)');
      if (!tableInfo.any((column) => column['name'] == 'avulsa')) {
        await db.execute(
          'ALTER TABLE purchases ADD COLUMN avulsa INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
    if (oldVersion < 4) {
      var tableInfo = await db.rawQuery('PRAGMA table_info(products)');
      if (!tableInfo.any((column) => column['name'] == 'image_path')) {
        await db.execute(
          'ALTER TABLE products ADD COLUMN image_path TEXT',
        );
      }
    }
    if (oldVersion < 5) {
      var tableInfo = await db.rawQuery('PRAGMA table_info(purchases)');
      if (!tableInfo.any((column) => column['name'] == 'is_public')) {
        await db.execute(
          'ALTER TABLE purchases ADD COLUMN is_public INTEGER NOT NULL DEFAULT 0',
        );
      }
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textUniqueType = 'TEXT NOT NULL UNIQUE';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE purchases (
  id $idType,
  date $textType,
  total_value $realType,
  url $textUniqueType,
  synced INTEGER NOT NULL DEFAULT 0,
  avulsa INTEGER NOT NULL DEFAULT 0,
  is_public INTEGER NOT NULL DEFAULT 0
)
''');

    await db.execute('''
CREATE TABLE products (
  id $idType,
  purchase_id $intType,
  name $textType,
  quantity $realType,
  unit_type $textType,
  unit_price $realType,
  total_price $realType,
  image_path TEXT,
  FOREIGN KEY (purchase_id) REFERENCES purchases (id) ON DELETE CASCADE
)
''');
  }

  // Insert a purchase and its products in a single transaction
  Future<int> insertPurchaseTransaction(
    Purchase purchase,
    List<Product> products,
  ) async {
    final db = await instance.database;

    // Using transaction to ensure either everything is saved or nothing is
    return await db.transaction((txn) async {
      final purchaseId = await txn.insert('purchases', purchase.toMap());

      for (var product in products) {
        final productMap = product.toMap();
        productMap['purchase_id'] = purchaseId;
        await txn.insert('products', productMap);
      }
      return purchaseId;
    });
  }

  // Verifies if URL exists to avoid duplicates
  Future<bool> purchaseExists(String url) async {
    final db = await instance.database;
    final maps = await db.query(
      'purchases',
      columns: ['id'],
      where: 'url = ?',
      whereArgs: [url],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // Get ALL latest products (group by name, ordering by date desc)
  Future<List<Product>> getLatestProducts({int? month, int? year}) async {
    final db = await instance.database;
    
    String innerWhereClause = '';
    String outerWhereClause = '';
    List<dynamic> whereArgs = [];
    
    if (month != null && year != null) {
      final String monthStr = month.toString().padLeft(2, '0');
      final String yearMonthPrefix = '$year-$monthStr-';
      innerWhereClause = 'WHERE pur.date LIKE ?';
      outerWhereClause = 'WHERE p2.date LIKE ?';
      whereArgs = ['$yearMonthPrefix%'];
    }

    // We join products with purchases to get the date, then group by product name,
    // taking the max date. SQLite supports fetching the row corresponding to MAX(x).
    final result = await db.rawQuery('''
      SELECT 
        p.id, p.purchase_id, p.name, 
        SUM(p.quantity) as quantity, 
        p.unit_type, p.unit_price, 
        SUM(p.total_price) as total_price,
        max_dates.max_date as date,
        p2.avulsa,
        (SELECT p_img.image_path FROM products p_img WHERE p_img.name = p.name AND p_img.image_path IS NOT NULL LIMIT 1) as image_path
      FROM products p
      INNER JOIN purchases p2 ON p.purchase_id = p2.id
      INNER JOIN (
          SELECT prod.name as prod_name, MAX(pur.date) as max_date
          FROM products prod
          INNER JOIN purchases pur ON prod.purchase_id = pur.id
          $innerWhereClause
          GROUP BY prod.name
      ) max_dates ON p.name = max_dates.prod_name AND p2.date = max_dates.max_date
      $outerWhereClause
      GROUP BY p.name, p.purchase_id, p.unit_price, p.unit_type, p2.avulsa
      ORDER BY p.name ASC
    ''', [...whereArgs, ...whereArgs]);

    return result.map((json) => Product.fromMap(json)).toList();
  }

  // Get price history for a specific product
  Future<List<Map<String, dynamic>>> getProductPriceHistory(String name) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      '''
      SELECT p.unit_price, p2.date
      FROM products p
      INNER JOIN purchases p2 ON p.purchase_id = p2.id
      WHERE p.name COLLATE NOCASE = ?
      ORDER BY p2.date ASC
    ''',
      [name],
    );

    return result;
  }

  // Get products from purchases that haven't been synced to PocketBase yet
  Future<List<Map<String, dynamic>>> getUnsyncedProducts() async {
    final db = await instance.database;
    return await db.rawQuery('''
      SELECT p.id as product_id, p.name, p.quantity, p.unit_type, p.unit_price, 
             pur.id as purchase_id, pur.date as purchase_date, pur.avulsa, pur.total_value as monthvalue, pur.is_public
      FROM products p
      INNER JOIN purchases pur ON p.purchase_id = pur.id
      WHERE pur.synced = 0
    ''');
  }

  // Get total spent in a specific month (excluding avulsa)
  Future<double> getMonthlyTotal(int month, int year) async {
    final db = await instance.database;
    final String monthStr = month.toString().padLeft(2, '0');
    final String yearMonthPrefix = '$year-$monthStr-';

    final result = await db.rawQuery('''
      SELECT SUM(total_value) as total
      FROM purchases
      WHERE avulsa = 0 AND date LIKE ?
    ''', ['$yearMonthPrefix%']);

    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // Get a list of all distinct months/years and their total spent
  Future<List<Map<String, dynamic>>> getMonthlyTotalsList() async {
    final db = await instance.database;
    // Extract YYYY-MM from date and group by it
    final result = await db.rawQuery('''
      SELECT 
        substr(date, 1, 7) as month_year,
        SUM(total_value) as total
      FROM purchases
      WHERE avulsa = 0
      GROUP BY substr(date, 1, 7)
      ORDER BY month_year DESC
    ''');
    
    return result;
  }

  // Mark all purchases of a specific list of IDs as synced
  Future<void> markPurchasesAsSynced(List<int> purchaseIds) async {
    if (purchaseIds.isEmpty) return;
    final db = await instance.database;
    final placeholders = List.filled(purchaseIds.length, '?').join(',');
    await db.update(
      'purchases',
      {'synced': 1},
      where: 'id IN ($placeholders)',
      whereArgs: purchaseIds,
    );
  }

  // Update a product's image path
  Future<void> updateProductImage(String name, String imagePath) async {
    final db = await instance.database;
    await db.update(
      'products',
      {'image_path': imagePath},
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  // Deletes ALL data (purchases and products) from the database
  // Useful to reset corrupted or test data
  Future<void> deleteAllData() async {
    final db = await instance.database;
    await db.delete('products');
    await db.delete('purchases');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
