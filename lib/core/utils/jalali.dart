// مسیر: lib/core/utils/jalali.dart
// تبدیل تاریخ میلادی ↔ شمسی (الگوریتم حسابی ۳۳ ساله) و قالب‌بندی تاریخ و ساعت برای گزارش‌ها.
// رقم‌ها لاتین نوشته می‌شوند؛ فونت وزیر نسخه FD آن‌ها را فارسی نشان می‌دهد.

class Jalali {
  final int year;
  final int month;
  final int day;

  const Jalali(this.year, this.month, this.day);

  static const List<String> monthNames = [
    'فروردین',
    'اردیبهشت',
    'خرداد',
    'تیر',
    'مرداد',
    'شهریور',
    'مهر',
    'آبان',
    'آذر',
    'دی',
    'بهمن',
    'اسفند',
  ];

  // هفته از شنبه شروع می‌شود
  static const List<String> weekdayNames = [
    'شنبه',
    'یکشنبه',
    'دوشنبه',
    'سه‌شنبه',
    'چهارشنبه',
    'پنجشنبه',
    'جمعه',
  ];

  static const List<int> _gregorianDaysBeforeMonth = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];

  static Jalali fromGregorian(int gy, int gm, int gd) {
    final int gy2 = gm > 2 ? gy + 1 : gy;
    int days = 355666 +
        (365 * gy) +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) +
        gd +
        _gregorianDaysBeforeMonth[gm - 1];
    int jy = -1595 + (33 * (days ~/ 12053));
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    final int jm;
    final int jd;
    if (days < 186) {
      jm = 1 + (days ~/ 31);
      jd = 1 + (days % 31);
    } else {
      jm = 7 + ((days - 186) ~/ 30);
      jd = 1 + ((days - 186) % 30);
    }
    return Jalali(jy, jm, jd);
  }

  static Jalali fromDateTime(DateTime d) => fromGregorian(d.year, d.month, d.day);

  /// نیمه‌شب (محلی) همین روز شمسی
  DateTime toDateTime() {
    final int jy2 = year + 1595;
    int days = -355668 +
        (365 * jy2) +
        ((jy2 ~/ 33) * 8) +
        (((jy2 % 33) + 3) ~/ 4) +
        day +
        (month < 7 ? (month - 1) * 31 : ((month - 7) * 30) + 186);
    int gy = 400 * (days ~/ 146097);
    days %= 146097;
    if (days > 36524) {
      days -= 1;
      gy += 100 * (days ~/ 36524);
      days %= 36524;
      if (days >= 365) days += 1;
    }
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      gy += (days - 1) ~/ 365;
      days = (days - 1) % 365;
    }
    int gd = days + 1;
    final bool leap = (gy % 4 == 0 && gy % 100 != 0) || gy % 400 == 0;
    final List<int> monthLengths = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    int gm = 0;
    while (gm < 12 && gd > monthLengths[gm]) {
      gd -= monthLengths[gm];
      gm++;
    }
    return DateTime(gy, gm + 1, gd);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// مثل 1405/07/11
  String get dateText => '$year/${_two(month)}/${_two(day)}';

  /// مثل «11 مهر 1405»
  String get longText => '$day ${monthNames[month - 1]} $year';

  // ---------------- قالب‌بندی ----------------

  static String formatDate(DateTime d) => fromDateTime(d).dateText;

  static String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

  static String formatTimeWithSeconds(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';

  static String formatDateTime(DateTime d) => '${formatDate(d)}  ${formatTime(d)}';

  /// نام روز هفته (شنبه … جمعه)
  static String weekdayName(DateTime d) => weekdayNames[(d.weekday + 1) % 7];

  /// رشته زمان ذخیره‌شده در دیتابیس (ISO) را به متن شمسی تبدیل می‌کند؛ اگر نامعتبر بود «—»
  static String formatIso(String? iso, {bool seconds = false}) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '—';
    return '${formatDate(d)}  ${seconds ? formatTimeWithSeconds(d) : formatTime(d)}';
  }

  @override
  bool operator ==(Object other) => other is Jalali && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => dateText;
}