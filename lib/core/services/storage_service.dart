import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _plexTokenKey = 'plex_token';
  static const String _usernameKey = 'plex_username';
  static const String _selectedServersKey = 'selected_servers';
  static const String _profileImagePathKey = 'profile_image_path';

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
  }
}
