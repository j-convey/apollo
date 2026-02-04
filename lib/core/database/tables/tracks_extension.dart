part of '../database_service.dart';

extension TracksExtension on DatabaseService {
  // Save tracks to database
  Future<void> saveTracks(
    String serverId,
    String libraryKey,
    List<Map<String, dynamic>> tracks,
  ) async {
    final db = await database;
    final batch = db.batch();

    // Delete existing tracks for this server/library
    batch.delete(
      'tracks',
      where: 'server_id = ? AND library_key = ?',
      whereArgs: [serverId, libraryKey],
    );

    // Insert new tracks
    for (var track in tracks) {
      batch.insert(
        'tracks',
        {
          'server_id': serverId,
          'library_key': libraryKey,
          'track_key': track['key'] ?? '',
          'title': track['title'] ?? 'Unknown',
          'artist': track['artist'] ?? 'Unknown Artist',
          'album': track['album'] ?? 'Unknown Album',
          'duration': track['duration'] ?? 0,
          'thumb': track['thumb'] ?? '',
          'year': track['year'] ?? 0,
          'added_at': track['addedAt'],
          'media_data': jsonEncode(track['Media'] ?? []),
          'user_rating': track['userRating'],
          // Artist and album info for navigation
          'rating_key': track['ratingKey']?.toString(),
          'grandparent_rating_key': track['grandparentRatingKey']?.toString(),
          'grandparent_title': track['grandparentTitle'],
          'grandparent_thumb': track['grandparentThumb'],
          'grandparent_art': track['grandparentArt'],
          'parent_title': track['parentTitle'],
          'parent_thumb': track['parentThumb'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    // Update sync metadata
    await db.insert(
      'sync_metadata',
      {
        'server_id': serverId,
        'library_key': libraryKey,
        'last_sync': DateTime.now().millisecondsSinceEpoch,
        'track_count': tracks.length,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    print('DATABASE: Saved ${tracks.length} tracks for server $serverId, library $libraryKey');
  }

  // Get all tracks from database
  Future<List<Map<String, dynamic>>> getAllTracks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tracks');

    return maps.map((map) => _mapTrackFromDb(map)).toList();
  }

  // Helper method to map database row to track format
  Map<String, dynamic> _mapTrackFromDb(Map<String, dynamic> map) {
    return {
      'title': map['title'] as String,
      'artist': map['artist'] as String?,
      'album': map['album'] as String?,
      'duration': map['duration'] as int,
      'key': map['track_key'] as String,
      'thumb': map['thumb'] as String?,
      'year': map['year'] as int?,
      'addedAt': map['added_at'] as int?,
      'serverId': map['server_id'] as String,
      'libraryKey': map['library_key'] as String,
      'Media': _parseMediaData(map['media_data'] as String? ?? ''),
      'userRating': map['user_rating'] as double?,
      // Artist and album info for navigation
      'ratingKey': map['rating_key'] as String?,
      'grandparentRatingKey': map['grandparent_rating_key'] as String?,
      'grandparentTitle': map['grandparent_title'] as String?,
      'grandparentThumb': map['grandparent_thumb'] as String?,
      'grandparentArt': map['grandparent_art'] as String?,
      'parentTitle': map['parent_title'] as String?,
      'parentThumb': map['parent_thumb'] as String?,
    };
  }

  // Get tracks for specific server/library
  Future<List<Map<String, dynamic>>> getTracksForLibrary(
    String serverId,
    String libraryKey,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tracks',
      where: 'server_id = ? AND library_key = ?',
      whereArgs: [serverId, libraryKey],
    );

    return maps.map((map) => _mapTrackFromDb(map)).toList();
  }

  // Get sync metadata
  Future<Map<String, dynamic>?> getSyncMetadata(String serverId, String libraryKey) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'sync_metadata',
      where: 'server_id = ? AND library_key = ?',
      whereArgs: [serverId, libraryKey],
    );

    if (maps.isEmpty) return null;
    return maps.first;
  }

  // Check if we have cached data
  Future<bool> hasCachedTracks() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM tracks');
    final count = result.first['count'] as int;
    return count > 0;
  }

  // Clear all tracks
  Future<void> clearAllTracks() async {
    final db = await database;
    await db.delete('tracks');
    await db.delete('sync_metadata');
    print('DATABASE: Cleared all tracks');
  }

  // Clear tracks for specific server
  Future<void> clearServerTracks(String serverId) async {
    final db = await database;
    await db.delete('tracks', where: 'server_id = ?', whereArgs: [serverId]);
    await db.delete('sync_metadata', where: 'server_id = ?', whereArgs: [serverId]);
    print('DATABASE: Cleared tracks for server $serverId');
  }

  // Get track count
  Future<int> getTrackCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM tracks');
    return result.first['count'] as int;
  }

  // Get all sync info
  Future<List<Map<String, dynamic>>> getAllSyncMetadata() async {
    final db = await database;
    return await db.query('sync_metadata');
  }

  // Search tracks by title, artist, or album
  Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];
    
    final db = await database;
    final searchQuery = '%${query.toLowerCase()}%';
    
    final List<Map<String, dynamic>> maps = await db.query(
      'tracks',
      where: 'LOWER(title) LIKE ? OR LOWER(artist) LIKE ? OR LOWER(album) LIKE ?',
      whereArgs: [searchQuery, searchQuery, searchQuery],
      limit: 20, // Limit results to top 20 matches
      orderBy: 'title ASC',
    );

    return maps.map((map) => _mapTrackFromDb(map)).toList();
  }

  // Search for unique artists by name
  Future<List<Map<String, dynamic>>> searchArtists(String query) async {
    if (query.trim().isEmpty) return [];
    
    final db = await database;
    final searchQuery = '%${query.toLowerCase()}%';
    
    // Get unique artists matching the search query
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT
        grandparent_rating_key as artistId,
        grandparent_title as artistName,
        grandparent_thumb as artistThumb,
        server_id as serverId
      FROM tracks
      WHERE LOWER(grandparent_title) LIKE ?
        AND grandparent_rating_key IS NOT NULL
        AND grandparent_title IS NOT NULL
      ORDER BY grandparent_title ASC
      LIMIT 10
    ''', [searchQuery]);

    return maps;
  }

  // Get liked tracks (user_rating >= 10.0)
  Future<List<Map<String, dynamic>>> getLikedTracks() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'tracks',
      where: 'user_rating >= ?',
      whereArgs: [10.0], // Plex typically uses 10.0 for "Liked"
      orderBy: 'title ASC',
    );

    return maps.map((map) => _mapTrackFromDb(map)).toList();
  }
}