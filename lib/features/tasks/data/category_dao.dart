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

    final baseId = normalized
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    var id = baseId.isEmpty ? 'category' : baseId;
    var index = 2;
    while (true) {
      final rows = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) break;
      id = '${baseId}_$index';
      index++;
    }

    final category = Category(
      id: id,
      name: normalized,
      colorValue: 0xFF8B5CF6,
      iconCode: null,
    );
    await db.insert('categories', category.toMap());
    return category.id;
  }

  Future<void> renameCategory(String categoryId, String name) async {
    final db = await AppDatabase.instance.database;
    final normalized = name.trim();
    if (normalized.isEmpty) return;
    await db.update(
      'categories',
      {'name': normalized},
      where: 'id = ?',
      whereArgs: [categoryId],
    );
  }

  /// Deletes the category and reassigns its tasks to none, both in one
  /// transaction so no task is ever left pointing at a category that is gone.
  Future<void> deleteCategory(String categoryId) async {
    final db = await AppDatabase.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'tasks',
        {'category_id': null},
        where: 'category_id = ?',
        whereArgs: [categoryId],
      );
      await txn.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
    });
  }
}
