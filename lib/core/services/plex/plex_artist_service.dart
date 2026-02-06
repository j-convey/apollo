import 'package:flutter/foundation.dart';
import 'plex_api_client.dart';
import '../../models/artist.dart';

/// Service for fetching artist-related data from Plex.
/// Single responsibility: Artist data operations.
class PlexArtistService {
  final PlexApiClient _apiClient = PlexApiClient();

  /// Fetches artist details by artist ID.
  Future<Artist?> getArtistDetails({
    required String artistId,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final url = '$serverUrl/library/metadata/$artistId?X-Plex-Token=$token';
      debugPrint('ARTIST_SERVICE: Fetching artist details from: $url');

      final response = await _apiClient.get(url, token: token);

      if (response.statusCode == 200) {
        final data = _apiClient.decodeJson(response);
        final metadata = data['MediaContainer']?['Metadata'];

        if (metadata != null && metadata.isNotEmpty) {
          return Artist.fromPlexJson(metadata[0]);
        }
      }

      debugPrint('ARTIST_SERVICE: Failed to fetch artist. Status: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('ARTIST_SERVICE: Error fetching artist: $e');
      return null;
    }
  }

  /// Fetches all tracks for an artist (grandchildren).
  /// Returns a list of track data maps.
  Future<List<Map<String, dynamic>>> getArtistTracks({
    required String artistId,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final url =
          '$serverUrl/library/metadata/$artistId/allLeaves?X-Plex-Token=$token';
      debugPrint('ARTIST_SERVICE: Fetching artist tracks from: $url');

      final response = await _apiClient.get(url, token: token);

      if (response.statusCode == 200) {
        final data = _apiClient.decodeJson(response);
        final tracks = data['MediaContainer']?['Metadata'] as List<dynamic>?;

        if (tracks != null) {
          debugPrint('ARTIST_SERVICE: Found ${tracks.length} tracks');
          return tracks.cast<Map<String, dynamic>>();
        }
      }

      debugPrint(
          'ARTIST_SERVICE: Failed to fetch tracks. Status: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('ARTIST_SERVICE: Error fetching tracks: $e');
      return [];
    }
  }

  /// Fetches albums for an artist (children).
  /// Returns a list of album data maps.
  Future<List<Map<String, dynamic>>> getArtistAlbums({
    required String artistId,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final url =
          '$serverUrl/library/metadata/$artistId/children?X-Plex-Token=$token';
      debugPrint('ARTIST_SERVICE: Fetching artist albums from: $url');

      final response = await _apiClient.get(url, token: token);

      if (response.statusCode == 200) {
        final data = _apiClient.decodeJson(response);
        final albums = data['MediaContainer']?['Metadata'] as List<dynamic>?;

        if (albums != null) {
          debugPrint('ARTIST_SERVICE: Found ${albums.length} albums');
          return albums.cast<Map<String, dynamic>>();
        }
      }

      debugPrint(
          'ARTIST_SERVICE: Failed to fetch albums. Status: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('ARTIST_SERVICE: Error fetching albums: $e');
      return [];
    }
  }

  /// Fetches tracks for an album (children of an album).
  /// Returns a list of track data maps.
  Future<List<Map<String, dynamic>>> getAlbumTracks({
    required String albumId,
    required String serverUrl,
    required String token,
  }) async {
    try {
      final url =
          '$serverUrl/library/metadata/$albumId/children?X-Plex-Token=$token';
      debugPrint('ARTIST_SERVICE: Fetching album tracks from: $url');

      final response = await _apiClient.get(url, token: token);

      if (response.statusCode == 200) {
        final data = _apiClient.decodeJson(response);
        final tracks = data['MediaContainer']?['Metadata'] as List<dynamic>?;

        if (tracks != null) {
          debugPrint('ARTIST_SERVICE: Found ${tracks.length} tracks for album');
          return tracks.cast<Map<String, dynamic>>();
        }
      }

      debugPrint(
          'ARTIST_SERVICE: Failed to fetch album tracks. Status: ${response.statusCode}');
      return [];
    } catch (e) {
      debugPrint('ARTIST_SERVICE: Error fetching album tracks: $e');
      return [];
    }
  }

  /// Builds an image URL from a Plex image path.
  String buildImageUrl({
    required String imagePath,
    required String serverUrl,
    required String token,
  }) {
    return '$serverUrl$imagePath?X-Plex-Token=$token';
  }
}
