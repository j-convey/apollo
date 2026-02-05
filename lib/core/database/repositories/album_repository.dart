import 'package:flutter/foundation.dart';
import '../../models/album.dart';
import '../../models/track.dart';
import 'base_repository.dart';

/// Repository for album-related database operations
class AlbumRepository extends BaseRepository {
  AlbumRepository(super.getDatabase);

  // ============================================================
  // READ OPERATIONS - Single Responsibility
  // ============================================================

  /// Get all albums (uses view for computed data)
  Future<List<Album>> getAll() async {
    final maps = await rawQuery('''
      SELECT * FROM v_albums_full ORDER BY title COLLATE NOCASE ASC
    ''');
    return maps.map(Album.fromDb).toList();
  }

  /// Get album by rating key
  Future<Album?> getByRatingKey(String ratingKey) async {
    final maps = await rawQuery('''
      SELECT * FROM v_albums_full WHERE rating_key = ?
    ''', [ratingKey]);
    if (maps.isEmpty) return null;
    return Album.fromDb(maps.first);
  }

  /// Get album by internal ID
  Future<Album?> getById(int id) async {
    final maps = await rawQuery('''
      SELECT * FROM v_albums_full WHERE id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return Album.fromDb(maps.first);
  }

  /// Get albums by artist rating key
  Future<List<Album>> getByArtist(String artistRatingKey) async {
    final maps = await rawQuery('''
      SELECT * FROM v_albums_full 
      WHERE artist_rating_key = ?
      ORDER BY year DESC, title COLLATE NOCASE ASC
    ''', [artistRatingKey]);
    return maps.map(Album.fromDb).toList();
  }

  /// Get albums by year
  Future<List<Album>> getByYear(int year) async {
    final maps = await rawQuery('''
      SELECT * FROM v_albums_full 
      WHERE year = ?
      ORDER BY title COLLATE NOCASE ASC
    ''', [year]);
    return maps.map(Album.fromDb).toList();
  }

  /// Get recently added albums
  Future<List<Album>> getRecent({int limit = 20}) async {
    final maps = await rawQuery('''
      SELECT * FROM v_albums_full 
      ORDER BY added_at DESC
      LIMIT ?
    ''', [limit]);
    return maps.map(Album.fromDb).toList();
  }

  /// Search albums by title or artist
  Future<List<Album>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final searchQuery = '%${query.toLowerCase()}%';
    final maps = await rawQuery('''
      SELECT * FROM v_albums_full 
      WHERE title COLLATE NOCASE LIKE ? OR artist_title COLLATE NOCASE LIKE ?
      ORDER BY title COLLATE NOCASE ASC
      LIMIT ?
    ''', [searchQuery, searchQuery, limit]);
    return maps.map(Album.fromDb).toList();
  }

  /// Get album count
  Future<int> getCount() async {
    return count('albums');
  }

  /// Get total duration of an album
  Future<int> getDuration(String albumRatingKey) async {
    final result = await rawQuery('''
      SELECT COALESCE(SUM(duration), 0) as total_duration
      FROM v_tracks_full WHERE album_rating_key = ?
    ''', [albumRatingKey]);
    return result.first['total_duration'] as int? ?? 0;
  }

  // ============================================================
  // EAGER LOADING - Fetch with relationships
  // ============================================================

  /// Get album with its tracks
  Future<Album?> getWithTracks(String ratingKey) async {
    final album = await getByRatingKey(ratingKey);
    if (album == null) return null;

    final trackMaps = await rawQuery('''
      SELECT * FROM v_tracks_full 
      WHERE album_rating_key = ?
      ORDER BY disc_number ASC, track_number ASC, title COLLATE NOCASE ASC
    ''', [ratingKey]);

    return album.copyWith(
      tracks: trackMaps.map(Track.fromDb).toList(),
    );
  }

  /// Get album with tracks by internal ID
  Future<Album?> getWithTracksById(int albumId) async {
    final album = await getById(albumId);
    if (album == null) return null;

    final trackMaps = await rawQuery('''
      SELECT * FROM v_tracks_full 
      WHERE album_id = ?
      ORDER BY disc_number ASC, track_number ASC, title COLLATE NOCASE ASC
    ''', [albumId]);

    return album.copyWith(
      tracks: trackMaps.map(Track.fromDb).toList(),
    );
  }

  /// Get all albums with their tracks (single query, grouped in Dart)
  Future<List<Album>> getAllWithTracks() async {
    // Fetch all albums
    final albums = await getAll();
    if (albums.isEmpty) return [];

    // Fetch all tracks in one query
    final trackMaps = await rawQuery('''
      SELECT * FROM v_tracks_full 
      ORDER BY album_id, disc_number, track_number
    ''');
    final allTracks = trackMaps.map(Track.fromDb).toList();

    // Group tracks by album ID
    final tracksByAlbum = <int, List<Track>>{};
    for (final track in allTracks) {
      if (track.albumId != null) {
        tracksByAlbum.putIfAbsent(track.albumId!, () => []).add(track);
      }
    }

    // Attach tracks to albums
    return albums.map((album) {
      return album.copyWith(tracks: tracksByAlbum[album.id] ?? []);
    }).toList();
  }

  // ============================================================
  // WRITE OPERATIONS
  // ============================================================

  /// Save or update an album
  Future<int> save(Album album) async {
    final id = await insert('albums', album.toDb());
    
    final result = await query(
      'albums',
      where: 'rating_key = ?',
      whereArgs: [album.ratingKey],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first['id'] as int : id;
  }

  /// Update album track count
  Future<void> updateTrackCount(String albumRatingKey) async {
    await rawQuery('''
      UPDATE albums 
      SET track_count = (
        SELECT COUNT(*) FROM tracks t 
        JOIN albums alb ON t.album_id = alb.id 
        WHERE alb.rating_key = ?
      ),
      updated_at = ?
      WHERE rating_key = ?
    ''', [albumRatingKey, DateTime.now().millisecondsSinceEpoch, albumRatingKey]);
  }

  /// Delete an album
  Future<void> deleteByRatingKey(String ratingKey, {bool cascade = false}) async {
    if (cascade) {
      final album = await getByRatingKey(ratingKey);
      if (album != null && album.id != null) {
        await delete('tracks', where: 'album_id = ?', whereArgs: [album.id]);
      }
    }
    await delete('albums', where: 'rating_key = ?', whereArgs: [ratingKey]);
  }

  /// Clear all albums
  Future<void> clearAll({bool cascade = false}) async {
    if (cascade) {
      await delete('tracks');
    }
    await delete('albums');
    debugPrint('DATABASE: Cleared all albums');
  }
}