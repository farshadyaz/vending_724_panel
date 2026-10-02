import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'addon_repository.dart';
import 'database_helper.dart';

class _SeedProduct {
  final String key; // نام فایل عکس: assets/images/seed_<key>.png (یا jpg / jpeg / webp)
  final String name;
  final int price; // ریال (تقریبی)
  const _SeedProduct(this.key, this.name, this.price);
}

class _SeedRack {
  final int rack;
  final String productKey;
  final int stock;
  final bool active;
  const _SeedRack(this.rack, this.productKey, this.stock, {this.active = true});
}

/// داده پیش‌فرض تستی؛ فقط وقتی دیتابیس خالی است ساخته می‌شود و بعد از آن هیچ‌وقت پاک نمی‌شود.
class DefaultSeeder {
  static const int shelves = 3;
  static const int columnsPerShelf = 8;
  static const List<String> _imageExts = ['png', 'jpg', 'jpeg', 'webp'];

  static const List<_SeedProduct> products = [
    _SeedProduct('cheetoz', 'چی‌توز پنیری ۹۰ گرم', 450000),
    _SeedProduct('pofak', 'پفک نمکی مزمز ۸۰ گرم', 350000),
    _SeedProduct('chips', 'چیپس مزمز نمکی ۷۰ گرم', 480000),
    _SeedProduct('petibor', 'بیسکوئیت پتی‌بور ۱۰۰ گرم', 300000),
    _SeedProduct('wafer', 'ویفر شکلاتی ۴۰ گرم', 250000),
    _SeedProduct('cake', 'کیک شکلاتی تکی ۶۰ گرم', 280000),
    _SeedProduct('sunflower', 'تخمه آفتابگردان ۱۰۰ گرم', 400000),
    _SeedProduct('pistachio', 'پسته شور ۱۰۰ گرم', 1000000),
    _SeedProduct('mixednuts', 'آجیل مخلوط ۱۰۰ گرم', 700000),
    _SeedProduct('lavashak', 'لواشک میوه‌ای', 150000),
    _SeedProduct('chocolate', 'شکلات شیری ۵۰ گرم', 400000),
    _SeedProduct('gum', 'آدامس بسته‌ای', 100000),
    _SeedProduct('cola', 'نوشابه کوکاکولا قوطی ۳۳۰ میلی', 350000),
    _SeedProduct('doogh', 'دوغ عالیس ۳۰۰ میلی', 200000),
    _SeedProduct('water', 'آب معدنی دماوند ۵۰۰ میلی', 120000),
    _SeedProduct('juice', 'آب‌میوه سان‌ایچ ۲۰۰ میلی', 250000),
  ];

  // رک‌ها: ۱ تا ۸ طبقه اول، ۹ تا ۱۶ طبقه دوم، ۱۷ تا ۲۴ طبقه سوم (رک ۲۴ عمداً خالی)
  static const List<_SeedRack> racks = [
    _SeedRack(1, 'cheetoz', 10),
    _SeedRack(2, 'cheetoz', 6),
    _SeedRack(3, 'pofak', 10),
    _SeedRack(4, 'pofak', 4),
    _SeedRack(5, 'chips', 10),
    _SeedRack(6, 'chips', 2),
    _SeedRack(7, 'petibor', 8),
    _SeedRack(8, 'wafer', 10),
    _SeedRack(9, 'cake', 10),
    _SeedRack(10, 'cake', 5),
    _SeedRack(11, 'sunflower', 10),
    _SeedRack(12, 'sunflower', 0),
    _SeedRack(13, 'pistachio', 7),
    _SeedRack(14, 'mixednuts', 9),
    _SeedRack(15, 'lavashak', 10),
    _SeedRack(16, 'lavashak', 3),
    _SeedRack(17, 'chocolate', 10),
    _SeedRack(18, 'juice', 6),
    _SeedRack(19, 'gum', 10),
    _SeedRack(20, 'cola', 10),
    _SeedRack(21, 'cola', 4, active: false),
    _SeedRack(22, 'doogh', 9),
    _SeedRack(23, 'water', 10),
  ];

  static Future<void> run({bool forceReset = false}) async {
    final db = await DatabaseHelper.instance.database;

    // آماده‌سازی جدول افزودنی‌ها (ستون آیکون + افزودنی‌های پیش‌فرض در اولین اجرا)
    await AddonRepository().ensureSchema();

    final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM Products_Catalog');
    final count = countRows.first['c'] as int;

    // داده تستی قدیمی (فقط یک محصول Coca Cola) هم خالی حساب می‌شود
    bool legacyOnly = false;
    if (count == 1) {
      final r = await db.rawQuery('SELECT name FROM Products_Catalog WHERE id = 1');
      legacyOnly = r.isNotEmpty && r.first['name'] == 'Coca Cola';
    }

    if (forceReset || count == 0 || legacyOnly) {
      await _seed(db);
    }
    await _attachImages(db);
  }

  static Future<void> _seed(Database db) async {
    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM Rack_Addons_Mapper');
      await txn.rawDelete('DELETE FROM Racks_Inventory');
      await txn.rawDelete('DELETE FROM Machine_Layout');
      await txn.rawDelete('DELETE FROM Products_Catalog');
      await txn.rawDelete('DELETE FROM Machine_Addons');

      for (int s = 1; s <= shelves; s++) {
        await txn.rawInsert(
          'INSERT INTO Machine_Layout (shelf_number, columns_count) VALUES (?, ?)',
          [s, columnsPerShelf],
        );
      }

      final Map<String, int> idByKey = {};
      for (int i = 0; i < products.length; i++) {
        final pr = products[i];
        final id = i + 1;
        idByKey[pr.key] = id;
        await txn.rawInsert(
          'INSERT INTO Products_Catalog (id, name, image_path, base_price, is_active) VALUES (?, ?, ?, ?, ?)',
          [id, pr.name, '', pr.price, 1],
        );
      }

      for (final r in racks) {
        final shelf = (r.rack - 1) ~/ columnsPerShelf + 1;
        final col = (r.rack - 1) % columnsPerShelf + 1;
        final productId = idByKey[r.productKey]!;
        final price = products.firstWhere((x) => x.key == r.productKey).price;
        await txn.rawInsert(
          'INSERT INTO Racks_Inventory (rack_number, physical_address, product_id, current_price, stock, status) VALUES (?, ?, ?, ?, ?, ?)',
          [r.rack, shelf * 1000 + col, productId, price, r.stock, r.active ? 1 : 0],
        );
      }

      // افزودنی‌های پیش‌فرض (آبجوش، سس)
      await AddonRepository.seedDefaults(txn);
    });
  }

  // اگر عکس محصول وصل نشده و فایلش در assets/images موجود باشد، به پوشه پایدار کپی و وصل می‌شود
  static Future<void> _attachImages(Database db) async {
    final docs = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docs.path, 'vending_assets', 'products'));

    for (int i = 0; i < products.length; i++) {
      final pr = products[i];
      final id = i + 1;

      final row = await db.rawQuery(
        'SELECT image_path FROM Products_Catalog WHERE id = ? AND name = ?',
        [id, pr.name],
      );
      if (row.isEmpty) continue; // محصول توسط کاربر تغییر کرده یا حذف شده

      final current = row.first['image_path'] as String;
      if (current.isNotEmpty && File(current).existsSync()) continue;

      for (final ext in _imageExts) {
        try {
          final data = await rootBundle.load('assets/images/seed_${pr.key}.$ext');
          if (!await targetDir.exists()) await targetDir.create(recursive: true);
          final file = File(p.join(targetDir.path, 'seed_${pr.key}.$ext'));
          await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
          await db.rawUpdate('UPDATE Products_Catalog SET image_path = ? WHERE id = ?', [file.path, id]);
          break;
        } catch (_) {
          // این پسوند وجود ندارد؛ پسوند بعدی را امتحان کن
        }
      }
    }
  }
}