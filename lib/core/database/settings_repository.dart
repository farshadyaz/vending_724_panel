import 'database_helper.dart';

/// تنظیمات ساده کلید-مقدار دستگاه (حالت پنل مشتری، رمز اولیه تکنسین، ظرفیت سبد خرید، سقف افزودنی هر رک)
class SettingsRepository {
  static const String panelModeKeypad = 'keypad'; // کیپد + کارت محصول
  static const String panelModeLayout = 'layout'; // لیست چیدمان رک‌ها
  static const String defaultAdminPin = '4848';

  static const int defaultCartCapacity = 5;
  static const int minCartCapacity = 1;
  static const int maxCartCapacity = 10;

  // حداکثر تعداد افزودنی برای هر رک (۰ = قابلیت افزودنی برای رک‌ها غیرفعال)
  static const int defaultMaxAddonsPerRack = 2;
  static const int minAddonsPerRackLimit = 0;
  static const int maxAddonsPerRackLimit = 6;

  static const String _kPanelMode = 'panel_mode';
  static const String _kAdminPin = 'admin_pin';
  static const String _kCartCapacity = 'cart_capacity';
  static const String _kMaxAddonsPerRack = 'max_addons_per_rack';

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String?> _get(String key) async {
    final db = await _dbHelper.database;
    await db.execute(
      'CREATE TABLE IF NOT EXISTS App_Settings (setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)',
    );
    final rows = await db.rawQuery(
      'SELECT setting_value FROM App_Settings WHERE setting_key = ?',
      [key],
    );
    if (rows.isEmpty) return null;
    return rows.first['setting_value'] as String;
  }

  Future<void> _set(String key, String value) async {
    final db = await _dbHelper.database;
    await db.execute(
      'CREATE TABLE IF NOT EXISTS App_Settings (setting_key TEXT PRIMARY KEY, setting_value TEXT NOT NULL)',
    );
    await db.rawInsert(
      'INSERT OR REPLACE INTO App_Settings (setting_key, setting_value) VALUES (?, ?)',
      [key, value],
    );
  }

  Future<String> getPanelMode() async {
    final v = await _get(_kPanelMode);
    return v == panelModeLayout ? panelModeLayout : panelModeKeypad;
  }

  Future<void> setPanelMode(String mode) async {
    await _set(_kPanelMode, mode == panelModeLayout ? panelModeLayout : panelModeKeypad);
  }

  Future<String> getAdminPin() async {
    final v = await _get(_kAdminPin);
    if (v == null || v.length != 4 || int.tryParse(v) == null) return defaultAdminPin;
    return v;
  }

  Future<void> setAdminPin(String pin) async {
    if (pin.length != 4 || int.tryParse(pin) == null) {
      throw ArgumentError('رمز باید ۴ رقم عددی باشد');
    }
    await _set(_kAdminPin, pin);
  }

  /// حداکثر تعداد کالا در هر خرید (ظرفیت سبد)؛ همیشه بین min و max برمی‌گردد
  Future<int> getCartCapacity() async {
    final v = int.tryParse(await _get(_kCartCapacity) ?? '');
    if (v == null || v < minCartCapacity || v > maxCartCapacity) return defaultCartCapacity;
    return v;
  }

  Future<void> setCartCapacity(int value) async {
    final int safe = value.clamp(minCartCapacity, maxCartCapacity).toInt();
    await _set(_kCartCapacity, safe.toString());
  }

  /// حداکثر تعداد افزودنی که هر رک می‌تواند داشته باشد
  Future<int> getMaxAddonsPerRack() async {
    final v = int.tryParse(await _get(_kMaxAddonsPerRack) ?? '');
    if (v == null || v < minAddonsPerRackLimit || v > maxAddonsPerRackLimit) return defaultMaxAddonsPerRack;
    return v;
  }

  Future<void> setMaxAddonsPerRack(int value) async {
    final int safe = value.clamp(minAddonsPerRackLimit, maxAddonsPerRackLimit).toInt();
    await _set(_kMaxAddonsPerRack, safe.toString());
  }
}