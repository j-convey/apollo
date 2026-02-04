/// Legacy file for backward compatibility.
/// All Plex services have been refactored into separate files in the 'plex/' folder.
/// 
/// This file provides a compatibility layer that combines all services into
/// a single PlexAuthService class to minimize breaking changes.

import 'plex/plex_services.dart';
import 'plex/plex_auth_service.dart' as plex_auth;

export 'plex/plex_services.dart';

/// Combined Plex service for backward compatibility.
/// New code should use the individual services directly:
/// - PlexAuthService for authentication
/// - PlexServerService for server/connection management
/// - PlexLibraryService for library operations
class PlexAuthService {
  final plex_auth.PlexAuthService _authService = plex_auth.PlexAuthService();
  final PlexServerService _serverService = PlexServerService();
  final PlexLibraryService _libraryService = PlexLibraryService();

  /// Signs in the user via Plex OAuth flow.
  Future<Map<String, dynamic>> signIn() => _authService.signIn();

  /// Validates if a token is still valid.
  Future<bool> validateToken(String token) => _authService.validateToken(token);

  /// Gets user info from a token.
  Future<Map<String, dynamic>?> getUserInfo(String token) =>
      _authService.getUserInfo(token);

  /// Fetches all owned Plex servers.
  Future<List<Map<String, dynamic>>> getServers(String token) async {
    final servers = await _serverService.getServers(token);
    return servers.map((s) => s.toJson()).toList();
  }

  /// Gets the best connection URL for a server (legacy method).
  String? getBestConnectionUrl(List<dynamic> connections) {
    final plexConnections = connections
        .map((c) => PlexConnection.fromJson(c as Map<String, dynamic>))
        .toList();
    return _serverService.getBestConnectionUrl(plexConnections);
  }

  /// Fetches music libraries from a server.
  Future<List<Map<String, dynamic>>> getLibraries(
      String token, String serverUrl) async {
    final libraries = await _libraryService.getMusicLibraries(token, serverUrl);
    return libraries.map((l) => l.toJson()).toList();
  }

  /// Fetches all tracks from a library.
  Future<List<Map<String, dynamic>>> getTracks(
    String token,
    String serverUrl,
    String libraryKey,
  ) {
    return _libraryService.getTracks(token, serverUrl, libraryKey);
  }
}
