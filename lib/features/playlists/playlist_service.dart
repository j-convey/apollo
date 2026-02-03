// c:\Users\jordan.convey\Documents\vscode\apollo\lib\features\playlists\services\playlist_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../../core/models/playlists.dart';
import '../../../core/database/database_service.dart';

class PlaylistService {
  final DatabaseService _dbService = DatabaseService();

  /// Fetches playlists from Plex API and syncs them to the local database.
  /// Returns the list of updated playlists.
  Future<List<Playlist>> syncPlaylists(String serverUrl, String token) async {
    try {
      // 1. Fetch from API
      final uri = Uri.parse('$serverUrl/playlists').replace(queryParameters: {
        'X-Plex-Token': token,
        'playlistType': 'audio', // Filter for audio playlists if desired
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> metadata = data['MediaContainer']['Metadata'] ?? [];

        final List<Playlist> playlists = metadata
            .map((json) => Playlist.fromPlexJson(json))
            .toList();

        // 2. Save to Database
        await _savePlaylistsToDb(playlists);
        
        return playlists;
      } else {
        debugPrint('Failed to fetch playlists: ${response.statusCode}');
        // If API fails, try to return local data
        return await getLocalPlaylists();
      }
    } catch (e) {
      debugPrint('Error syncing playlists: $e');
      return await getLocalPlaylists();
    }
  }

  /// Retrieves playlists currently stored in the local database.
  Future<List<Playlist>> getLocalPlaylists() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query('playlists');
    return maps.map((map) => Playlist.fromMap(map)).toList();
  }

  /// Helper to batch insert/update playlists
  Future<void> _savePlaylistsToDb(List<Playlist> playlists) async {
    final db = await _dbService.database;
    final batch = db.batch();

    // Optional: Clear old playlists if you want a full sync
    // batch.delete('playlists'); 

    for (var playlist in playlists) {
      batch.insert(
        'playlists',
        playlist.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }
}
