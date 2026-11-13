import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('exolog.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Животные и родословная
    await db.execute('''
      CREATE TABLE animals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        species TEXT NOT NULL,
        morph TEXT,
        sex TEXT NOT NULL,
        birth_date TEXT,
        photo_path TEXT,
        father_id INTEGER,
        mother_id INTEGER,
        feeding_interval_days INTEGER DEFAULT 7,
        quarantine_until TEXT,
        uv_lamp_install_date TEXT,
        uv_lamp_lifespan_months INTEGER DEFAULT 6,
        FOREIGN KEY (father_id) REFERENCES animals (id),
        FOREIGN KEY (mother_id) REFERENCES animals (id)
      )
    ''');

    // 2. Склад кормов
    await db.execute('''
      CREATE TABLE inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        count INTEGER NOT NULL DEFAULT 0,
        unit TEXT NOT NULL DEFAULT 'шт',
        min_threshold INTEGER DEFAULT 5
      )
    ''');

    // 3. Кормления (связано со складом)
    await db.execute('''
      CREATE TABLE feedings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        food_item_id INTEGER,
        quantity INTEGER DEFAULT 1,
        status TEXT NOT NULL, -- 'eaten' / 'refused'
        notes TEXT,
        FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE,
        FOREIGN KEY (food_item_id) REFERENCES inventory (id)
      )
    ''');

    // 4. Замеры и динамика роста
    await db.execute('''
      CREATE TABLE measurements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        weight_grams REAL,
        length_cm REAL,
        FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');

    // 5. События здоровья (линьки, лечение, уборка)
    await db.execute('''
      CREATE TABLE health_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        event_type TEXT NOT NULL, -- 'shedding', 'treatment', 'vet', 'cleaning'
        description TEXT,
        photo_path TEXT,
        FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');

    // 6. Зимовка и фазы
    await db.execute('''
      CREATE TABLE brumation (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_id INTEGER NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT,
        current_phase TEXT NOT NULL, -- 'preparation', 'cooling', 'warming'
        target_temp REAL,
        notes TEXT,
        FOREIGN KEY (animal_id) REFERENCES animals (id) ON DELETE CASCADE
      )
    ''');
  }

  // Списание корма со склада при успешном кормлении
  Future<void> logFeeding({
    required int animalId,
    required DateTime date,
    required int? foodItemId,
    required int quantity,
    required String status,
    String? notes,
  }) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.insert('feedings', {
        'animal_id': animalId,
        'date': date.toIso8601String(),
        'food_item_id': foodItemId,
        'quantity': quantity,
        'status': status,
        'notes': notes,
      });

      // Автоматически уменьшаем остаток на складе, если съедено
      if (status == 'eaten' && foodItemId != null) {
        await txn.rawUpdate('''
          UPDATE inventory 
          SET count = MAX(0, count - ?) 
          WHERE id = ?
        ''', [quantity, foodItemId]);
      }
    });
  }
}