import 'package:todo/core/db/app_database.dart';
import 'package:todo/features/tasks/domain/category.dart';

class CategoryDao {
  Future<List<Category>> getCategories() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map((row) => Category.fromMap(row)).toList();
  }

  Future<String> createCategory(String name) async {
    final db = await AppDatabase.instance.database;
    final normalized = name.trim();
    if (normalized.isEmpty) return 'general';
    final existing = await db.query(
      'categories',
      where: 'name = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as String;

    final id = normalized.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final category = Category(
      id: id,
      name: normalized,
      colorValue: 0xFF8B5CF6,
      iconCode: null,
    );
    await db.insert('categories', category.toMap());
    return category.id;
  }
}
