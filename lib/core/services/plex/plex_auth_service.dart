import 'package:url_launcher/url_launcher.dart';
import 'plex_api_client.dart';
import 'plex_constants.dart';

/// Handles Plex authentication operations.
/// Single responsibility: User authentication and token management.
class PlexAuthService {
  final PlexApiClient _apiClient = PlexApiClient();

  /// Signs in the user via Plex OAuth flow.
  /// Returns a map with 'success', 'token', and 'username' on success.
  Future<Map<String, dynamic>> signIn() async {
    try {
      final pinData = await _generatePin();
      final pinId = pinData['id'];
      final pinCode = pinData['code'];

      final authUrl = _buildAuthUrl(pinCode);

      if (await canLaunchUrl(authUrl)) {
        await launchUrl(authUrl, mode: LaunchMode.externalApplication);
      } else {
        return _errorResult('Could not launch authentication URL');
      }

      // Poll for authentication (check every 2 seconds for up to 5 minutes)
      for (int i = 0; i < 150; i++) {
        await Future.delayed(const Duration(seconds: 2));

        final result = await _checkPin(pinId);
        if (result != null && result['authToken'] != null) {
          final token = result['authToken'];
          final userInfo = await getUserInfo(token);

          return {
            'success': true,
            'token': token,
            'username': userInfo?['username'] ?? userInfo?['email'],
          };
        }
      }

      return _errorResult('Authentication timeout - please try again');
    } catch (e) {
      return _errorResult(e.toString());
    }
  }

  /// Validates if a token is still valid.
  Future<bool> validateToken(String token) async {
    try {
      final response = await _apiClient.get(
        '${PlexConstants.plexApiUrl}/api/v2/user',
        token: token,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Gets user info from a token.
  Future<Map<String, dynamic>?> getUserInfo(String token) async {
    try {
      final response = await _apiClient.get(
        '${PlexConstants.plexApiUrl}/api/v2/user',
        token: token,
      );

      if (response.statusCode == 200) {
        return _apiClient.decodeJson(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generates a PIN for authentication.
  Future<Map<String, dynamic>> _generatePin() async {
    final response = await _apiClient.post(
      '${PlexConstants.plexApiUrl}/api/v2/pins?strong=true',
    );

    if (response.statusCode == 201) {
      return _apiClient.decodeJson(response);
    } else {
      throw Exception('Failed to generate PIN: ${response.statusCode}');
    }
  }

  /// Checks the PIN status.
  Future<Map<String, dynamic>?> _checkPin(int pinId) async {
    try {
      final response = await _apiClient.get(
        '${PlexConstants.plexApiUrl}/api/v2/pins/$pinId',
      );

      if (response.statusCode == 200) {
        final data = _apiClient.decodeJson(response);
        if (data['authToken'] != null) {
          return data;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Builds the authentication URL.
  Uri _buildAuthUrl(String pinCode) {
    final params = Uri(queryParameters: {
      'clientID': PlexConstants.clientIdentifier,
      'code': pinCode,
      'context[device][product]': PlexConstants.productName,
    }).query;
    return Uri.parse('${PlexConstants.plexAuthUrl}/auth#?$params');
  }

  /// Creates an error result map.
  Map<String, dynamic> _errorResult(String error) {
    return {'success': false, 'error': error};
  }
}
