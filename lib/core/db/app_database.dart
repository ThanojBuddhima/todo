import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static AppDatabase get instance => _instance;

  Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'todo_app.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            color_value INTEGER NOT NULL,
            icon_code INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            notes TEXT,
            category_id TEXT,
            priority INTEGER NOT NULL DEFAULT 1,
            due_at INTEGER,
            remind_at INTEGER,
            notification_id INTEGER,
            is_done INTEGER NOT NULL DEFAULT 0,
            completed_at INTEGER,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            sort_index REAL NOT NULL DEFAULT 0,
            deleted_at INTEGER,
            FOREIGN KEY (category_id) REFERENCES categories(id)
          )
        ''');

        await db.execute('''
          CREATE TABLE subtasks (
            id TEXT PRIMARY KEY,
            task_id TEXT NOT NULL,
            title TEXT NOT NULL,
            is_done INTEGER NOT NULL DEFAULT 0,
            sort_index REAL NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE activity_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            task_id TEXT,
            task_title TEXT NOT NULL,
            category_name TEXT,
            action INTEGER NOT NULL,
            field TEXT,
            old_value TEXT,
            new_value TEXT,
            occurred_at INTEGER NOT NULL
          )
        ''');

        await db.execute('CREATE INDEX idx_activity_time ON activity_log(occurred_at)');
        await db.execute('CREATE INDEX idx_tasks_due ON tasks(due_at)');

        await db.insert('categories', {
          'id': 'general',
          'name': 'General',
          'color_value': 0xFF6C5CE7,
          'icon_code': 0,
        });
        await db.insert('categories', {
          'id': 'work',
          'name': 'Work',
          'color_value': 0xFF3B82F6,
          'icon_code': 0,
        });
        await db.insert('categories', {
          'id': 'personal',
          'name': 'Personal',
          'color_value': 0xFF10B981,
          'icon_code': 0,
        });
        await db.insert('categories', {
          'id': 'errands',
          'name': 'Errands',
          'color_value': 0xFFF59E0B,
          'icon_code': 0,
        });
      },
    );
  }
}
