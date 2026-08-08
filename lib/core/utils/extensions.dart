// مسیر: lib/core/utils/extensions.dart
extension CurrencyFormatter on int {
  String get toRial {
    // درج جداکننده هزارگان برای اعداد
    final formatted = toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    // در سیستم RTL، این فرمت دقیقاً کلمه ریال را بعد از عدد (سمت چپ آن) نشان می‌دهد
    return '$formatted ریال';
  }
}