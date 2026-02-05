import 'package:flutter/foundation.dart';
import 'views.dart';
import 'indexes.dart';

/// Database migration logic
class MigrationSchema {
  /// Current database version
  static const int currentVersion = 10;

  /// Run migrations from oldVersion to newVersion
  static Future<void> migrate(dynamic db, int oldVersion, int newVersion) async {
    debugPrint('DATABASE: Migrating from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      await _migrateToV2(db);
    }

    if (oldVersion < 3) {
      await _migrateToV3(db);
    }

    if (oldVersion < 4) {
      await _migrateToV4(db);
    }

    if (oldVersion < 5) {
      await _migrateToV5(db);
    }

    if (oldVersion < 6) {
      await _migrateToV6(db);
    }

    if (oldVersion < 7) {
      await _migrateToV7(db);
    }

    if (oldVersion < 8) {
      await _migrateToV8(db);
    }

    if (oldVersion < 9) {
      await _migrateToV9(db);
    }

    if (oldVersion < 10) {
      await _migrateToV10(db);
    }

    debugPrint('DATABASE: Migration complete to version $newVersion');
  }

  static Future<void> _migrateToV2(dynamic db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlists(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        summary TEXT,
        type TEXT,
        smart INTEGER,
        composite TEXT,
        duration INTEGER,
        leaf_count INTEGER
      )
    ''');
    debugPrint('DATABASE: Migrated to version 2');
  }

  static Future<void> _migrateToV3(dynamic db) async {
    await _safeAddColumn(db, 'tracks', 'user_rating REAL');
    debugPrint('DATABASE: Migrated to version 3');
  }

  static Future<void> _migrateToV4(dynamic db) async {
    await _safeAddColumn(db, 'tracks', 'rating_key TEXT');
    await _safeAddColumn(db, 'tracks', 'grandparent_rating_key TEXT');
    await _safeAddColumn(db, 'tracks', 'grandparent_title TEXT');
    await _safeAddColumn(db, 'tracks', 'grandparent_thumb TEXT');
    await _safeAddColumn(db, 'tracks', 'grandparent_art TEXT');
    await _safeAddColumn(db, 'tracks', 'parent_title TEXT');
    await _safeAddColumn(db, 'tracks', 'parent_thumb TEXT');
    debugPrint('DATABASE: Migrated to version 4');
  }

  static Future<void> _migrateToV5(dynamic db) async {
    await _safeAddColumn(db, 'tracks', 'parent_rating_key TEXT');
    debugPrint('DATABASE: Migrated to version 5');
  }

  static Future<void> _migrateToV6(dynamic db) async {
    // Create normalized tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS artists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rating_key TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        thumb TEXT,
        art TEXT,
        server_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS albums (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rating_key TEXT UNIQUE NOT NULL,
        title TEXT NOT NULL,
        artist_id INTEGER,
        artist_name TEXT,
        thumb TEXT,
        art TEXT,
        year INTEGER,
        server_id TEXT NOT NULL,
        added_at INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (artist_id) REFERENCES artists(id)
      )
    ''');

    await _safeAddColumn(db, 'tracks', 'artist_id INTEGER');
    await _safeAddColumn(db, 'tracks', 'album_id INTEGER');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlist_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        playlist_id TEXT NOT NULL,
        track_id INTEGER NOT NULL,
        position INTEGER,
        UNIQUE(playlist_id, track_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists(id),
        FOREIGN KEY (track_id) REFERENCES tracks(id)
      )
    ''');

    await _safeAddColumn(db, 'playlists', 'server_id TEXT');
    debugPrint('DATABASE: Migrated to version 6');
  }

  static Future<void> _migrateToV7(dynamic db) async {
    // Enhanced metadata for artists
    await _safeAddColumn(db, 'artists', 'summary TEXT');
    await _safeAddColumn(db, 'artists', 'genre TEXT');
    await _safeAddColumn(db, 'artists', 'country TEXT');
    await _safeAddColumn(db, 'artists', 'added_at INTEGER');
    await _safeAddColumn(db, 'artists', 'updated_at INTEGER');

    // Enhanced metadata for albums
    await _safeAddColumn(db, 'albums', 'genre TEXT');
    await _safeAddColumn(db, 'albums', 'studio TEXT');
    await _safeAddColumn(db, 'albums', 'summary TEXT');
    await _safeAddColumn(db, 'albums', 'track_count INTEGER DEFAULT 0');

    // Enhanced fields for tracks
    await _safeAddColumn(db, 'tracks', 'track_number INTEGER');
    await _safeAddColumn(db, 'tracks', 'disc_number INTEGER DEFAULT 1');
    await _safeAddColumn(db, 'tracks', 'artist_name TEXT');
    await _safeAddColumn(db, 'tracks', 'album_name TEXT');
    await _safeAddColumn(db, 'tracks', 'genre TEXT');

    debugPrint('DATABASE: Migrated to version 7');
  }

  static Future<void> _migrateToV8(dynamic db) async {
    await _safeAddColumn(db, 'albums', 'art TEXT');
    await _safeAddColumn(db, 'tracks', 'grandparent_thumb TEXT');
    debugPrint('DATABASE: Migrated to version 8');
  }

  static Future<void> _migrateToV9(dynamic db) async {
    // Ensure all required columns exist before creating indexes
    // This handles edge cases where earlier migrations may not have run
    await _safeAddColumn(db, 'tracks', 'parent_rating_key TEXT');
    await _safeAddColumn(db, 'tracks', 'grandparent_rating_key TEXT');
    await _safeAddColumn(db, 'tracks', 'disc_number INTEGER DEFAULT 1');
    await _safeAddColumn(db, 'tracks', 'track_number INTEGER');
    await _safeAddColumn(db, 'tracks', 'artist_id INTEGER');
    await _safeAddColumn(db, 'tracks', 'album_id INTEGER');
    await _safeAddColumn(db, 'tracks', 'added_at INTEGER');
    await _safeAddColumn(db, 'tracks', 'user_rating REAL');
    
    // Create SQL views for optimized queries
    await ViewSchema.dropAll(db);
    await ViewSchema.createAll(db);
    
    // Create optimized indexes (each wrapped in try-catch)
    await IndexSchema.createAll(db);
    
    debugPrint('DATABASE: Migrated to version 9 - Added views and indexes');
  }

  static Future<void> _migrateToV10(dynamic db) async {
    // Add UNIQUE constraint on tracks.rating_key for Plex API integration
    // This ensures each track from Plex is only stored once, and allows
    // direct queries to Plex API using rating_key without joining through albums
    try {
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_tracks_rating_key ON tracks(rating_key)');
      debugPrint('DATABASE: Migrated to version 10 - Added rating_key uniqueness for Plex integration');
    } catch (e) {
      debugPrint('DATABASE: Note - rating_key index may already exist: $e');
    }
  }

  /// Safely add a column (ignores error if column exists)
  static Future<void> _safeAddColumn(dynamic db, String table, String columnDef) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef');
    } catch (e) {
      // Column already exists, ignore
    }
  }
}