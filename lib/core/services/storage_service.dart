import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _plexTokenKey = 'plex_token';
  static const String _usernameKey = 'plex_username';
  static const String _selectedServersKey =
      'selected_servers'; // Legacy - kept for migration
  static const String _profileImagePathKey = 'profile_image_path';
  static const String _serverUrlKey = 'server_url'; // Legacy
  static const String _serverUrlMapKey = 'server_url_map'; // Legacy
  static const String _selectedServerKey = 'selected_server_id';
  static const String _selectedLibraryKey = 'selected_library_key';
  static const String _selectedServerUrlKey = 'selected_server_url';

  // Save Plex token
  Future<void> savePlexToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plexTokenKey, token);
  }

  // Get Plex token
  Future<String?> getPlexToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_plexTokenKey);
  }

  // Save username
  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, username);
  }

  // Get username
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  // Save profile image path
  Future<void> saveProfileImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImagePathKey, path);
  }

  // Get profile image path
  Future<String?> getProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_profileImagePathKey);
  }

  // Save server URL (legacy - kept for backward compatibility)
  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
  }

  // Get server URL (legacy - kept for backward compatibility)
  Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  // Save server URL map (machineIdentifier -> URL)
  Future<void> saveServerUrlMap(Map<String, String> urlMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlMapKey, json.encode(urlMap));
  }

  // Get server URL map (machineIdentifier -> URL)
  Future<Map<String, String>> getServerUrlMap() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_serverUrlMapKey);
    if (data != null) {
      final Map<String, dynamic> decoded = json.decode(data);
      return decoded.map((key, value) => MapEntry(key, value as String));
    }
    return {};
  }

  // Get the URL for a specific server by machine identifier (legacy)
  Future<String?> getServerUrlById(String machineIdentifier) async {
    final urlMap = await getServerUrlMap();
    return urlMap[machineIdentifier];
  }

  // ==================== NEW SINGLE SELECTION METHODS ====================

  // Save selected server ID (single selection)
  Future<void> saveSelectedServer(String serverId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedServerKey, serverId);
  }

  // Get selected server ID (single selection)
  Future<String?> getSelectedServer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedServerKey);
  }

  // Save selected library key (single selection)
  Future<void> saveSelectedLibrary(String libraryKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedLibraryKey, libraryKey);
  }

  // Get selected library key (single selection)
  Future<String?> getSelectedLibrary() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedLibraryKey);
  }

  // Save the selected server's URL (only set when user explicitly saves)
  Future<void> saveSelectedServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedServerUrlKey, url);
  }

  // Get the URL for the selected server (returns null if not yet saved)
  Future<String?> getSelectedServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedServerUrlKey);
  }

  // ==================== LEGACY METHODS (kept for backward compatibility) ====================

  // Save selected servers and libraries (legacy - multi-select)
  Future<void> saveSelectedServers(Map<String, List<String>> selections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedServersKey, json.encode(selections));
  }

  // Get selected servers and libraries (legacy - multi-select)
  Future<Map<String, List<String>>> getSelectedServers() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_selectedServersKey);
    if (data != null) {
      final Map<String, dynamic> decoded = json.decode(data);
      return decoded.map(
        (key, value) => MapEntry(key, List<String>.from(value)),
      );
    }
    return {};
  }

  // Clear all Plex credentials
  Future<void> clearPlexCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_plexTokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_selectedServersKey);
    await prefs.remove(_serverUrlMapKey);
    await prefs.remove(_selectedServerKey);
    await prefs.remove(_selectedLibraryKey);
    await prefs.remove(_selectedServerUrlKey);
  }
}
