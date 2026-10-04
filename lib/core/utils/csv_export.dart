// مسیر: lib/core/utils/csv_export.dart
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/report_repository.dart';
import 'jalali.dart';

/// ساخت متن CSV؛ با BOM ابتدای فایل تا اکسل فارسی را درست نشان بدهد
class CsvBuilder {
  static const String bom = '\uFEFF';

  /// سلول متنی: نقل‌قول‌گذاری + جلوگیری از اجرای فرمول در اکسل (متنی که با = + - @ شروع شود)
  static String _text(String value) {
    var v = value;
    if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) v = "'$v";
    if (v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r')) {
      v = '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static String _cell(Object? value) {
    if (value == null) return '';
    if (value is int || value is double) return value.toString();
    return _text(value.toString());
  }

  static String build(List<String> headers, List<List<Object?>> rows) {
    final buffer = StringBuffer(bom);
    buffer.write('${headers.map(_text).join(',')}\r\n');
    for (final row in rows) {
      buffer.write('${row.map(_cell).join(',')}\r\n');
    }
    return buffer.toString();
  }
}

/// فایل CSV گزارش‌ها
class ReportCsv {
  static String orders(List<OrderRow> orders) {
    return CsvBuilder.build(
      ['کد پیگیری', 'تاریخ شمسی', 'ساعت', 'وضعیت', 'مبلغ کل (ریال)', 'مبلغ مطالبه مشتری (ریال)', 'فروش خالص (ریال)', 'تعداد کالا', 'کالای تحویل‌شده', 'کد مرجع پوز', 'بسته‌شده توسط', 'زمان میلادی'],
      [
        for (final o in orders)
          [
            o.id,
            o.time == null ? '' : Jalali.formatDate(o.time!),
            o.time == null ? '' : Jalali.formatTimeWithSeconds(o.time!),
            ReportLabels.order(o.status),
            o.total,
            o.owed,
            o.net,
            o.itemCount,
            o.deliveredCount,
            o.reference ?? '',
            o.resolved ? (o.resolvedBy ?? '') : '',
            o.rawTime,
          ],
      ],
    );
  }

  static String logs(List<LogEntry> logs) {
    return CsvBuilder.build(
      ['شناسه', 'تاریخ شمسی', 'ساعت', 'نوع', 'کد', 'عنوان', 'توضیح', 'زمان میلادی'],
      [
        for (final l in logs)
          [
            l.id,
            l.time == null ? '' : Jalali.formatDate(l.time!),
            l.time == null ? '' : Jalali.formatTimeWithSeconds(l.time!),
            ReportLabels.type(l.type),
            l.code,
            ReportLabels.code(l.code),
            l.description,
            l.rawTime,
          ],
      ],
    );
  }
}

/// ذخیره فایل گزارش در پوشه دانلودها (در صورت نبودن، پوشه اسناد برنامه)
class CsvExporter {
  /// برای تست قابل جایگزینی است
  static Future<Directory> Function() directoryResolver = _defaultDirectory;

  static Future<Directory> _defaultDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;
    } catch (_) {
      // روی بعضی سکوها پوشه دانلود وجود ندارد
    }
    return getApplicationDocumentsDirectory();
  }

  /// فایل را می‌نویسد و آدرس آن را برمی‌گرداند. نام فایل: `<name>_<تاریخ شمسی>_<ساعت و دقیقه و ثانیه>.csv`
  static Future<String> save(String name, String csv, {DateTime? now}) async {
    final dir = await directoryResolver();
    if (!await dir.exists()) await dir.create(recursive: true);

    final t = now ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${Jalali.formatDate(t).replaceAll('/', '-')}_${two(t.hour)}${two(t.minute)}${two(t.second)}';
    final file = File(p.join(dir.path, '${name}_$stamp.csv'));
    await file.writeAsString(csv, flush: true);
    return file.path;
  }
}