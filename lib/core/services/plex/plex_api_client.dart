import 'dart:convert';
import 'package:http/http.dart' as http;
import 'plex_constants.dart';

/// Low-level HTTP client for Plex API requests.
/// Single responsibility: Making HTTP requests with proper headers.
class PlexApiClient {
  /// Makes a GET request to the Plex API with standard headers.
  Future<http.Response> get(String url, {String? token}) async {
    return await http.get(
      Uri.parse(url),
      headers: _buildHeaders(token: token),
    );
  }

  /// Makes a POST request to the Plex API with standard headers.
  Future<http.Response> post(String url, {String? token, Object? body}) async {
    return await http.post(
      Uri.parse(url),
      headers: _buildHeaders(token: token),
      body: body,
    );
  }

  /// Makes a GET request with a timeout.
  Future<http.Response> getWithTimeout(
    String url, {
    String? token,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    return await http
        .get(
          Uri.parse(url),
          headers: _buildHeaders(token: token),
        )
        .timeout(timeout);
  }

  /// Builds standard headers for Plex API requests.
  Map<String, String> _buildHeaders({String? token}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'X-Plex-Product': PlexConstants.productName,
      'X-Plex-Client-Identifier': PlexConstants.clientIdentifier,
    };

    if (token != null) {
      headers['X-Plex-Token'] = token;
    }

    return headers;
  }

  /// Decodes a JSON response body.
  dynamic decodeJson(http.Response response) {
    return json.decode(response.body);
  }
}
