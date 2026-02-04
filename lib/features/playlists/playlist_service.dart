import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../core/models/playlists.dart';
import '../../core/database/database_service.dart';

/// Service for managing playlists.
/// Single responsibility: Playlist synchronization and local storage.
class PlaylistService {
  final DatabaseService _dbService = DatabaseService();

  /// Fetches playlists from Plex API and syncs them to the local database.
  Future<List<Playlist>> syncPlaylists(String serverUrl, String token) async {
    try {
      final playlists = await _fetchPlaylistsFromApi(serverUrl, token);
      await _savePlaylistsToDb(playlists);
      return playlists;
    } catch (e) {
      debugPrint('PLAYLIST SERVICE: Error syncing playlists: $e');
      return await getLocalPlaylists();
    }
  }

  /// Fetches tracks for a specific playlist from the Plex API.
  Future<List<Map<String, dynamic>>> getPlaylistTracks(
    String serverUrl,
    String token,
    String playlistId,
  ) async {
    try {
      final uri = Uri.parse('$serverUrl/playlists/$playlistId/items').replace(
        queryParameters: {
          'X-Plex-Token': token,
        },
      );

      debugPrint('PLAYLIST SERVICE: Fetching tracks for playlist $playlistId');

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch playlist tracks: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      final container = data['MediaContainer'];
      final List<dynamic> metadata = container?['Metadata'] ?? [];

      debugPrint('PLAYLIST SERVICE: Found ${metadata.length} tracks in playlist');

      // Convert Plex track format to our standard track format
      // IMPORTANT: Preserve the full Media structure for audio playback
      return metadata.map((trackJson) {
        return {
          'id': trackJson['ratingKey']?.toString() ?? '',
          'title': trackJson['title'] ?? 'Unknown',
          'artist': trackJson['grandparentTitle'] ?? trackJson['originalTitle'] ?? 'Unknown Artist',
          'album': trackJson['parentTitle'] ?? 'Unknown Album',
          'duration': trackJson['duration'] ?? 0,
          'thumb': trackJson['thumb'],
          'parentThumb': trackJson['parentThumb'],
          'grandparentThumb': trackJson['grandparentThumb'],
          'grandparentRatingKey': trackJson['grandparentRatingKey'],
          'parentRatingKey': trackJson['parentRatingKey'],
          'ratingKey': trackJson['ratingKey'],
          'key': trackJson['key'],
          'addedAt': trackJson['addedAt'],
          'Media': trackJson['Media'], // Preserve full Media structure for audio player
          'serverId': null, // Will be set by the caller if needed
        };
      }).toList();
    } catch (e) {
      debugPrint('PLAYLIST SERVICE: Error fetching playlist tracks: $e');
      rethrow;
    }
  }

  /// Fetches playlists from the Plex API.
  Future<List<Playlist>> _fetchPlaylistsFromApi(String serverUrl, String token) async {
    final uri = Uri.parse('$serverUrl/playlists').replace(queryParameters: {
      'X-Plex-Token': token,
      'playlistType': 'audio',
    });

    debugPrint('PLAYLIST SERVICE: Fetching playlists from $serverUrl');
    
    final response = await http.get(
      uri,
      headers: {'Accept': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch playlists: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final container = data['MediaContainer'];
    final List<dynamic> metadata = container?['Metadata'] ?? [];

    debugPrint('PLAYLIST SERVICE: Found ${metadata.length} playlists');

    return metadata.map((json) => Playlist.fromPlexJson(json)).toList();
  }

  /// Retrieves playlists from the local database.
  Future<List<Playlist>> getLocalPlaylists() async {
    final maps = await _dbService.getAllPlaylists();
    return maps.map((map) => Playlist.fromMap(map)).toList();
  }

  /// Saves playlists to the local database.
  Future<void> _savePlaylistsToDb(List<Playlist> playlists) async {
    final playlistMaps = playlists.map((p) => p.toMap()).toList();
    await _dbService.savePlaylists(playlistMaps);
  }
}
