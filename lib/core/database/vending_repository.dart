import 'database_helper.dart';

class VendingRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // ۱. تزریق داده‌های اولیه برای تست دیتابیس (اجرا فقط در زمان دیباگ)
  Future<void> seedDummyData() async {
    final db = await _dbHelper.database;
    
    // پاکسازی جداول برای جلوگیری از خطای تکرار کلید در هر بار اجرای تست
    await db.execute('DELETE FROM Racks_Inventory');
    await db.execute('DELETE FROM Products_Catalog');

    // تعریف یک کالا در کاتالوگ
    await db.rawInsert(
      'INSERT INTO Products_Catalog (id, name, image_path, base_price) VALUES (?, ?, ?, ?)',
      [1, 'Coca Cola', '/images/coca.png', 25000]
    );

    // تعریف رک ۵ (سالم) و رک ۸ (معیوب) - عدد 1 به معنای True (فعال) است
    await db.rawInsert(
      'INSERT INTO Racks_Inventory (rack_number, physical_address, product_id, current_price, stock, status) VALUES (?, ?, ?, ?, ?, ?)',
      [5, 1005, 1, 25000, 10, 1] 
    );
    await db.rawInsert(
      'INSERT INTO Racks_Inventory (rack_number, physical_address, product_id, current_price, stock, status) VALUES (?, ?, ?, ?, ?, ?)',
      [8, 1008, 1, 25000, 10, 1] 
    );
  }

  // ۲. کوئری اعمال قرنطینه سیستمی (تغییر status به 0 به معنای False)
  Future<void> quarantineRack(int rackNumber) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE Racks_Inventory SET status = ? WHERE rack_number = ?',
      [0, rackNumber], 
    );
  }

  // ۳. کوئری بررسی وضعیت رک (برای دیباگ لاگ)
  Future<List<Map<String, dynamic>>> checkRackStatus(int rackNumber) async {
    final db = await _dbHelper.database;
    return await db.rawQuery('SELECT rack_number, status FROM Racks_Inventory WHERE rack_number = ?', [rackNumber]);
  }
}