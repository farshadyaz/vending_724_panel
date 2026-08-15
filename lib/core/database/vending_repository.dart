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
}