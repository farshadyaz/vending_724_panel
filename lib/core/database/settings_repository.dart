import 'database_helper.dart';

/// تنظیمات ساده کلید-مقدار دستگاه (حالت پنل مشتری، رمز اولیه تکنسین، ظرفیت سبد خرید،
/// سقف افزودنی هر رک، تنظیمات شبکه برد و پوز)
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

  // ارتباط با برد و پوز
  static const String hardwareModeNetwork = 'network'; // برد/پوز واقعی یا شبیه‌ساز روی شبکه
  static const String hardwareModeMock = 'mock'; // شبیه‌ساز داخلی بدون شبکه
  static const String defaultBoardIp = '127.0.0.1';
  static const int defaultBoardPort = 8080;
  static const String defaultPosIp = '127.0.0.1';
  static const int defaultPosPort = 8090;

  static const String _kPanelMode = 'panel_mode';
  static const String _kAdminPin = 'admin_pin';
  static const String _kCartCapacity = 'cart_capacity';
  static const String _kMaxAddonsPerRack = 'max_addons_per_rack';
  static const String _kHardwareMode = 'hardware_mode';
  static const String _kBoardIp = 'board_ip';
  static const String _kBoardPort = 'board_port';
  static const String _kPosIp = 'pos_ip';
  static const String _kPosPort = 'pos_port';

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

  // ---------------- اعتبارسنجی ----------------

  /// آدرس IPv4 معتبر مثل 192.168.1.20
  static bool isValidIpv4(String value) {
    final parts = value.trim().split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      if (p.isEmpty || p.length > 3) return false;
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
  }

  static bool isValidPort(int port) => port >= 1 && port <= 65535;

  // ---------------- حالت پنل و رمز ----------------

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

  // ---------------- سبد و افزودنی ----------------

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

  // ---------------- شبکه: برد و پوز ----------------

  Future<String> getHardwareMode() async {
    final v = await _get(_kHardwareMode);
    return v == hardwareModeMock ? hardwareModeMock : hardwareModeNetwork;
  }

  Future<void> setHardwareMode(String mode) async {
    await _set(_kHardwareMode, mode == hardwareModeMock ? hardwareModeMock : hardwareModeNetwork);
  }

  Future<String> getBoardIp() async {
    final v = await _get(_kBoardIp);
    return (v != null && isValidIpv4(v)) ? v : defaultBoardIp;
  }

  Future<int> getBoardPort() async {
    final v = int.tryParse(await _get(_kBoardPort) ?? '');
    return (v != null && isValidPort(v)) ? v : defaultBoardPort;
  }

  Future<String> getPosIp() async {
    final v = await _get(_kPosIp);
    return (v != null && isValidIpv4(v)) ? v : defaultPosIp;
  }

  Future<int> getPosPort() async {
    final v = int.tryParse(await _get(_kPosPort) ?? '');
    return (v != null && isValidPort(v)) ? v : defaultPosPort;
  }

  /// ذخیره همه تنظیمات شبکه؛ اگر مقداری نامعتبر باشد ArgumentError می‌دهد
  Future<void> setNetwork({
    required String boardIp,
    required int boardPort,
    required String posIp,
    required int posPort,
  }) async {
    if (!isValidIpv4(boardIp) || !isValidIpv4(posIp)) throw ArgumentError('آدرس IP نامعتبر است');
    if (!isValidPort(boardPort) || !isValidPort(posPort)) throw ArgumentError('پورت نامعتبر است');
    await _set(_kBoardIp, boardIp.trim());
    await _set(_kBoardPort, boardPort.toString());
    await _set(_kPosIp, posIp.trim());
    await _set(_kPosPort, posPort.toString());
  }
}