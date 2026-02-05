import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Base class for all repositories
/// Provides common database access and utility methods
abstract class BaseRepository {
  final Future<Database> Function() getDatabase;

  BaseRepository(this.getDatabase);

  /// Execute a query and return results
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await getDatabase();
    return db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  /// Execute a raw query
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) async {
    final db = await getDatabase();
    return db.rawQuery(sql, arguments);
  }

  /// Insert a record
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace,
  }) async {
    final db = await getDatabase();
    return db.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  /// Update records
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await getDatabase();
    return db.update(table, values, where: where, whereArgs: whereArgs);
  }

  /// Delete records
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final db = await getDatabase();
    return db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Get count of records
  Future<int> count(String table, {String? where, List<Object?>? whereArgs}) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $table${where != null ? ' WHERE $where' : ''}',
      whereArgs,
    );
    return result.first['count'] as int;
  }
}