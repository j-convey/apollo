import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _plexTokenKey = 'plex_token';
  static const String _usernameKey = 'plex_username';
  static const String _selectedServersKey = 'selected_servers';
  static const String _profileImagePathKey = 'profile_image_path';
  static const String _serverUrlKey = 'server_url';
  static const String _serverUrlMapKey = 'server_url_map';

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

  // Get the URL for a specific server by machine identifier
  Future<String?> getServerUrlById(String machineIdentifier) async {
    final urlMap = await getServerUrlMap();
    return urlMap[machineIdentifier];
  }

  // Get the URL for the server that has selected libraries
  Future<String?> getSelectedServerUrl() async {
    final selectedServers = await getSelectedServers();
    final urlMap = await getServerUrlMap();

    // Find the first server with selected libraries
    for (var entry in selectedServers.entries) {
      if (entry.value.isNotEmpty && urlMap.containsKey(entry.key)) {
        return urlMap[entry.key];
      }
    }
    return null;
  }

  // Save selected servers and libraries
  Future<void> saveSelectedServers(Map<String, List<String>> selections) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedServersKey, json.encode(selections));
  }

  // Get selected servers and libraries
  Future<Map<String, List<String>>> getSelectedServers() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_selectedServersKey);
    if (data != null) {
      final Map<String, dynamic> decoded = json.decode(data);
      return decoded.map((key, value) => MapEntry(key, List<String>.from(value)));
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
  }
}
