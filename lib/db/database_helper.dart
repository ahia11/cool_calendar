import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:calendar_app/models/event_model.dart'; // 引入刚才写的模型

class DatabaseHelper {
  // 1. 单例模式：确保全局只有一个数据库连接助手
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // 2. 获取数据库对象 (如果没打开过就打开，打开过就直接用)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('calendar.db'); // 数据库文件名
    return _database!;
  }

  // 3. 初始化数据库
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB, // 第一次创建时执行建表
    );
  }

  // 4. 创建表结构 (对应 Event 模型)
  Future _createDB(Database db, int version) async {
    // ID 类型为 INTEGER PRIMARY KEY AUTOINCREMENT (自增主键)
    // bool 类型在 SQLite 里用 INTEGER (0或1) 代替
    // DateTime 类型存为 TEXT (ISO8601 字符串)
    await db.execute('''
    CREATE TABLE events ( 
      id INTEGER PRIMARY KEY AUTOINCREMENT, 
      title TEXT NOT NULL,
      description TEXT,
      date TEXT NOT NULL,
      startTime TEXT NOT NULL,
      endTime TEXT NOT NULL,
      isAllDay INTEGER NOT NULL
    )
    ''');
  }

  // --- 下面是 CRUD (增删改查) 操作 ---

  // 新增日程
  Future<int> create(Event event) async {
    final db = await instance.database;
    return await db.insert('events', event.toMap());
  }

  // 查询某一个日程
  Future<Event> readEvent(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'events',
      columns: null, // null 表示查询所有字段
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Event.fromMap(maps.first);
    } else {
      throw Exception('ID $id not found');
    }
  }

  // 查询所有日程 (按开始时间排序)
  Future<List<Event>> readAllEvents() async {
    final db = await instance.database;
    final result = await db.query('events', orderBy: 'startTime ASC');

    return result.map((json) => Event.fromMap(json)).toList();
  }
  
  // 根据日期查询日程 (用于点击日历某一天时显示)
  Future<List<Event>> readEventsByDate(DateTime date) async {
    final db = await instance.database;
    
    // 这里的逻辑稍微简单粗暴点：比对 date 字符串的前10位 (yyyy-MM-dd)
    // 实际开发中也可以用 SQL 的 strftime 函数
    final dateStr = date.toIso8601String().substring(0, 10); 
    
    final result = await db.query(
      'events',
      where: 'date LIKE ?',
      whereArgs: ['$dateStr%'], // 模糊查询匹配当天
      orderBy: 'startTime ASC'
    );

    return result.map((json) => Event.fromMap(json)).toList();
  }

  // 更新日程
  Future<int> update(Event event) async {
    final db = await instance.database;
    return db.update(
      'events',
      event.toMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  // 删除日程
  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'events',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  // 关闭数据库 (通常不用手动调，但写上也无妨)
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}