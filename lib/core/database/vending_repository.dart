import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_helper.dart';

class VendingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ۱. تزریق داده‌های اولیه برای تست دیتابیس
  Future<void> seedDummyData() async {
    final db = await _dbHelper.database;
    
    await db.execute('DELETE FROM Racks_Inventory');
    await db.execute('DELETE FROM Products_Catalog');
    await db.execute('DELETE FROM Machine_Layout');
    await db.rawInsert('INSERT INTO Machine_Layout (shelf_number, columns_count) VALUES (?, ?)', [1, 10]);

    // مقدار is_active به صورت پیش‌فرض اضافه شد
    await db.rawInsert(
      'INSERT INTO Products_Catalog (id, name, image_path, base_price, is_active) VALUES (?, ?, ?, ?, ?)',
      [1, 'Coca Cola', '/images/coca.png', 25000, 1]
    );

    await db.rawInsert(
      'INSERT INTO Racks_Inventory (rack_number, physical_address, product_id, current_price, stock, status) VALUES (?, ?, ?, ?, ?, ?)',
      [5, 1005, 1, 25000, 10, 1] 
    );
    await db.rawInsert(
      'INSERT INTO Racks_Inventory (rack_number, physical_address, product_id, current_price, stock, status) VALUES (?, ?, ?, ?, ?, ?)',
      [8, 1008, 1, 25000, 10, 1] 
    );
  }

  Future<void> quarantineRack(int rackNumber) async {
    final db = await _dbHelper.database;
    await db.rawUpdate('UPDATE Racks_Inventory SET status = ? WHERE rack_number = ?', [0, rackNumber]);
  }

  Future<List<Map<String, dynamic>>> checkRackStatus(int rackNumber) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('SELECT rack_number, status FROM Racks_Inventory WHERE rack_number = ?', [rackNumber]);
  }

  // اطلاعات کامل یک رک برای صفحه خرید (نام، عکس، قیمت، موجودی، وضعیت، آدرس فیزیکی)؛ null = رک وجود ندارد
  Future<Map<String, dynamic>?> fetchRackForSale(int rackNumber) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT r.rack_number, r.physical_address, r.current_price, r.stock, r.status,
             p.name AS product_name, p.image_path AS image_path
      FROM Racks_Inventory r
      LEFT JOIN Products_Catalog p ON p.id = r.product_id
      WHERE r.rack_number = ?
    ''', [rackNumber]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> addProduct(String name, String tempImagePath, int basePrice) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String targetDirPath = p.join(appDocDir.path, 'vending_assets', 'products');
    final Directory targetDir = Directory(targetDirPath);
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(tempImagePath)}';
    final String finalImagePath = p.join(targetDirPath, fileName);
    await File(tempImagePath).copy(finalImagePath);

    final db = await _dbHelper.database;
    await db.rawInsert(
      'INSERT INTO Products_Catalog (name, image_path, base_price) VALUES (?, ?, ?)',
      [name, finalImagePath, basePrice]
    );
  }

  // --- متدهای جدید مدیریت لیست محصولات ---

  // واکشی تمام محصولاتی که حذف نرم نشده‌اند
  Future<List<Map<String, dynamic>>> fetchActiveProducts() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('SELECT * FROM Products_Catalog WHERE is_active = 1 ORDER BY id DESC');
  }

  // بررسی اینکه آیا این محصول در رکی که فعال است و موجودی دارد قرار گرفته یا خیر؟
  Future<bool> isProductInActiveRack(int productId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM Racks_Inventory WHERE product_id = ? AND status = 1 AND stock > 0', 
      [productId]
    );
    final count = result.first['count'] as int;
    return count > 0;
  }

  // حذف نرم (Soft Delete)
  Future<void> softDeleteProduct(int id) async {
    final db = await _dbHelper.database;
    await db.rawUpdate('UPDATE Products_Catalog SET is_active = 0 WHERE id = ?', [id]);
  }

  // آپدیت اطلاعات محصول (و کپی تصویر جدید در صورت نیاز)
  Future<void> updateProduct(int id, String name, int price, String? newTempImagePath) async {
    final db = await _dbHelper.database;
    
    if (newTempImagePath != null) {
      // اگر تصویر جدیدی انتخاب شده، آن را کپی کن
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String targetDirPath = p.join(appDocDir.path, 'vending_assets', 'products');
      final Directory targetDir = Directory(targetDirPath);
      if (!await targetDir.exists()) await targetDir.create(recursive: true);

      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(newTempImagePath)}';
      final String finalImagePath = p.join(targetDirPath, fileName);
      await File(newTempImagePath).copy(finalImagePath);

      await db.rawUpdate(
        'UPDATE Products_Catalog SET name = ?, base_price = ?, image_path = ? WHERE id = ?', 
        [name, price, finalImagePath, id]
      );
    } else {
      // فقط آپدیت متن و قیمت
      await db.rawUpdate(
        'UPDATE Products_Catalog SET name = ?, base_price = ? WHERE id = ?', 
        [name, price, id]
      );
    }
  }

  // --- ساختار دستگاه (تنظیمات دستگاه) ---

  Future<List<Map<String, dynamic>>> fetchLayout() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('SELECT * FROM Machine_Layout ORDER BY shelf_number ASC');
  }

  // اعمال ساختار جدید: columnsPerShelf[i] = تعداد رک طبقه i+1
  //
  // - رک‌هایی که جایشان در ساختار جدید هست، همان‌جا می‌مانند.
  // - رک‌هایی که جایشان حذف می‌شود (مثلاً با کم کردن ستون‌های یک طبقه) همراه محصول، قیمت،
  //   موجودی، وضعیت و افزودنی‌هایشان به خانه‌های آزاد منتقل می‌شوند؛ اول خانه‌های تازه
  //   (مثلاً طبقه جدید)، بعد خانه‌های خالی قبلی.
  // - اگر جای کافی نباشد و رکِ بدون جا موجودی داشته باشد، ذخیره رد می‌شود.
  // - شماره رک‌ها همیشه ترتیبی از روی طبقه‌ها ساخته می‌شود و افزودنی‌های هر رک با شماره جدید منتقل می‌شوند.
  //
  // خروجی: error = null یعنی موفق؛ moved = تعداد رک‌های منتقل‌شده
  Future<({String? error, int moved})> applyLayout(List<int> columnsPerShelf) async {
    if (columnsPerShelf.isEmpty) return (error: 'حداقل یک طبقه لازم است', moved: 0);
    if (columnsPerShelf.any((c) => c < 1)) return (error: 'هر طبقه باید حداقل یک رک داشته باشد', moved: 0);
    if (columnsPerShelf.fold<int>(0, (a, b) => a + b) > 99) {
      return (error: 'مجموع رک‌ها نباید بیشتر از ۹۹ باشد', moved: 0);
    }

    final db = await _dbHelper.database;
    final oldLayout = await fetchLayout();
    final oldCols = oldLayout.map((e) => e['columns_count'] as int).toList();
    final racks = await db.rawQuery('SELECT * FROM Racks_Inventory ORDER BY physical_address ASC');

    // افزودنی‌های هر رک بر اساس شماره قدیمی رک (برای انتقال همراه رک)
    final mapperRows = await db.rawQuery(
      'SELECT rack_number, addon_id, addon_value FROM Rack_Addons_Mapper ORDER BY id ASC',
    );
    final Map<int, List<Map<String, Object?>>> addonsByOldRack = {};
    for (final m in mapperRows) {
      addonsByOldRack.putIfAbsent(m['rack_number'] as int, () => <Map<String, Object?>>[]).add(m);
    }

    bool inLayout(List<int> cols, int shelf, int col) =>
        shelf >= 1 && shelf <= cols.length && col >= 1 && col <= cols[shelf - 1];

    // آدرس جدید ← ردیف رک
    final Map<int, Map<String, Object?>> placed = {};
    final List<Map<String, Object?>> orphans = [];
    for (final r in racks) {
      final addr = r['physical_address'] as int;
      if (inLayout(columnsPerShelf, addr ~/ 1000, addr % 1000)) {
        placed[addr] = r;
      } else {
        orphans.add(r);
      }
    }

    int moved = 0;
    if (orphans.isNotEmpty) {
      final List<int> freeNew = []; // خانه‌های آزادِ تازه (در ساختار قبلی وجود نداشتند)
      final List<int> freeOld = []; // خانه‌های خالیِ قبلی
      for (int s = 1; s <= columnsPerShelf.length; s++) {
        for (int c = 1; c <= columnsPerShelf[s - 1]; c++) {
          final addr = s * 1000 + c;
          if (placed.containsKey(addr)) continue;
          if (inLayout(oldCols, s, c)) {
            freeOld.add(addr);
          } else {
            freeNew.add(addr);
          }
        }
      }
      final targets = [...freeNew, ...freeOld];

      final List<Map<String, Object?>> unplaced = [];
      for (int i = 0; i < orphans.length; i++) {
        if (i < targets.length) {
          placed[targets[i]] = orphans[i];
          moved++;
        } else {
          unplaced.add(orphans[i]);
        }
      }
      if (unplaced.any((r) => (r['stock'] as int) > 0)) {
        return (
          error: 'جای کافی برای انتقال رک‌های دارای موجودی نیست؛ تعداد رک‌ها را بیشتر کنید',
          moved: 0,
        );
      }
    }

    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM Rack_Addons_Mapper');
      await txn.rawDelete('DELETE FROM Racks_Inventory');
      await txn.rawDelete('DELETE FROM Machine_Layout');

      for (int i = 0; i < columnsPerShelf.length; i++) {
        await txn.rawInsert(
          'INSERT INTO Machine_Layout (shelf_number, columns_count) VALUES (?, ?)',
          [i + 1, columnsPerShelf[i]],
        );
      }

      for (final entry in placed.entries) {
        final addr = entry.key;
        final r = entry.value;
        final shelf = addr ~/ 1000;
        final col = addr % 1000;
        int before = 0;
        for (int i = 0; i < shelf - 1; i++) {
          before += columnsPerShelf[i];
        }
        final int newRackNumber = before + col;
        await txn.rawInsert(
          'INSERT INTO Racks_Inventory (rack_number, physical_address, product_id, current_price, stock, status) VALUES (?, ?, ?, ?, ?, ?)',
          [newRackNumber, addr, r['product_id'], r['current_price'], r['stock'], r['status']],
        );

        // افزودنی‌های این رک با شماره جدید منتقل می‌شوند
        final oldAddons = addonsByOldRack[r['rack_number'] as int] ?? const <Map<String, Object?>>[];
        for (final m in oldAddons) {
          await txn.rawInsert(
            'INSERT INTO Rack_Addons_Mapper (rack_number, addon_id, addon_value) VALUES (?, ?, ?)',
            [newRackNumber, m['addon_id'], m['addon_value']],
          );
        }
      }
    });
    return (error: null, moved: moved);
  }

  // --- لایوت رک‌ها (محصول‌گذاری) ---

  Future<List<Map<String, dynamic>>> fetchRacksWithProducts() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT r.*, p.name AS product_name
      FROM Racks_Inventory r
      LEFT JOIN Products_Catalog p ON p.id = r.product_id
      ORDER BY r.rack_number ASC
    ''');
  }

  Future<void> saveRack({
    required int rackNumber,
    required int physicalAddress,
    required int productId,
    required int price,
    required int stock,
    required bool active,
  }) async {
    final db = await _dbHelper.database;
    await db.rawInsert(
      'INSERT OR REPLACE INTO Racks_Inventory (rack_number, physical_address, product_id, current_price, stock, status) VALUES (?, ?, ?, ?, ?, ?)',
      [rackNumber, physicalAddress, productId, price, stock, active ? 1 : 0],
    );
  }

  // خالی کردن رک؛ افزودنی‌های آن رک هم حذف می‌شود
  Future<void> clearRack(int rackNumber) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM Rack_Addons_Mapper WHERE rack_number = ?', [rackNumber]);
      await txn.rawDelete('DELETE FROM Racks_Inventory WHERE rack_number = ?', [rackNumber]);
    });
  }
}