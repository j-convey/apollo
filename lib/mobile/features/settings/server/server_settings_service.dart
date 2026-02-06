import 'package:flutter/material.dart';
import 'package:apollo/core/services/plex/plex_services.dart';
import 'package:apollo/core/services/storage_service.dart';
import 'package:apollo/core/database/database_service.dart';
import 'package:apollo/core/models/track.dart';

/// Service class handling all server settings business logic
class ServerSettingsService {
  final PlexAuthService authService = PlexAuthService();
  final PlexServerService serverService = PlexServerService();
  final PlexLibraryService libraryService = PlexLibraryService();
  final StorageService storageService = StorageService();
  final DatabaseService dbService = DatabaseService();

  Future<bool> validateToken(String token) async {
    return await authService.validateToken(token);
  }

  Future<void> clearCredentials() async {
    await storageService.clearPlexCredentials();
  }

  Future<Map<String, dynamic>> signIn() async {
    return await authService.signIn();
  }

  Future<void> saveCredentials(String token, String? username) async {
    await storageService.savePlexToken(token);
    if (username != null) {
      await storageService.saveUsername(username);
    }
  }

  Future<String?> getPlexToken() async {
    return await storageService.getPlexToken();
  }

  Future<String?> getUsername() async {
    return await storageService.getUsername();
  }

  Future<Map<String, dynamic>?> loadSyncStatus() async {
    try {
      final syncMetadata = await dbService.tracks.getAllSyncMetadata();
      final trackCount = await dbService.tracks.getCount();
      
      if (syncMetadata.isNotEmpty) {
        final lastSync = syncMetadata.first['last_sync'] as int;
        final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
        
        return {
          'trackCount': trackCount,
          'lastSync': lastSyncDate,
        };
      }
    } catch (e) {
      debugPrint('Error loading sync status: $e');
    }
    return null;
  }

  Future<List<PlexServer>> getServers(String token) async {
    return await serverService.getServers(token);
  }

  Future<List<Map<String, dynamic>>> getLibrariesForServer(
    String token,
    PlexServer server,
  ) async {
    final serverUrl = serverService.getBestConnectionUrlForServer(server);
    
    if (serverUrl != null) {
      try {
        final libraries = await libraryService.getLibraries(token, serverUrl);
        final musicLibraries = libraries.where((l) => l.isMusicLibrary).toList();
        return musicLibraries.map((l) => l.toJson()).toList();
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<Map<String, List<String>>> getSelectedServers() async {
    return await storageService.getSelectedServers();
  }

  Future<void> saveSelections(Map<String, Set<String>> selectedLibraries) async {
    final selections = selectedLibraries.map(
      (key, value) => MapEntry(key, value.toList())
    );
    await storageService.saveSelectedServers(selections);
    await _saveServerUrlMap(selectedLibraries.keys.toList());
  }

  Future<void> _saveServerUrlMap(List<String> serverIds) async {
    // This would need to be called with servers, so we'll handle it differently
  }

  Future<void> syncLibrary(
    List<PlexServer> servers,
    Map<String, List<Map<String, dynamic>>> serverLibraries,
    Function(String) onLibraryChange,
    Function(double) onProgressChange,
    Function(int) onTracksSyncedChange,
  ) async {
    try {
      final token = await storageService.getPlexToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final selectedServers = await storageService.getSelectedServers();
      if (selectedServers.isEmpty) {
        throw Exception('No libraries selected');
      }

      int totalLibraries = 0;
      for (var server in servers) {
        final libraryKeys = selectedServers[server.machineIdentifier];
        if (libraryKeys != null && libraryKeys.isNotEmpty) {
          totalLibraries += libraryKeys.length;
        }
      }

      int totalTracks = 0;
      int librariesCompleted = 0;
      
      for (var server in servers) {
        final libraryKeys = selectedServers[server.machineIdentifier];
        
        if (libraryKeys != null && libraryKeys.isNotEmpty) {
          final serverUrl = serverService.getBestConnectionUrlForServer(server);
          
          if (serverUrl != null) {
            for (var libraryKey in libraryKeys) {
              final libraryInfo = serverLibraries[server.machineIdentifier]
                  ?.firstWhere(
                    (lib) => lib['key'] == libraryKey,
                    orElse: () => {'title': 'Library $libraryKey'},
                  );
              final libraryTitle = libraryInfo?['title'] as String? ?? 'Library $libraryKey';
              
              onLibraryChange('$libraryTitle (fetching...)');

              debugPrint('Fetching library $libraryKey from server ${server.machineIdentifier}...');
              
              final tracks = await libraryService.getTracks(token, serverUrl, libraryKey);
              
              onLibraryChange('$libraryTitle (saving...)');
              
              debugPrint('Saving ${tracks.length} tracks from library $libraryKey...');
              
              // Convert maps to Track objects
              final trackObjects = tracks
                  .map((trackData) => Track.fromPlexJson(
                        trackData,
                        serverId: server.machineIdentifier,
                        libraryKey: libraryKey,
                      ))
                  .toList();
              
              await dbService.tracks.saveAll(
                server.machineIdentifier,
                libraryKey,
                trackObjects,
                onProgress: (current, total) {
                  onLibraryChange('$libraryTitle (saving $current/$total)');
                },
              );
              
              totalTracks += tracks.length;
              librariesCompleted++;
              
              onProgressChange(librariesCompleted / totalLibraries);
              onTracksSyncedChange(totalTracks);
              
              debugPrint('Completed ${tracks.length} tracks from library $libraryKey');
            }
          }
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  String formatSyncDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }

  Future<void> saveServerUrlMap(List<PlexServer> servers) async {
    final Map<String, String> urlMap = {};
    
    for (var server in servers) {
      final serverUrl = serverService.getBestConnectionUrlForServer(server);
      if (serverUrl != null) {
        urlMap[server.machineIdentifier] = serverUrl;
        debugPrint('Saving server URL: ${server.machineIdentifier} -> $serverUrl');
      }
    }
    
    await storageService.saveServerUrlMap(urlMap);
    debugPrint('Saved ${urlMap.length} server URLs to storage');
  }
}
