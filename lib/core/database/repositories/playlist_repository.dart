import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show ConflictAlgorithm;
import '../../models/playlist.dart';
import '../../models/track.dart';
import 'base_repository.dart';

/// Repository for playlist-related database operations
class PlaylistRepository extends BaseRepository {
  PlaylistRepository(super.getDatabase);

  // ============================================================
  // READ OPERATIONS
  // ============================================================

  /// Get all playlists
  Future<List<Playlist>> getAll() async {
    final maps = await query('playlists', orderBy: 'title COLLATE NOCASE ASC');
    return maps.map(Playlist.fromDb).toList();
  }

  /// Get playlist by ID
  Future<Playlist?> getById(String id) async {
    final maps = await query(
      'playlists',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Playlist.fromDb(maps.first);
  }

  /// Get playlists for a server
  Future<List<Playlist>> getByServer(String serverId) async {
    final maps = await query(
      'playlists',
      where: 'server_id = ?',
      whereArgs: [serverId],
      orderBy: 'title COLLATE NOCASE ASC',
    );
    return maps.map(Playlist.fromDb).toList();
  }

  /// Search playlists by title
  Future<List<Playlist>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final searchQuery = '%${query.toLowerCase()}%';
    final maps = await rawQuery('''
      SELECT * FROM playlists 
      WHERE title COLLATE NOCASE LIKE ?
      ORDER BY title COLLATE NOCASE ASC
      LIMIT ?
    ''', [searchQuery, limit]);
    return maps.map(Playlist.fromDb).toList();
  }

  /// Get playlist count
  Future<int> getCount() async {
    return count('playlists');
  }

  // ============================================================
  // EAGER LOADING
  // ============================================================

  /// Get playlist with its tracks
  Future<Playlist?> getWithTracks(String playlistId) async {
    final playlist = await getById(playlistId);
    if (playlist == null) return null;

    final trackMaps = await rawQuery('''
      SELECT * FROM v_playlist_tracks_full 
      WHERE playlist_id = ?
      ORDER BY position ASC
    ''', [playlistId]);

    return playlist.copyWith(
      tracks: trackMaps.map(Track.fromDb).toList(),
    );
  }

  /// Get tracks for a playlist
  Future<List<Track>> getTracks(String playlistId) async {
    final trackMaps = await rawQuery('''
      SELECT * FROM v_playlist_tracks_full 
      WHERE playlist_id = ?
      ORDER BY position ASC
    ''', [playlistId]);
    return trackMaps.map(Track.fromDb).toList();
  }

  // ============================================================
  // WRITE OPERATIONS
  // ============================================================

  /// Save playlists
  Future<void> saveAll(List<Playlist> playlists) async {
    final db = await getDatabase();
    final batch = db.batch();

    for (final playlist in playlists) {
      batch.insert(
        'playlists',
        playlist.toDb(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('DATABASE: Saved ${playlists.length} playlists');
  }

  /// Save playlist tracks
  Future<void> saveTracks(String playlistId, List<Track> tracks) async {
    // Delete existing associations
    await delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [playlistId]);

    // Insert new associations
    int position = 0;
    for (final track in tracks) {
      final trackResults = await query(
        'tracks',
        where: 'track_key = ?',
        whereArgs: [track.trackKey],
        limit: 1,
      );

      if (trackResults.isNotEmpty) {
        await insert('playlist_tracks', {
          'playlist_id': playlistId,
          'track_id': trackResults.first['id'],
          'position': position++,
        });
      }
    }

    debugPrint('DATABASE: Saved ${tracks.length} tracks for playlist $playlistId');
  }

  /// Delete a playlist
  Future<void> deleteById(String playlistId) async {
    await delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [playlistId]);
    await delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
    debugPrint('DATABASE: Deleted playlist $playlistId');
  }

  /// Clear all playlists
  Future<void> clearAll() async {
    await delete('playlist_tracks');
    await delete('playlists');
    debugPrint('DATABASE: Cleared all playlists');
  }
}