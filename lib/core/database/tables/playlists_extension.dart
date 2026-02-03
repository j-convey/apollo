part of '../database_service.dart';

extension PlaylistsExtension on DatabaseService {
  // Save playlists to database
  Future<void> savePlaylists(List<Map<String, dynamic>> playlists) async {
    final db = await database;
    final batch = db.batch();

    for (var playlist in playlists) {
      batch.insert(
        'playlists',
        playlist,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print('DATABASE: Saved ${playlists.length} playlists');
  }

  // Get all playlists from database
  Future<List<Map<String, dynamic>>> getAllPlaylists() async {
    final db = await database;
    return await db.query('playlists', orderBy: 'title ASC');
  }
}