// مسیر: lib/core/database/report_repository.dart
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../utils/jalali.dart';
import 'order_repository.dart';

// ---------------------------------------------------------------------------
// بازه زمانی گزارش
// ---------------------------------------------------------------------------

/// بازه زمانی گزارش (ابتدا شامل، انتها غیرشامل)؛ start و end هر دو null یعنی «همه»
class ReportRange {
  final String key;
  final String label;
  final DateTime? start;
  final DateTime? end;

  const ReportRange({required this.key, required this.label, this.start, this.end});

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// بازه‌های آماده؛ ماه‌ها شمسی‌اند
  static List<ReportRange> presets(DateTime now) {
    final today = _midnight(now);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final j = Jalali.fromDateTime(today);
    final monthStart = Jalali(j.year, j.month, 1);
    final nextMonth = j.month == 12 ? Jalali(j.year + 1, 1, 1) : Jalali(j.year, j.month + 1, 1);
    final prevMonth = j.month == 1 ? Jalali(j.year - 1, 12, 1) : Jalali(j.year, j.month - 1, 1);
    return [
      ReportRange(key: 'today', label: 'امروز', start: today, end: tomorrow),
      ReportRange(key: 'yesterday', label: 'دیروز', start: DateTime(today.year, today.month, today.day - 1), end: today),
      ReportRange(key: 'last7', label: '۷ روز اخیر', start: DateTime(today.year, today.month, today.day - 6), end: tomorrow),
      ReportRange(key: 'last30', label: '۳۰ روز اخیر', start: DateTime(today.year, today.month, today.day - 29), end: tomorrow),
      ReportRange(
        key: 'month',
        label: 'این ماه (${Jalali.monthNames[j.month - 1]})',
        start: monthStart.toDateTime(),
        end: nextMonth.toDateTime(),
      ),
      ReportRange(
        key: 'prevMonth',
        label: 'ماه قبل (${Jalali.monthNames[prevMonth.month - 1]})',
        start: prevMonth.toDateTime(),
        end: monthStart.toDateTime(),
      ),
      const ReportRange(key: 'all', label: 'همه'),
    ];
  }

  /// تعداد روزهای بازه (فقط وقتی هر دو سر مشخص باشد)
  int? get dayCount {
    final s = start;
    final e = end;
    if (s == null || e == null) return null;
    return (e.difference(s).inHours / 24).round();
  }

  /// شرط SQL روی ستون زمان؛ مقدارها به args اضافه می‌شوند.
  /// زمان‌ها در دیتابیس به‌صورت ISO محلی ذخیره شده‌اند و مقایسه رشته‌ای با آن درست است.
  String sql(String column, List<Object?> args) {
    final buffer = StringBuffer();
    if (start != null) {
      buffer.write(' AND $column >= ?');
      args.add(start!.toIso8601String());
    }
    if (end != null) {
      buffer.write(' AND $column < ?');
      args.add(end!.toIso8601String());
    }
    return buffer.toString();
  }
}

// ---------------------------------------------------------------------------
// نام‌های فارسی وضعیت‌ها و کدهای لاگ
// ---------------------------------------------------------------------------

class ReportLabels {
  static const Map<String, String> orderStatus = {
    OrderStatus.pending: 'در انتظار پرداخت',
    OrderStatus.paid: 'پرداخت‌شده',
    OrderStatus.declined: 'کارت رد شد',
    OrderStatus.cancelled: 'لغو شد',
    OrderStatus.paymentTimeout: 'پاسخ پوز نرسید',
    OrderStatus.posError: 'خطای ارتباط با پوز',
    OrderStatus.settlementDue: 'مطالبه مشتری',
    OrderStatus.needsReview: 'نیازمند بررسی',
  };

  static const Map<String, String> itemStatus = {
    ItemStatus.pending: 'در انتظار',
    ItemStatus.delivered: 'تحویل شد',
    ItemStatus.failed: 'تحویل نشد',
    ItemStatus.unknown: 'نامعلوم',
    ItemStatus.cancelled: 'لغو',
  };

  static const Map<String, String> logType = {
    'OP': 'عملیاتی',
    'SOFT': 'هشدار',
    'HARD': 'خطای جدی',
  };

  static const Map<String, String> logCode = {
    'ORDER_CREATED': 'ثبت سفارش',
    'PAY_APPROVED': 'پرداخت تأیید شد',
    'PAY_DECLINED': 'کارت رد شد',
    'PAY_CANCELLED': 'پرداخت لغو شد',
    'PAY_TIMEOUT': 'پوز پاسخ نداد',
    'PAY_RETRY': 'تلاش مجدد پرداخت',
    'POS_CONNECTION': 'قطع ارتباط با پوز',
    'ORDER_DONE': 'تحویل کامل',
    'ORDER_PARTIAL': 'تحویل ناقص',
    'SETTLEMENT_DUE': 'مطالبه مشتری',
    'ORDER_RESOLVED': 'بستن مورد پیگیری',
    'ORDER_INTERRUPTED': 'سفارش نیمه‌تمام',
    'CHECKOUT_START': 'خطای شروع خرید',
    'CHECKOUT_RETRY': 'خطای تلاش مجدد',
    'BOARD_UNAVAILABLE': 'برد در دسترس نبود',
    'BOARD_TIMEOUT': 'برد پاسخ نداد',
    'BOARD_CONNECTION': 'قطع ارتباط با برد',
    'H-1001': 'خرابی موتور رک',
    'RACK_FAILED': 'رک کامل تحویل نداد',
  };

  static String order(String status) => orderStatus[status] ?? status;
  static String item(String status) => itemStatus[status] ?? status;
  static String type(String t) => logType[t] ?? t;
  static String code(String c) => logCode[c] ?? c;
}

// ---------------------------------------------------------------------------
// مدل‌ها
// ---------------------------------------------------------------------------

enum LogCategory { all, panel, board }

DateTime? _parseTime(Object? raw) => raw == null ? null : DateTime.tryParse(raw.toString());

int _int(Object? v) => v is num ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? 0);

class SalesSummary {
  /// سفارش‌هایی که پرداخت‌شان قطعی است (پرداخت‌شده + مطالبه مشتری)
  final int soldOrders;
  final int completeOrders; // همه کالاها تحویل شد
  final int partialOrders; // بخشی یا همه کالاها تحویل نشد (مطالبه مشتری)
  final int grossAmount; // جمع پرداخت مشتریان
  final int owedAmount; // جمع مبلغ مطالبه‌شده مشتریان (کالای تحویل‌نشده)
  final int owedOpenAmount; // بخشی از مطالبات که هنوز تسویه نشده
  final int deliveredUnits;
  final int undeliveredUnits;
  final int uncertainOrders; // پرداخت یا تحویل نامعلوم (نیازمند بررسی)
  final int uncertainAmount;
  final int declinedOrders;
  final int cancelledOrders;
  final int totalOrders;

  const SalesSummary({
    this.soldOrders = 0,
    this.completeOrders = 0,
    this.partialOrders = 0,
    this.grossAmount = 0,
    this.owedAmount = 0,
    this.owedOpenAmount = 0,
    this.deliveredUnits = 0,
    this.undeliveredUnits = 0,
    this.uncertainOrders = 0,
    this.uncertainAmount = 0,
    this.declinedOrders = 0,
    this.cancelledOrders = 0,
    this.totalOrders = 0,
  });

  /// فروش خالص = آنچه مشتری پرداخته منهای مبلغ کالاهایی که تحویل نشده و باید به او برگردد
  int get netRevenue => grossAmount - owedAmount;
}

class DaySales {
  final DateTime day;
  final int orders;
  final int revenue;
  const DaySales(this.day, this.orders, this.revenue);
}

class ProductSales {
  final int? productId;
  final String name;
  final int units;
  final int revenue;
  const ProductSales(this.productId, this.name, this.units, this.revenue);
}

class RackSales {
  final int rackNumber;
  final int? physicalAddress;
  final String productName;
  final int delivered;
  final int failed; // تحویل نشده (خطای برد یا نتیجه نامعلوم)
  final int revenue;
  const RackSales({
    required this.rackNumber,
    required this.physicalAddress,
    required this.productName,
    required this.delivered,
    required this.failed,
    required this.revenue,
  });
}

class OrderRow {
  final String id;
  final String rawTime;
  final DateTime? time;
  final String status;
  final int total;
  final int owed;
  final String? reference;
  final int itemCount;
  final int deliveredCount;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  const OrderRow({
    required this.id,
    required this.rawTime,
    required this.time,
    required this.status,
    required this.total,
    required this.owed,
    required this.reference,
    required this.itemCount,
    required this.deliveredCount,
    required this.resolvedAt,
    required this.resolvedBy,
  });

  bool get isSold => status == OrderStatus.paid || status == OrderStatus.settlementDue;

  /// مبلغ خالص این سفارش در فروش (برای سفارش‌های پرداخت‌نشده یا نامعلوم صفر است)
  int get net => isSold ? total - owed : 0;

  bool get resolved => resolvedAt != null;

  factory OrderRow.fromMap(Map<String, Object?> m) => OrderRow(
        id: m['id'].toString(),
        rawTime: (m['timestamp'] ?? '').toString(),
        time: _parseTime(m['timestamp']),
        status: (m['pos_status'] ?? '').toString(),
        total: _int(m['total_amount']),
        owed: _int(m['owed_amount']),
        reference: m['pos_reference']?.toString(),
        itemCount: _int(m['ic']),
        deliveredCount: _int(m['dc']),
        resolvedAt: _parseTime(m['resolved_at']),
        resolvedBy: m['resolved_by']?.toString(),
      );
}

class OrderItemRow {
  final int id;
  final int rackNumber;
  final int? physicalAddress;
  final String productName;
  final int price;
  final String status;
  final DateTime? deliveredAt;
  const OrderItemRow({
    required this.id,
    required this.rackNumber,
    required this.physicalAddress,
    required this.productName,
    required this.price,
    required this.status,
    required this.deliveredAt,
  });
}

class LogEntry {
  final int id;
  final String type;
  final String code;
  final String description;
  final String rawTime;
  final DateTime? time;
  const LogEntry({
    required this.id,
    required this.type,
    required this.code,
    required this.description,
    required this.rawTime,
    required this.time,
  });

  /// شناسه سفارشی که در متن لاگ آمده (اگر باشد)
  String? get orderId => RegExp(r'ORD-[A-Za-z0-9]+').firstMatch(description)?.group(0);

  factory LogEntry.fromMap(Map<String, Object?> m) => LogEntry(
        id: _int(m['id']),
        type: (m['log_type'] ?? '').toString(),
        code: (m['error_code'] ?? '').toString(),
        description: (m['description'] ?? '').toString(),
        rawTime: (m['timestamp'] ?? '').toString(),
        time: _parseTime(m['timestamp']),
      );
}

/// یک سفارش همراه با کالاهایش (و در صورت نیاز لاگ‌های مربوط به آن)
class OrderDetail {
  final OrderRow order;
  final List<OrderItemRow> items;
  final List<LogEntry> logs;
  const OrderDetail(this.order, this.items, this.logs);
}

enum OrderFilter { all, complete, settlement, review, failed }

/// گروه موارد نیازمند پیگیری: مطالبه مشتری یا سفارش نامعلوم
enum AttentionGroup { all, settlement, review }

/// نتیجه‌ای که اپراتور هنگام بستن یک مورد ثبت می‌کند؛ هر نتیجه حسابداری سفارش را هم درست می‌کند.
enum ResolveOutcome {
  /// مبلغ مطالبه با مشتری تسویه شد (فقط برای «مطالبه مشتری»)
  settled,

  /// کالا در واقع تحویل شده بود: سفارش «پرداخت‌شده» و کامل می‌شود و موجودی رک‌ها کم می‌شود
  delivered,

  /// فقط بخشی از کالاهای نتیجه‌نشده تحویل شده بود: همان‌ها «تحویل‌شده» می‌شوند و مطالبه مشتری فقط برای بقیه می‌ماند (باز)
  partial,

  /// پرداخت انجام شده ولی کالا تحویل نشده: مبلغ کالاهای تحویل‌نشده «مطالبه مشتری» ثبت می‌شود (و باز می‌ماند)
  paidNotDelivered,

  /// پرداخت انجام نشده بود: سفارش لغو می‌شود و فروشی حساب نمی‌شود
  notPaid,
}

class AttentionStats {
  final int openSettlement; // مطالبه مشتری باز
  final int openReview; // سفارش نامعلوم باز
  final int openOwedTotal; // جمع مبلغ مطالبه‌های باز
  final int closed;
  const AttentionStats({this.openSettlement = 0, this.openReview = 0, this.openOwedTotal = 0, this.closed = 0});

  int get open => openSettlement + openReview;
}

// ---------------------------------------------------------------------------
// ریپازیتوری گزارش‌ها و لاگ‌ها
// ---------------------------------------------------------------------------

class ReportRepository {
  final OrderRepository _orders;

  ReportRepository({OrderRepository? orders}) : _orders = orders ?? OrderRepository();

  /// وضعیت‌هایی که پرداختشان قطعی است و در فروش حساب می‌شوند
  static const List<String> soldStatuses = [OrderStatus.paid, OrderStatus.settlementDue];

  /// وضعیت‌هایی که نتیجه پرداخت یا تحویل‌شان نامعلوم است و باید بررسی شوند
  static const List<String> uncertainStatuses = [
    OrderStatus.needsReview,
    OrderStatus.paymentTimeout,
    OrderStatus.posError,
  ];

  /// وضعیت‌هایی که اپراتور باید پیگیری و سپس «ببندد»
  static const List<String> attentionStatuses = [
    OrderStatus.settlementDue,
    OrderStatus.needsReview,
    OrderStatus.paymentTimeout,
    OrderStatus.posError,
  ];

  static List<String> statusesFor(OrderFilter filter) {
    switch (filter) {
      case OrderFilter.all:
        return const [];
      case OrderFilter.complete:
        return const [OrderStatus.paid];
      case OrderFilter.settlement:
        return const [OrderStatus.settlementDue];
      case OrderFilter.review:
        return const [OrderStatus.needsReview, OrderStatus.paymentTimeout, OrderStatus.posError, OrderStatus.pending];
      case OrderFilter.failed:
        return const [OrderStatus.declined, OrderStatus.cancelled];
    }
  }

  /// شرط SQL برای کدهای مربوط به برد
  static const String _boardCodeSql =
      "(substr(error_code, 1, 2) = 'H-' OR substr(error_code, 1, 6) = 'BOARD_' OR error_code = 'RACK_FAILED')";

  Future<Database> _db() => _orders.ensureSchema();

  static String _marks(int n) => List.filled(n, '?').join(',');

  // ---------------- فروش ----------------

  Future<SalesSummary> salesSummary(ReportRange range) async {
    final db = await _db();

    final args = <Object?>[];
    final rows = await db.rawQuery(
      '''
      SELECT pos_status AS s, COUNT(*) AS c, COALESCE(SUM(total_amount), 0) AS t, COALESCE(SUM(owed_amount), 0) AS o,
             COALESCE(SUM(CASE WHEN resolved_at IS NULL THEN owed_amount ELSE 0 END), 0) AS oo
      FROM Orders WHERE 1 = 1${range.sql('timestamp', args)}
      GROUP BY pos_status
      ''',
      args,
    );

    int total = 0, complete = 0, partial = 0, gross = 0, owed = 0, owedOpen = 0;
    int uncertain = 0, uncertainAmount = 0, declined = 0, cancelled = 0;
    for (final r in rows) {
      final String s = r['s'].toString();
      final int c = _int(r['c']);
      total += c;
      if (s == OrderStatus.paid) {
        complete += c;
        gross += _int(r['t']);
        owed += _int(r['o']);
      } else if (s == OrderStatus.settlementDue) {
        partial += c;
        gross += _int(r['t']);
        owed += _int(r['o']);
        owedOpen += _int(r['oo']);
      } else if (uncertainStatuses.contains(s)) {
        uncertain += c;
        uncertainAmount += _int(r['t']);
      } else if (s == OrderStatus.declined) {
        declined += c;
      } else if (s == OrderStatus.cancelled) {
        cancelled += c;
      }
    }

    final unitArgs = <Object?>[...soldStatuses];
    final units = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN i.delivery_status = ? THEN 1 ELSE 0 END), 0) AS d,
             COALESCE(SUM(CASE WHEN i.delivery_status <> ? THEN 1 ELSE 0 END), 0) AS u
      FROM Order_Items i JOIN Orders o ON o.id = i.order_id
      WHERE o.pos_status IN (${_marks(soldStatuses.length)})${range.sql('o.timestamp', unitArgs)}
      ''',
      [ItemStatus.delivered, ItemStatus.delivered, ...unitArgs],
    );

    return SalesSummary(
      soldOrders: complete + partial,
      completeOrders: complete,
      partialOrders: partial,
      grossAmount: gross,
      owedAmount: owed,
      owedOpenAmount: owedOpen,
      deliveredUnits: _int(units.first['d']),
      undeliveredUnits: _int(units.first['u']),
      uncertainOrders: uncertain,
      uncertainAmount: uncertainAmount,
      declinedOrders: declined,
      cancelledOrders: cancelled,
      totalOrders: total,
    );
  }

  /// فروش روزانه (جدیدترین روز اول). برای بازه‌های کوتاه، روزهای بدون فروش هم با مقدار صفر می‌آیند.
  Future<List<DaySales>> salesByDay(ReportRange range, {DateTime? now}) async {
    final db = await _db();
    final args = <Object?>[...soldStatuses];
    final rows = await db.rawQuery(
      '''
      SELECT substr(timestamp, 1, 10) AS d, COUNT(*) AS c, COALESCE(SUM(total_amount - owed_amount), 0) AS r
      FROM Orders WHERE pos_status IN (${_marks(soldStatuses.length)})${range.sql('timestamp', args)}
      GROUP BY d ORDER BY d DESC
      ''',
      args,
    );

    final Map<String, DaySales> byKey = {};
    for (final r in rows) {
      final day = DateTime.tryParse(r['d'].toString());
      if (day == null) continue;
      byKey[r['d'].toString()] = DaySales(DateTime(day.year, day.month, day.day), _int(r['c']), _int(r['r']));
    }

    final days = range.dayCount;
    if (days != null && days <= 62 && range.start != null) {
      final start = range.start!;
      // روزهای آینده (مثلاً بقیه ماه جاری) صفر نشان داده نمی‌شوند؛ آخرین ردیف امروز است
      final base = now ?? DateTime.now();
      final tomorrow = DateTime(base.year, base.month, base.day + 1);
      final end = range.end!.isAfter(tomorrow) ? tomorrow : range.end!;
      final shown = (end.difference(start).inHours / 24).round();
      final result = <DaySales>[];
      for (int i = shown - 1; i >= 0; i--) {
        final d = DateTime(start.year, start.month, start.day + i);
        final key = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        result.add(byKey[key] ?? DaySales(d, 0, 0));
      }
      return result;
    }
    return byKey.values.toList();
  }

  Future<List<ProductSales>> salesByProduct(ReportRange range) async {
    final db = await _db();
    final args = <Object?>[...soldStatuses, ItemStatus.delivered];
    final rows = await db.rawQuery(
      '''
      SELECT i.product_id AS pid, COALESCE(p.name, 'محصول حذف‌شده') AS name, COUNT(*) AS u, COALESCE(SUM(i.sold_price), 0) AS r
      FROM Order_Items i JOIN Orders o ON o.id = i.order_id
      LEFT JOIN Products_Catalog p ON p.id = i.product_id
      WHERE o.pos_status IN (${_marks(soldStatuses.length)}) AND i.delivery_status = ?${range.sql('o.timestamp', args)}
      GROUP BY i.product_id ORDER BY u DESC, r DESC
      ''',
      args,
    );
    return [for (final r in rows) ProductSales(r['pid'] as int?, r['name'].toString(), _int(r['u']), _int(r['r']))];
  }

  /// فروش به تفکیک رک؛ ستون «تحویل نشده» برای پیدا کردن رک‌های خراب است
  Future<List<RackSales>> salesByRack(ReportRange range) async {
    final db = await _db();
    final args = <Object?>[ItemStatus.delivered, ItemStatus.delivered, ItemStatus.delivered, ...soldStatuses];
    final rows = await db.rawQuery(
      '''
      SELECT i.rack_number AS rack, i.physical_address AS addr,
             COALESCE(MAX(p.name), 'محصول حذف‌شده') AS name,
             COALESCE(SUM(CASE WHEN i.delivery_status = ? THEN 1 ELSE 0 END), 0) AS d,
             COALESCE(SUM(CASE WHEN i.delivery_status <> ? THEN 1 ELSE 0 END), 0) AS f,
             COALESCE(SUM(CASE WHEN i.delivery_status = ? THEN i.sold_price ELSE 0 END), 0) AS r
      FROM Order_Items i JOIN Orders o ON o.id = i.order_id
      LEFT JOIN Products_Catalog p ON p.id = i.product_id
      WHERE o.pos_status IN (${_marks(soldStatuses.length)})${range.sql('o.timestamp', args)}
      GROUP BY i.rack_number, i.physical_address ORDER BY i.rack_number, i.physical_address
      ''',
      args,
    );
    return [
      for (final r in rows)
        RackSales(
          rackNumber: _int(r['rack']),
          physicalAddress: r['addr'] as int?,
          productName: r['name'].toString(),
          delivered: _int(r['d']),
          failed: _int(r['f']),
          revenue: _int(r['r']),
        ),
    ];
  }

  // ---------------- سفارش‌ها ----------------

  static const String _orderSelect = '''
      SELECT o.id, o.timestamp, o.pos_status, o.total_amount, o.owed_amount, o.pos_reference, o.resolved_at, o.resolved_by,
             (SELECT COUNT(*) FROM Order_Items WHERE order_id = o.id) AS ic,
             (SELECT COUNT(*) FROM Order_Items WHERE order_id = o.id AND delivery_status = 'DELIVERED') AS dc
      FROM Orders o
  ''';

  /// فهرست سفارش‌ها (جدیدترین اول). limit = null یعنی همه
  Future<List<OrderRow>> orders(
    ReportRange range, {
    OrderFilter filter = OrderFilter.all,
    int? limit,
    int offset = 0,
  }) async {
    final db = await _db();
    final args = <Object?>[];
    final statuses = statusesFor(filter);
    final statusSql = statuses.isEmpty ? '' : ' AND o.pos_status IN (${_marks(statuses.length)})';
    args.addAll(statuses);
    final rangeSql = range.sql('o.timestamp', args);
    final limitSql = limit == null ? '' : ' LIMIT $limit OFFSET $offset';
    final rows = await db.rawQuery(
      '$_orderSelect WHERE 1 = 1$statusSql$rangeSql ORDER BY o.timestamp DESC, o.id DESC$limitSql',
      args,
    );
    return [for (final r in rows) OrderRow.fromMap(r)];
  }

  Future<List<OrderItemRow>> _itemsOf(Database db, String orderId) async {
    final rows = await db.rawQuery(
      '''
      SELECT i.id, i.rack_number, i.physical_address, COALESCE(p.name, 'محصول حذف‌شده') AS name, i.sold_price, i.delivery_status, i.delivered_at
      FROM Order_Items i LEFT JOIN Products_Catalog p ON p.id = i.product_id
      WHERE i.order_id = ? ORDER BY i.id
      ''',
      [orderId],
    );
    return [
      for (final r in rows)
        OrderItemRow(
          id: _int(r['id']),
          rackNumber: _int(r['rack_number']),
          physicalAddress: r['physical_address'] as int?,
          productName: r['name'].toString(),
          price: _int(r['sold_price']),
          status: r['delivery_status'].toString(),
          deliveredAt: _parseTime(r['delivered_at']),
        ),
    ];
  }

  /// لاگ‌هایی که شناسه این سفارش در متنشان آمده است (قدیمی‌ترین اول)
  Future<List<LogEntry>> logsOfOrder(String orderId) async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT id, log_type, error_code, description, timestamp FROM System_Logs WHERE instr(description, ?) > 0 ORDER BY id ASC',
      [orderId],
    );
    // شناسه‌ای که فقط ابتدای شناسه بلندتری باشد (مثلاً ORD-12 داخل ORD-123) پذیرفته نمی‌شود
    final exact = RegExp('${RegExp.escape(orderId)}(?![A-Za-z0-9])');
    return [
      for (final r in rows)
        if (exact.hasMatch((r['description'] ?? '').toString())) LogEntry.fromMap(r),
    ];
  }

  Future<OrderDetail?> orderDetail(String orderId) async {
    final db = await _db();
    final rows = await db.rawQuery('$_orderSelect WHERE o.id = ?', [orderId]);
    if (rows.isEmpty) return null;
    final items = await _itemsOf(db, orderId);
    final logs = await logsOfOrder(orderId);
    return OrderDetail(OrderRow.fromMap(rows.first), items, logs);
  }

  // ---------------- موارد نیازمند پیگیری اپراتور ----------------

  /// نتیجه‌هایی که اپراتور برای یک وضعیت مجاز است (و مبنای دکمه‌های صفحه مطالبات).
  /// undeliveredCount = تعداد کالاهای هنوز تحویل‌نشده سفارش؛ «بخشی تحویل شده بود» فقط وقتی معنا دارد که بیش از یکی باشد.
  static List<ResolveOutcome> allowedOutcomes(String status, {required bool hasDeliveredItem, int undeliveredCount = 1}) {
    final bool canSplit = undeliveredCount >= 2;
    switch (status) {
      case OrderStatus.settlementDue:
        return [
          ResolveOutcome.settled,
          ResolveOutcome.delivered,
          if (canSplit) ResolveOutcome.partial,
        ];
      case OrderStatus.needsReview:
        return [
          ResolveOutcome.delivered,
          if (canSplit) ResolveOutcome.partial,
          ResolveOutcome.paidNotDelivered,
          if (!hasDeliveredItem) ResolveOutcome.notPaid, // کالایی که تحویل شده بدون پرداخت نمی‌تواند باشد
        ];
      case OrderStatus.paymentTimeout:
      case OrderStatus.posError:
        return const [ResolveOutcome.paidNotDelivered, ResolveOutcome.notPaid];
      default:
        return const [];
    }
  }

  static String _groupSql(AttentionGroup group) {
    switch (group) {
      case AttentionGroup.all:
        return '';
      case AttentionGroup.settlement:
        return " AND o.pos_status = '${OrderStatus.settlementDue}'";
      case AttentionGroup.review:
        return " AND o.pos_status <> '${OrderStatus.settlementDue}'";
    }
  }

  /// موارد باز (resolved = false: مطالبه مشتری‌ها اول، بعد سفارش‌های نامعلوم، هر دو جدیدترین اول)
  /// یا بسته‌شده (resolved = true: هر وضعیتی که اپراتور بسته است، آخرین بسته‌شده اول)؛ همراه با کالاهایشان
  Future<List<OrderDetail>> attentionOrders({
    bool resolved = false,
    AttentionGroup group = AttentionGroup.all,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db();
    final String where;
    final String orderBy;
    final List<Object?> args;
    if (resolved) {
      where = 'o.resolved_at IS NOT NULL';
      orderBy = 'o.resolved_at DESC, o.id DESC';
      args = const [];
    } else {
      where = 'o.pos_status IN (${_marks(attentionStatuses.length)}) AND o.resolved_at IS NULL${_groupSql(group)}';
      orderBy = "CASE WHEN o.pos_status = '${OrderStatus.settlementDue}' THEN 0 ELSE 1 END, o.timestamp DESC, o.id DESC";
      args = attentionStatuses;
    }
    final rows = await db.rawQuery('$_orderSelect WHERE $where ORDER BY $orderBy LIMIT $limit OFFSET $offset', args);
    final result = <OrderDetail>[];
    for (final r in rows) {
      final order = OrderRow.fromMap(r);
      result.add(OrderDetail(order, await _itemsOf(db, order.id), const []));
    }
    return result;
  }

  /// جست‌وجوی سفارش با «چند رقم آخر» کد پیگیری، در همه وضعیت‌ها و بازه‌ها؛ جدیدترین اول.
  /// فقط انتهای کد تطبیق داده می‌شود (نه هر جای آن) تا نتیجه‌ها کم و دقیق باشند.
  Future<List<OrderDetail>> searchOrdersByCode(String fragment, {int limit = 30}) async {
    final text = fragment.trim();
    if (text.isEmpty) return const [];
    final db = await _db();
    final rows = await db.rawQuery(
      '$_orderSelect WHERE length(o.id) >= length(?) AND substr(o.id, -length(?)) = ? ORDER BY o.timestamp DESC, o.id DESC LIMIT $limit',
      [text, text, text],
    );
    final result = <OrderDetail>[];
    for (final r in rows) {
      final order = OrderRow.fromMap(r);
      result.add(OrderDetail(order, await _itemsOf(db, order.id), const []));
    }
    return result;
  }

  /// شمارنده‌ها و جمع مطالبه‌های باز (مستقل از محدودیت فهرست)
  Future<AttentionStats> attentionStats() async {
    final db = await _db();
    final open = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(CASE WHEN pos_status = ? THEN 1 ELSE 0 END), 0) AS s,
             COALESCE(SUM(CASE WHEN pos_status <> ? THEN 1 ELSE 0 END), 0) AS r,
             COALESCE(SUM(CASE WHEN pos_status = ? THEN owed_amount ELSE 0 END), 0) AS o
      FROM Orders WHERE pos_status IN (${_marks(attentionStatuses.length)}) AND resolved_at IS NULL
      ''',
      [OrderStatus.settlementDue, OrderStatus.settlementDue, OrderStatus.settlementDue, ...attentionStatuses],
    );
    final closed = await db.rawQuery('SELECT COUNT(*) AS c FROM Orders WHERE resolved_at IS NOT NULL');
    return AttentionStats(
      openSettlement: _int(open.first['s']),
      openReview: _int(open.first['r']),
      openOwedTotal: _int(open.first['o']),
      closed: _int(closed.first['c']),
    );
  }

  /// تعداد موارد بازی که اپراتور باید پیگیری کند (برای نشان روی کارت داشبورد)
  Future<int> openAttentionCount() async {
    final db = await _db();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM Orders WHERE pos_status IN (${_marks(attentionStatuses.length)}) AND resolved_at IS NULL',
      attentionStatuses,
    );
    return _int(rows.first['c']);
  }

  /// بستن یک مورد با ثبت نتیجه واقعی؛ وضعیت سفارش، مبلغ مطالبه، کالاها و موجودی رک هم متناسب با آن اصلاح می‌شود.
  /// برای [ResolveOutcome.partial]، [deliveredItemIds] شناسه ردیف‌های تحویل‌شده است (بقیه ردیف‌های تحویل‌نشده می‌مانند).
  /// false = مورد باز نبود، این نتیجه برای آن مجاز نبود یا ورودی نامعتبر بود؛ در این صورت هیچ تغییری ثبت نمی‌شود.
  Future<bool> resolveOrder(
    String orderId, {
    required String by,
    required ResolveOutcome outcome,
    Set<int> deliveredItemIds = const {},
  }) async {
    final db = await _db();
    final String now = DateTime.now().toIso8601String();
    String? logType;
    String? logCode;
    String? logText;

    final bool applied = await db.transaction<bool>((txn) async {
      final found = await txn.rawQuery(
        'SELECT pos_status, total_amount, owed_amount, resolved_at FROM Orders WHERE id = ?',
        [orderId],
      );
      if (found.isEmpty || found.first['resolved_at'] != null) return false;

      final String status = found.first['pos_status'].toString();
      final int owedBefore = _int(found.first['owed_amount']);
      final items = await txn.rawQuery(
        'SELECT id, rack_number, physical_address, product_id, sold_price, delivery_status FROM Order_Items WHERE order_id = ? ORDER BY id',
        [orderId],
      );
      final pending = [
        for (final i in items)
          if (i['delivery_status'] != ItemStatus.delivered) i,
      ];
      final bool hasDelivered = pending.length < items.length;
      if (!allowedOutcomes(status, hasDeliveredItem: hasDelivered, undeliveredCount: pending.length).contains(outcome)) {
        return false;
      }

      // موجودی هر کالای تحویل‌شده از رکی کم می‌شود که «آدرس فیزیکی» و «محصول» آن با کالای سفارش می‌خواند؛
      // شماره رک با تغییر چیدمان عوض می‌شود، پس فقط برای ردیف‌های قدیمی بدون آدرس فیزیکی به آن تکیه می‌شود.
      // اگر چنین رکی دیگر نباشد، موجودی دست نمی‌خورد و در لاگ برای بررسی دستی نوشته می‌شود.
      final unadjusted = <int>{};
      Future<void> markDelivered(Map<String, Object?> item) async {
        await txn.rawUpdate(
          'UPDATE Order_Items SET delivery_status = ?, delivered_at = ? WHERE id = ?',
          [ItemStatus.delivered, now, item['id']],
        );
        final Object? address = item['physical_address'];
        final int changed = address != null
            ? await txn.rawUpdate(
                'UPDATE Racks_Inventory SET stock = MAX(stock - 1, 0) WHERE physical_address = ? AND product_id = ?',
                [address, item['product_id']],
              )
            : await txn.rawUpdate(
                'UPDATE Racks_Inventory SET stock = MAX(stock - 1, 0) WHERE rack_number = ? AND product_id = ?',
                [item['rack_number'], item['product_id']],
              );
        if (changed == 0) unadjusted.add(_int(item['rack_number']));
      }

      String stockNote() => unadjusted.isEmpty
          ? ''
          : '؛ موجودی رک ${unadjusted.join('، ')} خودکار تنظیم نشد (چیدمان یا محصول رک عوض شده) و باید دستی بررسی شود';

      ResolveOutcome effective = outcome;
      List<Map<String, Object?>> chosen = const [];
      if (outcome == ResolveOutcome.partial) {
        chosen = [
          for (final i in pending)
            if (deliveredItemIds.contains(_int(i['id']))) i,
        ];
        if (chosen.isEmpty) return false;
        if (chosen.length == pending.length) effective = ResolveOutcome.delivered; // همه تحویل شده‌اند
      }

      switch (effective) {
        case ResolveOutcome.settled:
          // اپراتور مبلغ را تسویه کرده یعنی کالای نتیجه‌نشده تحویل نشده بوده
          await txn.rawUpdate(
            'UPDATE Order_Items SET delivery_status = ? WHERE order_id = ? AND delivery_status <> ?',
            [ItemStatus.failed, orderId, ItemStatus.delivered],
          );
          await txn.rawUpdate('UPDATE Orders SET resolved_at = ?, resolved_by = ? WHERE id = ?', [now, by, orderId]);
          logType = 'OP';
          logCode = 'ORDER_RESOLVED';
          logText = 'سفارش $orderId: تسویه مبلغ $owedBefore ریال با مشتری توسط «$by» ثبت شد';
          break;

        case ResolveOutcome.delivered:
          for (final i in pending) {
            await markDelivered(i);
          }
          await txn.rawUpdate(
            'UPDATE Orders SET pos_status = ?, owed_amount = 0, resolved_at = ?, resolved_by = ? WHERE id = ?',
            [OrderStatus.paid, now, by, orderId],
          );
          logType = 'OP';
          logCode = 'ORDER_RESOLVED';
          logText =
              'سفارش $orderId (${ReportLabels.order(status)}): «$by» تأیید کرد کالا تحویل شده بود؛ ${pending.length} کالا تحویل‌شده ثبت و از موجودی رک‌ها کم شد${stockNote()}';
          break;

        case ResolveOutcome.partial:
          final chosenIds = {for (final i in chosen) _int(i['id'])};
          int remaining = 0;
          for (final i in pending) {
            if (chosenIds.contains(_int(i['id']))) {
              await markDelivered(i);
            } else {
              remaining += _int(i['sold_price']);
              await txn.rawUpdate('UPDATE Order_Items SET delivery_status = ? WHERE id = ?', [ItemStatus.failed, i['id']]);
            }
          }
          await txn.rawUpdate(
            'UPDATE Orders SET pos_status = ?, owed_amount = ? WHERE id = ?',
            [OrderStatus.settlementDue, remaining, orderId],
          );
          logType = 'HARD';
          logCode = 'SETTLEMENT_DUE';
          logText =
              'سفارش $orderId (${ReportLabels.order(status)}): «$by» تأیید کرد ${chosen.length} از ${pending.length} کالای نتیجه‌نشده تحویل شده بود؛ مبلغ $remaining ریال بابت بقیه باید با مشتری تسویه شود${stockNote()}';
          break;

        case ResolveOutcome.paidNotDelivered:
          final int sum = pending.fold<int>(0, (s, i) => s + _int(i['sold_price']));
          await txn.rawUpdate(
            'UPDATE Order_Items SET delivery_status = ? WHERE order_id = ? AND delivery_status <> ?',
            [ItemStatus.failed, orderId, ItemStatus.delivered],
          );
          await txn.rawUpdate(
            'UPDATE Orders SET pos_status = ?, owed_amount = ? WHERE id = ?',
            [OrderStatus.settlementDue, sum, orderId],
          );
          logType = 'HARD';
          logCode = 'SETTLEMENT_DUE';
          logText =
              'سفارش $orderId (${ReportLabels.order(status)}): «$by» تأیید کرد پرداخت انجام شده ولی کالا تحویل نشده؛ مبلغ $sum ریال بابت کالای تحویل‌نشده باید با مشتری تسویه شود';
          break;

        case ResolveOutcome.notPaid:
          await txn.rawUpdate(
            'UPDATE Order_Items SET delivery_status = ? WHERE order_id = ? AND delivery_status <> ?',
            [ItemStatus.cancelled, orderId, ItemStatus.delivered],
          );
          await txn.rawUpdate(
            'UPDATE Orders SET pos_status = ?, owed_amount = 0, resolved_at = ?, resolved_by = ? WHERE id = ?',
            [OrderStatus.cancelled, now, by, orderId],
          );
          logType = 'OP';
          logCode = 'ORDER_RESOLVED';
          logText = 'سفارش $orderId (${ReportLabels.order(status)}): «$by» تأیید کرد پرداخت انجام نشده بود؛ سفارش لغو شد';
          break;
      }
      return true;
    });

    if (applied) await _orders.log(logType!, logCode!, logText!);
    return applied;
  }

  // ---------------- لاگ‌ها ----------------

  String _logWhere(LogCategory category, ReportRange range, List<Object?> args, {String? type, String? code}) {
    final buffer = StringBuffer(' WHERE 1 = 1');
    if (category == LogCategory.board) buffer.write(' AND $_boardCodeSql');
    if (category == LogCategory.panel) buffer.write(' AND NOT $_boardCodeSql');
    if (type != null) {
      buffer.write(' AND log_type = ?');
      args.add(type);
    }
    if (code != null) {
      buffer.write(' AND error_code = ?');
      args.add(code);
    }
    buffer.write(range.sql('timestamp', args));
    return buffer.toString();
  }

  /// فهرست لاگ‌ها (جدیدترین اول). limit = null یعنی همه
  Future<List<LogEntry>> logs({
    LogCategory category = LogCategory.all,
    required ReportRange range,
    String? type,
    String? code,
    int? limit,
    int offset = 0,
  }) async {
    final db = await _db();
    final args = <Object?>[];
    final where = _logWhere(category, range, args, type: type, code: code);
    final limitSql = limit == null ? '' : ' LIMIT $limit OFFSET $offset';
    final rows = await db.rawQuery(
      'SELECT id, log_type, error_code, description, timestamp FROM System_Logs$where ORDER BY timestamp DESC, id DESC$limitSql',
      args,
    );
    return [for (final r in rows) LogEntry.fromMap(r)];
  }

  /// تعداد لاگ‌ها به تفکیک نوع (بدون اعمال فیلتر نوع)
  Future<Map<String, int>> logCountsByType({LogCategory category = LogCategory.all, required ReportRange range, String? code}) async {
    final db = await _db();
    final args = <Object?>[];
    final where = _logWhere(category, range, args, code: code);
    final rows = await db.rawQuery('SELECT log_type AS t, COUNT(*) AS c FROM System_Logs$where GROUP BY log_type', args);
    return {for (final r in rows) r['t'].toString(): _int(r['c'])};
  }

  /// کدهای موجود در لاگ‌ها (پرتکرارترین اول) برای فیلتر
  Future<List<String>> logCodes({LogCategory category = LogCategory.all, required ReportRange range, String? type}) async {
    final db = await _db();
    final args = <Object?>[];
    final where = _logWhere(category, range, args, type: type);
    final rows = await db.rawQuery(
      'SELECT error_code AS c, COUNT(*) AS n FROM System_Logs$where GROUP BY error_code ORDER BY n DESC, c ASC',
      args,
    );
    return [for (final r in rows) r['c'].toString()];
  }

  /// تعداد لاگ‌هایی که پاک‌سازی حذف می‌کند (برای نمایش در پنجره تأیید)
  Future<int> oldLogsCount({int days = 90, DateTime? now}) async {
    final db = await _db();
    final base = now ?? DateTime.now();
    final cutoff = DateTime(base.year, base.month, base.day - days);
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM System_Logs WHERE log_type IN ('OP', 'SOFT') AND timestamp < ?",
      [cutoff.toIso8601String()],
    );
    return _int(rows.first['c']);
  }

  /// حذف لاگ‌های عملیاتی و هشدار قدیمی‌تر از [days] روز؛ لاگ‌های «خطای جدی» همیشه می‌مانند.
  /// تعداد ردیف‌های حذف‌شده را برمی‌گرداند.
  Future<int> purgeOldLogs({int days = 90, DateTime? now}) async {
    final db = await _db();
    final base = now ?? DateTime.now();
    final cutoff = DateTime(base.year, base.month, base.day - days);
    return db.rawDelete(
      "DELETE FROM System_Logs WHERE log_type IN ('OP', 'SOFT') AND timestamp < ?",
      [cutoff.toIso8601String()],
    );
  }
}