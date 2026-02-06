import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

import 'schema/tables.dart';
import 'schema/views.dart';
import 'schema/indexes.dart';
import 'schema/migrations.dart';
import 'repositories/artist_repository.dart';
import 'repositories/album_repository.dart';
import 'repositories/track_repository.dart';
import 'repositories/playlist_repository.dart';
import '../models/track.dart';
import '../models/playlist.dart';

/// Central database service providing access to all repositories.
/// 
/// Usage:
/// ```dart
/// final db = DatabaseService();
/// 
/// // Get all artists with their albums
/// final artists = await db.artists.getAll();
/// 
/// // Get an album with its tracks
/// final album = await db.albums.getWithTracks('12345');
/// 
/// // Get tracks for a library
/// final tracks = await db.tracks.getByLibrary(serverId, libraryKey);
/// ```
class DatabaseService {
  static Database? _database;
  
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // ============================================================
  // REPOSITORIES - Accessed via getters for lazy initialization
  // ============================================================

  ArtistRepository? _artistRepository;
  AlbumRepository? _albumRepository;
  TrackRepository? _trackRepository;
  PlaylistRepository? _playlistRepository;

  /// Artist repository
  ArtistRepository get artists {
    _artistRepository ??= ArtistRepository(() => database);
    return _artistRepository!;
  }

  /// Album repository
  AlbumRepository get albums {
    _albumRepository ??= AlbumRepository(() => database);
    return _albumRepository!;
  }

  /// Track repository
  TrackRepository get tracks {
    _trackRepository ??= TrackRepository(() => database);
    return _trackRepository!;
  }

  /// Playlist repository
  PlaylistRepository get playlists {
    _playlistRepository ??= PlaylistRepository(() => database);
    return _playlistRepository!;
  }

  // ============================================================
  // DATABASE INITIALIZATION
  // ============================================================

  /// Get the database instance (initializes if needed)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms
    // On Android/iOS, sqflite works natively without FFI
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'apollo_music.db');

    return await openDatabase(
      path,
      version: MigrationSchema.currentVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('DATABASE: Creating new database with version $version');
    
    // Create tables
    await TableSchema.createAll(db);
    
    // Create views
    await ViewSchema.createAll(db);
    
    // Create indexes
    await IndexSchema.createAll(db);
    
    debugPrint('DATABASE: Database created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await MigrationSchema.migrate(db, oldVersion, newVersion);
  }

  // ============================================================
  // UTILITY METHODS
  // ============================================================

  /// Close the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Clear all data from the database
  Future<void> clearAllData() async {
    await tracks.clearAll();
    await albums.clearAll();
    await artists.clearAll();
    await playlists.clearAll();
    debugPrint('DATABASE: All data cleared');
  }

  /// Recreate views (useful after schema changes)
  Future<void> recreateViews() async {
    final db = await database;
    await ViewSchema.dropAll(db);
    await ViewSchema.createAll(db);
    debugPrint('DATABASE: Views recreated');
  }

  // ============================================================
  // BACKWARD COMPATIBILITY - Deprecated methods
  // Maps to new repository pattern
  // ============================================================

  @Deprecated('Use db.artists.getAll() instead')
  Future<List<Map<String, dynamic>>> getAllArtists() async {
    final results = await artists.getAll();
    return results.map((a) => a.toJson()).toList();
  }

  @Deprecated('Use db.albums.getAll() instead')
  Future<List<Map<String, dynamic>>> getAllAlbums() async {
    final results = await albums.getAll();
    return results.map((a) => a.toJson()).toList();
  }

  @Deprecated('Use db.tracks.getAll() instead')
  Future<List<Map<String, dynamic>>> getAllTracks() async {
    final results = await tracks.getAll();
    return results.map((t) => t.toJson()).toList();
  }

  @Deprecated('Use db.albums.getByRatingKey(ratingKey) instead')
  Future<Map<String, dynamic>?> getAlbum(String ratingKey) async {
    final result = await albums.getByRatingKey(ratingKey);
    return result?.toJson();
  }

  @Deprecated('Use db.tracks.getByAlbum(albumRatingKey) instead')
  Future<List<Map<String, dynamic>>> getTracksForAlbum(String albumRatingKey) async {
    final results = await tracks.getByAlbum(albumRatingKey);
    return results.map((t) => t.toJson()).toList();
  }

  @Deprecated('Use db.artists.getByRatingKey(ratingKey) instead')
  Future<Map<String, dynamic>?> getArtist(String ratingKey) async {
    final result = await artists.getByRatingKey(ratingKey);
    return result?.toJson();
  }

  @Deprecated('Use db.albums.getByArtist(artistRatingKey) instead')
  Future<List<Map<String, dynamic>>> getAlbumsByArtist(String artistRatingKey) async {
    final results = await albums.getByArtist(artistRatingKey);
    return results.map((a) => a.toJson()).toList();
  }

  @Deprecated('Use db.tracks.getByArtist(artistRatingKey) instead')
  Future<List<Map<String, dynamic>>> getTracksByArtist(String artistRatingKey) async {
    final results = await tracks.getByArtist(artistRatingKey);
    return results.map((t) => t.toJson()).toList();
  }

  @Deprecated('Use db.playlists.getAll() instead')
  Future<List<Map<String, dynamic>>> getAllPlaylists() async {
    final results = await playlists.getAll();
    return results.map((p) => p.toJson()).toList();
  }

  @Deprecated('Use db.playlists.getTracks(playlistId) instead')
  Future<List<Map<String, dynamic>>> getPlaylistTracks(String playlistId) async {
    final results = await playlists.getTracks(playlistId);
    return results.map((t) => t.toJson()).toList();
  }

  // ============================================================
  // ADDITIONAL BACKWARD COMPATIBILITY METHODS
  // ============================================================

  @Deprecated('Use db.tracks.getAllSyncMetadata() instead')
  Future<List<Map<String, dynamic>>> getAllSyncMetadata() async {
    return tracks.getAllSyncMetadata();
  }

  @Deprecated('Use db.tracks.getCount() instead')
  Future<int> getTrackCount() async {
    return tracks.getCount();
  }

  @Deprecated('Use db.tracks.saveAll() instead')
  Future<void> saveTracks(
    String serverId,
    String libraryKey,
    List<Map<String, dynamic>> trackMaps, {
    void Function(int current, int total)? onProgress,
  }) async {
    // Convert maps to Track models
    final trackModels = trackMaps.map((map) {
      return Track.fromPlexJson(
        map,
        serverId: serverId,
        libraryKey: libraryKey,
      );
    }).toList();
    await tracks.saveAll(serverId, libraryKey, trackModels, onProgress: onProgress);
  }

  @Deprecated('Use db.tracks.search(query) instead')
  Future<List<Map<String, dynamic>>> searchTracks(String query) async {
    final results = await tracks.search(query);
    return results.map((t) => t.toJson()).toList();
  }

  @Deprecated('Use db.artists.search(query) instead')
  Future<List<Map<String, dynamic>>> searchArtists(String query) async {
    final results = await artists.search(query);
    return results.map((a) => a.toJson()).toList();
  }

  @Deprecated('Use db.playlists.saveAll() instead')
  Future<void> savePlaylists(List<Map<String, dynamic>> playlistMaps, String serverId) async {
    final playlistModels = playlistMaps.map((map) {
      return Playlist.fromDb({
        ...map,
        'server_id': serverId,
      });
    }).toList();
    await playlists.saveAll(playlistModels);
  }
}