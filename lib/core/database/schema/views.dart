/// SQL Views for common query patterns
/// These eliminate duplicate JOIN logic across repositories
class ViewSchema {
  /// Full track view with all relationships joined
  static const String createTracksFullView = '''
    CREATE VIEW IF NOT EXISTS v_tracks_full AS
    SELECT 
      t.*,
      t.artist_name as artist_name_stored,
      t.album_name as album_name_stored,
      a.id as artist_id_joined,
      a.title as artist_name,
      a.thumb as artist_thumb,
      a.rating_key as artist_rating_key,
      alb.id as album_id_joined,
      alb.title as album_name,
      alb.thumb as album_thumb,
      alb.rating_key as album_rating_key,
      alb.year as album_year
    FROM tracks t
    LEFT JOIN artists a ON t.artist_id = a.id
    LEFT JOIN albums alb ON t.album_id = alb.id
  ''';

  /// Album view with computed track counts and total duration
  static const String createAlbumsFullView = '''
    CREATE VIEW IF NOT EXISTS v_albums_full AS
    SELECT 
      alb.*,
      a.title as artist_title,
      a.rating_key as artist_rating_key,
      a.thumb as artist_thumb,
      COALESCE(COUNT(t.id), 0) as computed_track_count,
      COALESCE(SUM(t.duration), 0) as total_duration
    FROM albums alb
    LEFT JOIN artists a ON alb.artist_id = a.id
    LEFT JOIN tracks t ON t.album_id = alb.id
    GROUP BY alb.id
  ''';

  /// Artist view with computed album and track counts
  static const String createArtistsFullView = '''
    CREATE VIEW IF NOT EXISTS v_artists_full AS
    SELECT 
      a.*,
      COUNT(DISTINCT alb.id) as album_count,
      COUNT(DISTINCT t.id) as track_count
    FROM artists a
    LEFT JOIN albums alb ON alb.artist_id = a.id
    LEFT JOIN tracks t ON t.artist_id = a.id
    GROUP BY a.id
  ''';

  /// Playlist tracks view with full track details
  static const String createPlaylistTracksFullView = '''
    CREATE VIEW IF NOT EXISTS v_playlist_tracks_full AS
    SELECT 
      pt.playlist_id,
      pt.position,
      t.*,
      t.artist_name as artist_name_stored,
      t.album_name as album_name_stored,
      a.title as artist_name,
      a.thumb as artist_thumb,
      a.rating_key as artist_rating_key,
      alb.title as album_name,
      alb.thumb as album_thumb,
      alb.rating_key as album_rating_key
    FROM playlist_tracks pt
    JOIN tracks t ON pt.track_id = t.id
    LEFT JOIN artists a ON t.artist_id = a.id
    LEFT JOIN albums alb ON t.album_id = alb.id
  ''';

  /// Execute all view creation statements
  static Future<void> createAll(dynamic db) async {
    await db.execute(createTracksFullView);
    await db.execute(createAlbumsFullView);
    await db.execute(createArtistsFullView);
    await db.execute(createPlaylistTracksFullView);
  }

  /// Drop all views (for recreation)
  static Future<void> dropAll(dynamic db) async {
    await db.execute('DROP VIEW IF EXISTS v_tracks_full');
    await db.execute('DROP VIEW IF EXISTS v_albums_full');
    await db.execute('DROP VIEW IF EXISTS v_artists_full');
    await db.execute('DROP VIEW IF EXISTS v_playlist_tracks_full');
  }
}