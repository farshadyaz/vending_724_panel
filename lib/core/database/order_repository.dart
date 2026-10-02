import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

/// وضعیت سفارش/پرداخت (ستون pos_status در جدول Orders)
class OrderStatus {
  static const String pending = 'PENDING'; // سفارش ساخته شده، پرداخت هنوز نتیجه‌ای نداده
  static const String paid = 'PAID'; // پرداخت تأیید شد
  static const String declined = 'DECLINED'; // کارت رد شد
  static const String cancelled = 'CANCELLED'; // مشتری یا پوز پرداخت را لغو کرد
  static const String paymentTimeout = 'PAYMENT_TIMEOUT'; // پوز پاسخ نداد (وضعیت مبلغ نامعلوم)
  static const String posError = 'POS_ERROR'; // ارتباط با پوز برقرار نشد
  static const String refunded = 'REFUNDED'; // کل مبلغ برگشت داده شد
  static const String partialRefunded = 'PARTIAL_REFUNDED'; // بخشی از مبلغ برگشت داده شد
  static const String refundFailed = 'REFUND_FAILED'; // بازگشت وجه خودکار ناموفق بود (پیگیری دستی)
  static const String refundUnknown = 'REFUND_UNKNOWN'; // نتیجه بازگشت وجه نامعلوم است (اول پوز بررسی شود)
  static const String needsReview = 'NEEDS_REVIEW'; // سفارش نیمه‌تمام ماند (قطع برق/بسته شدن برنامه)
}

/// وضعیت تحویل هر کالا (ستون delivery_status در جدول Order_Items)
class ItemStatus {
  static const String pending = 'PENDING';
  static const String delivered = 'DELIVERED';
  static const String failed = 'FAILED'; // برد پاسخ داد ولی کالا تحویل نشد
  static const String unknown = 'UNKNOWN'; // نتیجه تحویل نامعلوم (تایم‌اوت/قطع ارتباط)
  static const String cancelled = 'CANCELLED'; // پرداخت انجام نشد
}

/// مشکلی که هنگام بررسی نهایی سبد پیدا می‌شود
class CartIssue {
  final int rackNumber;
  final String name;
  final String reason;
  const CartIssue(this.rackNumber, this.name, this.reason);
}

/// ثبت سفارش‌ها، آیتم‌ها، موجودی و لاگ سیستم برای چرخه خرید
class OrderRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  String _now() => DateTime.now().toIso8601String();

  /// ستون‌های جدید را در صورت نبودن اضافه می‌کند؛ بدون تغییر نسخه دیتابیس و بدون از دست رفتن اطلاعات:
  ///  - Orders.pos_reference (کد مرجع پوز) و Orders.refunded_amount (مبلغ بازگشتی)
  ///  - Order_Items.physical_address (آدرس فیزیکی رک؛ چون شماره رک با تغییر چیدمان عوض می‌شود)
  Future<Database> _dbWithColumns() async {
    final db = await _dbHelper.database;

    final orderCols = await db.rawQuery('PRAGMA table_info(Orders)');
    final orderNames = orderCols.map((c) => c['name'].toString()).toSet();
    if (!orderNames.contains('pos_reference')) {
      await db.execute('ALTER TABLE Orders ADD COLUMN pos_reference TEXT');
    }
    if (!orderNames.contains('refunded_amount')) {
      await db.execute('ALTER TABLE Orders ADD COLUMN refunded_amount INTEGER NOT NULL DEFAULT 0');
    }

    final itemCols = await db.rawQuery('PRAGMA table_info(Order_Items)');
    final itemNames = itemCols.map((c) => c['name'].toString()).toSet();
    if (!itemNames.contains('physical_address')) {
      await db.execute('ALTER TABLE Order_Items ADD COLUMN physical_address INTEGER');
    }
    return db;
  }

  // ---------------- بررسی سبد ----------------

  /// بررسی نهایی سبد درست قبل از پرداخت (ممکن است ادمین بین انتخاب و پرداخت رک را تغییر داده باشد)
  Future<List<CartIssue>> validateCart(List<Map<String, dynamic>> cart) async {
    final db = await _dbHelper.database;
    final Map<int, List<Map<String, dynamic>>> byRack = {};
    for (final item in cart) {
      byRack.putIfAbsent(item['rack_number'] as int, () => <Map<String, dynamic>>[]).add(item);
    }

    final issues = <CartIssue>[];
    for (final entry in byRack.entries) {
      final int rack = entry.key;
      final items = entry.value;
      final String name = (items.first['name'] ?? 'کالا').toString();

      final rows = await db.rawQuery(
        'SELECT physical_address, current_price, stock, status FROM Racks_Inventory WHERE rack_number = ?',
        [rack],
      );
      if (rows.isEmpty) {
        issues.add(CartIssue(rack, name, 'این رک دیگر وجود ندارد'));
        continue;
      }
      final r = rows.first;
      if (items.any((i) => i['physical_address'] != r['physical_address'])) {
        // شماره رک بعد از تغییر چیدمان دستگاه به رک فیزیکی دیگری رسیده است
        issues.add(CartIssue(rack, name, 'جای این رک تغییر کرده است'));
        continue;
      }
      if ((r['status'] as int) != 1) {
        issues.add(CartIssue(rack, name, 'این رک غیرفعال شده است'));
        continue;
      }
      if ((r['stock'] as int) < items.length) {
        issues.add(CartIssue(rack, name, 'موجودی این کالا کافی نیست'));
        continue;
      }
      final int price = r['current_price'] as int;
      if (items.any((i) => (i['price'] as int) != price)) {
        issues.add(CartIssue(rack, name, 'قیمت این کالا تغییر کرده است'));
      }
    }
    return issues;
  }

  // ---------------- سفارش ----------------

  /// ثبت سفارش و آیتم‌های آن قبل از پرداخت (وضعیت PENDING)؛ هر آیتم سبد = یک واحد کالا.
  /// شناسه محصول و آدرس فیزیکی از جدول رک‌ها خوانده می‌شود.
  Future<void> createOrder({
    required String orderId,
    required List<Map<String, dynamic>> cart,
    required int cartCapacity,
  }) async {
    final db = await _dbWithColumns();
    final int total = cart.fold<int>(0, (sum, item) => sum + (item['price'] as int));
    final String now = _now();

    await db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT INTO Orders (id, total_amount, cart_capacity, pos_status, timestamp) VALUES (?, ?, ?, ?, ?)',
        [orderId, total, cartCapacity, OrderStatus.pending, now],
      );
      for (final item in cart) {
        final int rack = item['rack_number'] as int;
        final rows = await txn.rawQuery(
          'SELECT product_id, physical_address FROM Racks_Inventory WHERE rack_number = ?',
          [rack],
        );
        if (rows.isEmpty) {
          throw StateError('رک $rack برای ثبت سفارش پیدا نشد');
        }
        await txn.rawInsert(
          'INSERT INTO Order_Items (order_id, rack_number, product_id, sold_price, delivery_status, physical_address) VALUES (?, ?, ?, ?, ?, ?)',
          [orderId, rack, rows.first['product_id'], item['price'], ItemStatus.pending, rows.first['physical_address']],
        );
      }
    });
  }

  /// تأیید پرداخت: وضعیت سفارش و آیتم‌ها (در انتظار تحویل) در یک تراکنش ثبت می‌شود
  Future<void> markPaid(String orderId, {String? reference}) async {
    final db = await _dbWithColumns();
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE Orders SET pos_status = ?, pos_reference = COALESCE(?, pos_reference) WHERE id = ?',
        [OrderStatus.paid, reference, orderId],
      );
      await txn.rawUpdate(
        'UPDATE Order_Items SET delivery_status = ? WHERE order_id = ?',
        [ItemStatus.pending, orderId],
      );
    });
  }

  /// قبل از «تلاش مجدد» پرداخت (بعد از رد شدن کارت): سفارش دوباره PENDING می‌شود تا اگر وسط تلاش مجدد
  /// پوز پرداخت را تأیید کرد و برق رفت، بعد از راه‌اندازی مجدد به‌عنوان سفارش نیمه‌تمام علامت بخورد.
  Future<void> reopenForPayment(String orderId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE Orders SET pos_status = ? WHERE id = ?', [OrderStatus.pending, orderId]);
      await txn.rawUpdate('UPDATE Order_Items SET delivery_status = ? WHERE order_id = ?', [ItemStatus.pending, orderId]);
    });
  }

  Future<void> setPaymentStatus(String orderId, String status, {String? reference}) async {
    final db = await _dbWithColumns();
    await db.rawUpdate(
      'UPDATE Orders SET pos_status = ?, pos_reference = COALESCE(?, pos_reference) WHERE id = ?',
      [status, reference, orderId],
    );
  }

  /// وضعیت همه آیتم‌های سفارش (مثلاً CANCELLED وقتی پرداخت انجام نشده)
  Future<void> setAllItemsStatus(String orderId, String status) async {
    final db = await _dbHelper.database;
    await db.rawUpdate('UPDATE Order_Items SET delivery_status = ? WHERE order_id = ?', [status, orderId]);
  }

  /// ثبت نتیجه تحویل در یک تراکنش: deliveredByRack = تعداد تحویل‌شده هر رک.
  /// آیتم‌های هر رک به ترتیب ثبت، اول DELIVERED می‌شوند و بقیه undeliveredStatus می‌گیرند؛
  /// موجودی رک فقط به اندازه کالاهای تحویل‌شده کم می‌شود.
  Future<void> recordDispense(
    String orderId,
    Map<int, int> deliveredByRack, {
    required String undeliveredStatus,
  }) async {
    final db = await _dbHelper.database;
    final String now = _now();
    await db.transaction((txn) async {
      final racks = await txn.rawQuery('SELECT DISTINCT rack_number FROM Order_Items WHERE order_id = ?', [orderId]);
      for (final row in racks) {
        final int rack = row['rack_number'] as int;
        final items = await txn.rawQuery(
          'SELECT id FROM Order_Items WHERE order_id = ? AND rack_number = ? ORDER BY id ASC',
          [orderId, rack],
        );
        final int delivered = (deliveredByRack[rack] ?? 0).clamp(0, items.length).toInt();
        for (int i = 0; i < items.length; i++) {
          final bool ok = i < delivered;
          await txn.rawUpdate(
            'UPDATE Order_Items SET delivery_status = ?, delivered_at = ? WHERE id = ?',
            [ok ? ItemStatus.delivered : undeliveredStatus, ok ? now : null, items[i]['id']],
          );
        }
        if (delivered > 0) {
          await txn.rawUpdate(
            'UPDATE Racks_Inventory SET stock = MAX(stock - ?, 0) WHERE rack_number = ?',
            [delivered, rack],
          );
        }
      }
    });
  }

  /// ثبت نتیجه بازگشت وجه (status یکی از REFUNDED / PARTIAL_REFUNDED / REFUND_FAILED / REFUND_UNKNOWN)
  Future<void> setRefund(String orderId, {required String status, required int amount}) async {
    final db = await _dbWithColumns();
    await db.rawUpdate(
      'UPDATE Orders SET pos_status = ?, refunded_amount = ? WHERE id = ?',
      [status, amount, orderId],
    );
  }

  // ---------------- لاگ سیستم ----------------

  /// ثبت یک رویداد در System_Logs؛ خطای ثبت لاگ هیچ‌وقت جلوی چرخه خرید را نمی‌گیرد.
  /// type: OP (عملیاتی) | SOFT (خطای نرم) | HARD (خطای سخت)
  Future<void> log(String type, String code, String description) async {
    try {
      final db = await _dbHelper.database;
      await db.rawInsert(
        'INSERT INTO System_Logs (log_type, error_code, description, timestamp, is_synced) VALUES (?, ?, ?, ?, 0)',
        [type, code, description, _now()],
      );
    } catch (e) {
      debugPrint('WARNING: system log failed ($code): $e');
    }
  }

  // ---------------- بازیابی بعد از قطعی ----------------

  /// سفارش‌هایی که وسط کار مانده‌اند (برق رفت یا برنامه بسته شد) را علامت می‌زند تا تکنسین بررسی کند:
  ///  - سفارش PENDING: نتیجه پرداخت نامعلوم است
  ///  - سفارش PAID که همه کالاهایش DELIVERED نشده؛ چون هر نتیجه نهایی دیگری (بازگشت وجه کامل/جزئی/ناموفق)
  ///    وضعیت سفارش را از PAID تغییر می‌دهد، پس PAID با کالای تحویل‌نشده یعنی کار نیمه‌تمام مانده است
  /// فقط هنگام شروع برنامه صدا زده شود. تعداد سفارش‌های علامت‌خورده را برمی‌گرداند.
  Future<int> recoverInterruptedOrders() async {
    final db = await _dbWithColumns();
    final rows = await db.rawQuery(
      '''
      SELECT o.id AS id, o.pos_status AS status FROM Orders o
      WHERE o.pos_status = ?
         OR (o.pos_status = ? AND EXISTS (
              SELECT 1 FROM Order_Items i
              WHERE i.order_id = o.id AND i.delivery_status <> ?))
      ''',
      [OrderStatus.pending, OrderStatus.paid, ItemStatus.delivered],
    );

    for (final row in rows) {
      final String id = row['id'].toString();
      final String status = row['status'].toString();

      final racks = await db.rawQuery(
        'SELECT DISTINCT rack_number, physical_address FROM Order_Items WHERE order_id = ? ORDER BY rack_number',
        [id],
      );
      final String rackText = racks
          .map((r) => r['physical_address'] == null
              ? 'رک ${r['rack_number']}'
              : 'رک ${r['rack_number']} (آدرس ${r['physical_address']})')
          .join('، ');

      await db.transaction((txn) async {
        await txn.rawUpdate('UPDATE Orders SET pos_status = ? WHERE id = ?', [OrderStatus.needsReview, id]);
        await txn.rawUpdate(
          'UPDATE Order_Items SET delivery_status = ? WHERE order_id = ? AND delivery_status IN (?, ?)',
          [ItemStatus.unknown, id, ItemStatus.pending, ItemStatus.cancelled],
        );
      });
      await log(
        'HARD',
        'ORDER_INTERRUPTED',
        'سفارش $id وسط کار متوقف شده بود (وضعیت قبلی: $status؛ $rackText)؛ وضعیت پرداخت و تحویل باید دستی بررسی شود',
      );
    }
    return rows.length;
  }
}
