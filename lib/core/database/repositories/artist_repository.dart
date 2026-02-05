import 'package:flutter/foundation.dart';
import '../../models/artist.dart';
import '../../models/album.dart';
import '../../models/track.dart';
import 'base_repository.dart';

/// Repository for artist-related database operations
class ArtistRepository extends BaseRepository {
  ArtistRepository(super.getDatabase);

  // ============================================================
  // READ OPERATIONS - Single Responsibility
  // ============================================================

  /// Get all artists (uses view for computed counts)
  Future<List<Artist>> getAll() async {
    final maps = await rawQuery('''
      SELECT * FROM v_artists_full ORDER BY title COLLATE NOCASE ASC
    ''');
    return maps.map(Artist.fromDb).toList();
  }

  /// Get artist by rating key
  Future<Artist?> getByRatingKey(String ratingKey) async {
    final maps = await rawQuery('''
      SELECT * FROM v_artists_full WHERE rating_key = ?
    ''', [ratingKey]);
    if (maps.isEmpty) return null;
    return Artist.fromDb(maps.first);
  }

  /// Get artist by internal ID
  Future<Artist?> getById(int id) async {
    final maps = await rawQuery('''
      SELECT * FROM v_artists_full WHERE id = ?
    ''', [id]);
    if (maps.isEmpty) return null;
    return Artist.fromDb(maps.first);
  }

  /// Search artists by name
  Future<List<Artist>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    final searchQuery = '%${query.toLowerCase()}%';
    final maps = await rawQuery('''
      SELECT * FROM v_artists_full 
      WHERE title COLLATE NOCASE LIKE ?
      ORDER BY title COLLATE NOCASE ASC
      LIMIT ?
    ''', [searchQuery, limit]);
    return maps.map(Artist.fromDb).toList();
  }

  /// Get artist count
  Future<int> getCount() async {
    return count('artists');
  }

  // ============================================================
  // EAGER LOADING - Fetch with relationships
  // ============================================================

  /// Get artist with their albums
  Future<Artist?> getWithAlbums(String ratingKey) async {
    final artist = await getByRatingKey(ratingKey);
    if (artist == null) return null;

    final albumMaps = await rawQuery('''
      SELECT * FROM v_albums_full 
      WHERE artist_id = ?
      ORDER BY year DESC, title COLLATE NOCASE ASC
    ''', [artist.id]);

    return artist.copyWith(
      albums: albumMaps.map(Album.fromDb).toList(),
    );
  }

  /// Get artist with all their tracks
  Future<Artist?> getWithTracks(String ratingKey) async {
    final artist = await getByRatingKey(ratingKey);
    if (artist == null) return null;

    final trackMaps = await rawQuery('''
      SELECT * FROM v_tracks_full 
      WHERE artist_id = ?
      ORDER BY album_name, disc_number, track_number
    ''', [artist.id]);

    return artist.copyWith(
      tracks: trackMaps.map(Track.fromDb).toList(),
    );
  }

  /// Get artist with albums and all tracks
  Future<Artist?> getWithAlbumsAndTracks(String ratingKey) async {
    final artist = await getByRatingKey(ratingKey);
    if (artist == null) return null;

    // Get albums
    final albumMaps = await rawQuery('''
      SELECT * FROM v_albums_full 
      WHERE artist_id = ?
      ORDER BY year DESC, title COLLATE NOCASE ASC
    ''', [artist.id]);
    final albums = albumMaps.map(Album.fromDb).toList();

    // Get all tracks for this artist
    final trackMaps = await rawQuery('''
      SELECT * FROM v_tracks_full 
      WHERE artist_id = ?
      ORDER BY album_id, disc_number, track_number
    ''', [artist.id]);
    final allTracks = trackMaps.map(Track.fromDb).toList();

    // Group tracks by album
    final tracksByAlbum = <int, List<Track>>{};
    for (final track in allTracks) {
      if (track.albumId != null) {
        tracksByAlbum.putIfAbsent(track.albumId!, () => []).add(track);
      }
    }

    // Attach tracks to albums
    final albumsWithTracks = albums.map((album) {
      return album.copyWith(tracks: tracksByAlbum[album.id] ?? []);
    }).toList();

    return artist.copyWith(
      albums: albumsWithTracks,
      tracks: allTracks,
    );
  }

  // ============================================================
  // WRITE OPERATIONS
  // ============================================================

  /// Save or update an artist
  Future<int> save(Artist artist) async {
    final id = await insert('artists', artist.toDb());
    
    // Get the actual ID after upsert
    final result = await query(
      'artists',
      where: 'rating_key = ?',
      whereArgs: [artist.ratingKey],
      limit: 1,
    );
    
    return result.isNotEmpty ? result.first['id'] as int : id;
  }

  /// Delete an artist
  Future<void> deleteByRatingKey(String ratingKey, {bool cascade = false}) async {
    if (cascade) {
      final artist = await getByRatingKey(ratingKey);
      if (artist != null && artist.id != null) {
        await delete('tracks', where: 'artist_id = ?', whereArgs: [artist.id]);
        await delete('albums', where: 'artist_id = ?', whereArgs: [artist.id]);
      }
    }
    await delete('artists', where: 'rating_key = ?', whereArgs: [ratingKey]);
  }

  /// Clear all artists
  Future<void> clearAll({bool cascade = false}) async {
    if (cascade) {
      await delete('tracks');
      await delete('albums');
    }
    await delete('artists');
    debugPrint('DATABASE: Cleared all artists');
  }
}
