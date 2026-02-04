library;

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

part 'tables/schema.dart';
part 'tables/tracks_extension.dart';
part 'tables/playlists_extension.dart';
part 'tables/artists_extension.dart';
part 'tables/albums_extension.dart';

class DatabaseService {
  static Database? _database;
  
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'apollo_music.db');

    return await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ============================================================
  // SHARED HELPER METHODS - Used by all extensions
  // ============================================================

  /// Parse media data JSON string back to list
  List<dynamic> _parseMediaData(String mediaData) {
    try {
      if (mediaData.isEmpty) return [];
      final decoded = jsonDecode(mediaData);
      return decoded is List ? decoded : [];
    } catch (e) {
      debugPrint('DATABASE: Error parsing media data: $e');
      return [];
    }
  }

  /// Map a database row to the standard track format used by the app.
  /// This is the single source of truth for track mapping.
  Map<String, dynamic> mapTrackFromDb(Map<String, dynamic> map) {
    // Prefer normalized joined data, fall back to denormalized columns, then stored names
    final albumName = (map['album_name'] as String?) ?? 
                      (map['parent_title'] as String?) ?? 
                      (map['album_name_stored'] as String?) ??
                      'Unknown Album';
    final artistName = (map['artist_name'] as String?) ?? 
                       (map['grandparent_title'] as String?) ?? 
                       (map['artist_name_stored'] as String?) ??
                       'Unknown Artist';
    final albumThumb = (map['album_thumb'] as String?) ?? 
                       (map['parent_thumb'] as String?);
    final artistThumb = (map['artist_thumb'] as String?) ?? 
                        (map['grandparent_thumb'] as String?);
    final albumRatingKey = (map['album_rating_key'] as String?) ?? 
                           (map['parent_rating_key'] as String?);
    final artistRatingKey = (map['artist_rating_key'] as String?) ?? 
                            (map['grandparent_rating_key'] as String?);
    
    return {
      'id': map['id'] as int?,
      'title': map['title'] as String,
      'artist': artistName,
      'album': albumName,
      'duration': map['duration'] as int? ?? 0,
      'key': map['track_key'] as String,
      'thumb': map['thumb'] as String?,
      'year': map['year'] as int?,
      'addedAt': map['added_at'] as int?,
      'serverId': map['server_id'] as String,
      'libraryKey': map['library_key'] as String,
      'Media': _parseMediaData(map['media_data'] as String? ?? ''),
      'userRating': map['user_rating'] as double?,
      // Track ordering
      'trackNumber': map['track_number'] as int?,
      'discNumber': map['disc_number'] as int? ?? 1,
      // Track rating key for identification
      'ratingKey': map['rating_key'] as String?,
      // Artist info
      'grandparentRatingKey': artistRatingKey,
      'grandparentTitle': artistName,
      'grandparentThumb': artistThumb,
      // Album info
      'parentRatingKey': albumRatingKey,
      'parentTitle': albumName,
      'parentThumb': albumThumb,
    };
  }

  /// Map a database row to the standard artist format used by the app.
  Map<String, dynamic> mapArtistFromDb(Map<String, dynamic> map) {
    return {
      'id': map['id'] as int?,
      'artistId': map['id'].toString(), // Also provide as string for UI
      'ratingKey': map['rating_key'] as String?,
      'title': map['title'] as String,
      'artistName': map['title'] as String, // Alias for UI
      'thumb': map['thumb'] as String?,
      'artistThumb': map['thumb'] as String?, // Alias for UI
      'art': map['art'] as String?,
      'summary': map['summary'] as String?,
      'genre': map['genre'] as String?,
      'country': map['country'] as String?,
      'serverId': map['server_id'] as String,
      'addedAt': map['added_at'] as int?,
      'albumCount': map['album_count'] as int? ?? 0,
      'trackCount': map['track_count'] as int? ?? 0,
    };
  }

  /// Map a database row to the standard album format used by the app.
  Map<String, dynamic> mapAlbumFromDb(Map<String, dynamic> map) {
    return {
      'id': map['id'] as int?,
      'ratingKey': map['rating_key'] as String?,
      'title': map['title'] as String,
      'artistId': map['artist_id'] as int?,
      'artistName': (map['artist_name'] as String?) ?? 
                    (map['artist_title'] as String?) ?? 
                    'Unknown Artist',
      'artistRatingKey': map['artist_rating_key'] as String?,
      'thumb': map['thumb'] as String?,
      'art': map['art'] as String?,
      'year': map['year'] as int?,
      'genre': map['genre'] as String?,
      'studio': map['studio'] as String?,
      'summary': map['summary'] as String?,
      'trackCount': map['track_count'] as int? ?? 0,
      'serverId': map['server_id'] as String,
      'addedAt': map['added_at'] as int?,
    };
  }
}
