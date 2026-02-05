/// SQL indexes for query optimization
class IndexSchema {
  static const List<String> createIndexes = [
    // Track indexes
    'CREATE INDEX IF NOT EXISTS idx_tracks_server_library ON tracks(server_id, library_key)',
    'CREATE INDEX IF NOT EXISTS idx_tracks_artist ON tracks(artist_id)',
    'CREATE INDEX IF NOT EXISTS idx_tracks_album ON tracks(album_id)',
    'CREATE INDEX IF NOT EXISTS idx_tracks_album_order ON tracks(album_id, disc_number, track_number)',
    'CREATE INDEX IF NOT EXISTS idx_tracks_rating_key ON tracks(rating_key)',
    'CREATE INDEX IF NOT EXISTS idx_tracks_parent_key ON tracks(parent_rating_key)',
    'CREATE INDEX IF NOT EXISTS idx_tracks_title_lower ON tracks(title COLLATE NOCASE)',
    'CREATE INDEX IF NOT EXISTS idx_tracks_added ON tracks(added_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_tracks_rating ON tracks(user_rating)',
    
    // Album indexes
    'CREATE INDEX IF NOT EXISTS idx_albums_artist ON albums(artist_id)',
    'CREATE INDEX IF NOT EXISTS idx_albums_year ON albums(year DESC)',
    'CREATE INDEX IF NOT EXISTS idx_albums_artist_year ON albums(artist_id, year DESC)',
    'CREATE INDEX IF NOT EXISTS idx_albums_rating_key ON albums(rating_key)',
    'CREATE INDEX IF NOT EXISTS idx_albums_title_lower ON albums(title COLLATE NOCASE)',
    'CREATE INDEX IF NOT EXISTS idx_albums_added ON albums(added_at DESC)',
    
    // Artist indexes
    'CREATE INDEX IF NOT EXISTS idx_artists_rating_key ON artists(rating_key)',
    'CREATE INDEX IF NOT EXISTS idx_artists_title_lower ON artists(title COLLATE NOCASE)',
    
    // Playlist indexes
    'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_playlist ON playlist_tracks(playlist_id)',
    'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_track ON playlist_tracks(track_id)',
    'CREATE INDEX IF NOT EXISTS idx_playlist_tracks_position ON playlist_tracks(playlist_id, position)',
  ];

  /// Execute all index creation statements safely
  /// Each index is wrapped in try-catch to handle missing columns in old databases
  static Future<void> createAll(dynamic db) async {
    for (final sql in createIndexes) {
      try {
        await db.execute(sql);
      } catch (e) {
        // Index may already exist or column may not exist in old schema
        // This is safe to ignore during migrations
      }
    }
  }
}