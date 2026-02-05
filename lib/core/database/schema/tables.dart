/// SQL statements for creating tables
class TableSchema {
  static const String createArtists = '''
    CREATE TABLE artists (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rating_key TEXT UNIQUE NOT NULL,
      title TEXT NOT NULL,
      thumb TEXT,
      art TEXT,
      summary TEXT,
      genre TEXT,
      country TEXT,
      server_id TEXT NOT NULL,
      added_at INTEGER,
      updated_at INTEGER
    )
  ''';

  static const String createAlbums = '''
    CREATE TABLE albums (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rating_key TEXT UNIQUE NOT NULL,
      title TEXT NOT NULL,
      artist_id INTEGER,
      artist_name TEXT,
      thumb TEXT,
      art TEXT,
      year INTEGER,
      genre TEXT,
      studio TEXT,
      summary TEXT,
      track_count INTEGER DEFAULT 0,
      server_id TEXT NOT NULL,
      added_at INTEGER,
      updated_at INTEGER,
      FOREIGN KEY (artist_id) REFERENCES artists(id) ON DELETE SET NULL
    )
  ''';

  static const String createTracks = '''
    CREATE TABLE tracks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      rating_key TEXT UNIQUE NOT NULL,
      server_id TEXT NOT NULL,
      library_key TEXT NOT NULL,
      track_key TEXT NOT NULL,
      title TEXT NOT NULL,
      artist_id INTEGER,
      artist_name TEXT,
      album_id INTEGER,
      album_name TEXT,
      track_number INTEGER,
      disc_number INTEGER DEFAULT 1,
      duration INTEGER,
      thumb TEXT,
      year INTEGER,
      genre TEXT,
      added_at INTEGER,
      media_data TEXT,
      user_rating REAL,
      parent_rating_key TEXT,
      parent_thumb TEXT,
      grandparent_rating_key TEXT,
      grandparent_thumb TEXT,
      UNIQUE(server_id, track_key),
      FOREIGN KEY (artist_id) REFERENCES artists(id) ON DELETE SET NULL,
      FOREIGN KEY (album_id) REFERENCES albums(id) ON DELETE SET NULL
    )
  ''';

  static const String createSyncMetadata = '''
    CREATE TABLE sync_metadata (
      server_id TEXT PRIMARY KEY,
      library_key TEXT NOT NULL,
      last_sync INTEGER NOT NULL,
      track_count INTEGER NOT NULL
    )
  ''';

  static const String createPlaylists = '''
    CREATE TABLE playlists (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      summary TEXT,
      type TEXT,
      smart INTEGER,
      composite TEXT,
      duration INTEGER,
      leaf_count INTEGER,
      server_id TEXT NOT NULL
    )
  ''';

  static const String createPlaylistTracks = '''
    CREATE TABLE playlist_tracks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      playlist_id TEXT NOT NULL,
      track_id INTEGER NOT NULL,
      position INTEGER,
      UNIQUE(playlist_id, track_id),
      FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
      FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
    )
  ''';

  /// Execute all table creation statements
  static Future<void> createAll(dynamic db) async {
    await db.execute(createArtists);
    await db.execute(createAlbums);
    await db.execute(createTracks);
    await db.execute(createSyncMetadata);
    await db.execute(createPlaylists);
    await db.execute(createPlaylistTracks);
  }
}