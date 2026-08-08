import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('vending_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createDB,
      ),
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE Products_Catalog (
        id INTEGER PRIMARY KEY,
        name $textType,
        image_path $textType,
        base_price $intType
      )
    ''');

    await db.execute('''
      CREATE TABLE Machine_Layout (
        shelf_number INTEGER PRIMARY KEY,
        columns_count $intType
      )
    ''');

    await db.execute('''
      CREATE TABLE Racks_Inventory (
        rack_number INTEGER PRIMARY KEY,
        physical_address $intType,
        product_id $intType,
        current_price $intType,
        stock $intType,
        status $boolType,
        FOREIGN KEY (product_id) REFERENCES Products_Catalog (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE Machine_Addons (
        id INTEGER PRIMARY KEY,
        name $textType,
        value_type $textType,
        hardware_cmd $textType
      )
    ''');

    await db.execute('''
      CREATE TABLE Rack_Addons_Mapper (
        id $idType,
        rack_number $intType,
        addon_id $intType,
        addon_value $intType,
        FOREIGN KEY (rack_number) REFERENCES Racks_Inventory (rack_number),
        FOREIGN KEY (addon_id) REFERENCES Machine_Addons (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE Orders (
        id TEXT PRIMARY KEY,
        total_amount $intType,
        cart_capacity $intType,
        pos_status $textType,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Order_Items (
        id $idType,
        order_id TEXT NOT NULL,
        rack_number $intType,
        product_id $intType,
        sold_price $intType,
        delivery_status $textType,
        delivered_at TEXT,
        FOREIGN KEY (order_id) REFERENCES Orders (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE System_Logs (
        id $idType,
        log_type $textType,
        error_code $textType,
        description $textType,
        timestamp TEXT NOT NULL,
        is_synced $boolType
      )
    ''');

    await db.execute('''
      CREATE TABLE System_Configs (
        machine_id TEXT PRIMARY KEY,
        server_base_url $textType,
        last_sync TEXT NOT NULL,
        board_ip $textType,
        maintenance_mode $boolType,
        db_version $intType
      )
    ''');
  }
}