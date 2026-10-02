import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'database_helper.dart';

class _DefaultAddon {
  final String name;
  final String iconKey;
  final String cmd;
  const _DefaultAddon(this.name, this.iconKey, this.cmd);
}

/// افزودنی‌ها = رک‌های عملیاتی غیرکالایی (مثل آبجوش، سس) که به «رک» نسبت داده می‌شوند.
/// جدول Machine_Addons: تعریف افزودنی‌ها | جدول Rack_Addons_Mapper: نسبت افزودنی به رک
class AddonRepository {
  static bool _schemaReady = false;

  static const List<_DefaultAddon> _defaultAddons = [
    _DefaultAddon('آبجوش', 'local_fire_department', '1'),
    _DefaultAddon('سس', 'water_drop', '2'),
  ];

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// ستون icon_key را (فقط یک‌بار) به جدول Machine_Addons اضافه می‌کند و افزودنی‌های پیش‌فرض را می‌سازد.
  /// دیتای موجود دست نمی‌خورد.
  Future<void> ensureSchema() async {
    if (_schemaReady) return;
    final db = await _dbHelper.database;

    final cols = await db.rawQuery('PRAGMA table_info(Machine_Addons)');
    final bool hasIcon = cols.any((c) => c['name'] == 'icon_key');
    if (!hasIcon) {
      await db.execute("ALTER TABLE Machine_Addons ADD COLUMN icon_key TEXT NOT NULL DEFAULT 'add_circle_outline'");
      final countRows = await db.rawQuery('SELECT COUNT(*) AS c FROM Machine_Addons');
      if ((countRows.first['c'] as int) == 0) {
        await seedDefaults(db);
      }
    }
    _schemaReady = true;
  }

  /// درج افزودنی‌های پیش‌فرض (آبجوش، سس)
  static Future<void> seedDefaults(DatabaseExecutor ex) async {
    for (final a in _defaultAddons) {
      await ex.rawInsert(
        "INSERT INTO Machine_Addons (name, value_type, hardware_cmd, icon_key) VALUES (?, 'count', ?, ?)",
        [a.name, a.cmd, a.iconKey],
      );
    }
  }

  // ---------------- تعریف افزودنی‌ها ----------------

  Future<List<Map<String, dynamic>>> fetchAddons() async {
    await ensureSchema();
    final db = await _dbHelper.database;
    return await db.rawQuery('SELECT * FROM Machine_Addons ORDER BY id ASC');
  }

  /// cmd = کد دستور برد؛ اگر خالی باشد، شناسه افزودنی به‌عنوان کد قرار می‌گیرد
  Future<int> addAddon({required String name, required String iconKey, required String cmd}) async {
    await ensureSchema();
    final db = await _dbHelper.database;
    final id = await db.rawInsert(
      "INSERT INTO Machine_Addons (name, value_type, hardware_cmd, icon_key) VALUES (?, 'count', ?, ?)",
      [name, cmd, iconKey],
    );
    if (cmd.isEmpty) {
      await db.rawUpdate('UPDATE Machine_Addons SET hardware_cmd = ? WHERE id = ?', [id.toString(), id]);
    }
    return id;
  }

  Future<void> updateAddon({
    required int id,
    required String name,
    required String iconKey,
    required String cmd,
  }) async {
    await ensureSchema();
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE Machine_Addons SET name = ?, icon_key = ?, hardware_cmd = ? WHERE id = ?',
      [name, iconKey, cmd.isEmpty ? id.toString() : cmd, id],
    );
  }

  /// حذف افزودنی؛ نسبت‌های آن به رک‌ها هم حذف می‌شود
  Future<void> deleteAddon(int id) async {
    await ensureSchema();
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM Rack_Addons_Mapper WHERE addon_id = ?', [id]);
      await txn.rawDelete('DELETE FROM Machine_Addons WHERE id = ?', [id]);
    });
  }

  /// تعداد رک‌هایی که از هر افزودنی استفاده می‌کنند: addon_id ← تعداد رک
  Future<Map<int, int>> fetchAddonUsage() async {
    await ensureSchema();
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT addon_id, COUNT(DISTINCT rack_number) AS c FROM Rack_Addons_Mapper GROUP BY addon_id',
    );
    return {for (final r in rows) r['addon_id'] as int: r['c'] as int};
  }

  // ---------------- نسبت افزودنی به رک ----------------

  /// افزودنی‌های یک رک: addon_id, qty, name, icon_key, hardware_cmd
  Future<List<Map<String, dynamic>>> fetchRackAddons(int rackNumber) async {
    await ensureSchema();
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT m.addon_id AS addon_id, m.addon_value AS qty,
             a.name AS name, a.icon_key AS icon_key, a.hardware_cmd AS hardware_cmd
      FROM Rack_Addons_Mapper m
      JOIN Machine_Addons a ON a.id = m.addon_id
      WHERE m.rack_number = ?
      ORDER BY m.id ASC
    ''', [rackNumber]);
  }

  /// افزودنی‌های همه رک‌ها: rack_number ← لیست افزودنی‌ها
  Future<Map<int, List<Map<String, dynamic>>>> fetchAllRackAddons() async {
    await ensureSchema();
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT m.rack_number AS rack_number, m.addon_id AS addon_id, m.addon_value AS qty,
             a.name AS name, a.icon_key AS icon_key, a.hardware_cmd AS hardware_cmd
      FROM Rack_Addons_Mapper m
      JOIN Machine_Addons a ON a.id = m.addon_id
      ORDER BY m.rack_number ASC, m.id ASC
    ''');
    final Map<int, List<Map<String, dynamic>>> result = {};
    for (final r in rows) {
      result.putIfAbsent(r['rack_number'] as int, () => <Map<String, dynamic>>[]).add(r);
    }
    return result;
  }

  /// جایگزینی کامل افزودنی‌های یک رک؛ qtyByAddon: addon_id ← تعداد به‌ازای هر کالا
  Future<void> setRackAddons(int rackNumber, Map<int, int> qtyByAddon) async {
    await ensureSchema();
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.rawDelete('DELETE FROM Rack_Addons_Mapper WHERE rack_number = ?', [rackNumber]);
      for (final entry in qtyByAddon.entries) {
        await txn.rawInsert(
          'INSERT INTO Rack_Addons_Mapper (rack_number, addon_id, addon_value) VALUES (?, ?, ?)',
          [rackNumber, entry.key, entry.value < 1 ? 1 : entry.value],
        );
      }
    });
  }
}