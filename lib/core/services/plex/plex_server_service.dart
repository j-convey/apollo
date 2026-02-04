import 'package:flutter/foundation.dart';
import 'plex_api_client.dart';
import 'plex_constants.dart';

/// Represents a Plex server with its connection information.
class PlexServer {
  final String name;
  final String machineIdentifier;
  final List<PlexConnection> connections;

  PlexServer({
    required this.name,
    required this.machineIdentifier,
    required this.connections,
  });

  factory PlexServer.fromJson(Map<String, dynamic> json) {
    final connectionsList = (json['connections'] as List<dynamic>)
        .map((c) => PlexConnection.fromJson(c))
        .toList();

    return PlexServer(
      name: json['name'] as String,
      machineIdentifier: json['clientIdentifier'] as String,
      connections: connectionsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'clientIdentifier': machineIdentifier,
      'connections': connections.map((c) => c.toJson()).toList(),
    };
  }
}

/// Represents a connection endpoint for a Plex server.
class PlexConnection {
  final String uri;
  final bool isLocal;
  final String protocol;
  final int port;

  PlexConnection({
    required this.uri,
    required this.isLocal,
    required this.protocol,
    required this.port,
  });

  factory PlexConnection.fromJson(Map<String, dynamic> json) {
    return PlexConnection(
      uri: json['uri'] as String,
      isLocal: json['local'] as bool? ?? false,
      protocol: json['protocol'] as String? ?? 'https',
      port: json['port'] as int? ?? 32400,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'local': isLocal,
      'protocol': protocol,
      'port': port,
    };
  }

  bool get isHttps => protocol == 'https' || uri.startsWith('https://');
  bool get isRemote => !isLocal;
}

/// Manages Plex server discovery and connection selection.
/// Single responsibility: Server and connection management.
class PlexServerService {
  final PlexApiClient _apiClient = PlexApiClient();

  /// Fetches all owned Plex servers for the authenticated user.
  Future<List<PlexServer>> getServers(String token) async {
    try {
      final response = await _apiClient.get(
        '${PlexConstants.plexApiUrl}/api/v2/resources?includeHttps=1&includeRelay=1',
        token: token,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _apiClient.decodeJson(response);
        return data
            .where((resource) =>
                resource['product'] == 'Plex Media Server' &&
                resource['owned'] == true)
            .map((resource) => PlexServer.fromJson(resource))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching servers: $e');
      return [];
    }
  }

  /// Finds the best remote HTTPS connection for a server.
  /// Prioritizes remote connections since local is not needed.
  PlexConnection? findBestConnection(List<PlexConnection> connections) {
    debugPrint('========== CONNECTION SELECTION ==========');
    debugPrint('Available connections: ${connections.length}');
    for (var conn in connections) {
      debugPrint('  - URI: ${conn.uri}');
      debugPrint('    Local: ${conn.isLocal}, Remote: ${conn.isRemote}');
      debugPrint('    Protocol: ${conn.protocol}, Port: ${conn.port}');
    }

    // Priority 1: Remote HTTPS connections (sorted by port for consistency)
    final remoteHttps = connections
        .where((c) => c.isRemote && c.isHttps)
        .toList()
      ..sort((a, b) => a.port.compareTo(b.port));

    if (remoteHttps.isNotEmpty) {
      final selected = remoteHttps.first;
      debugPrint('✓ Selected remote HTTPS connection: ${selected.uri}');
      return selected;
    }

    // Priority 2: Any HTTPS connection
    final anyHttps = connections.where((c) => c.isHttps).toList();
    if (anyHttps.isNotEmpty) {
      final selected = anyHttps.first;
      debugPrint('✓ Selected HTTPS connection: ${selected.uri}');
      return selected;
    }

    // Priority 3: Any connection
    if (connections.isNotEmpty) {
      final selected = connections.first;
      debugPrint('✓ Selected fallback connection: ${selected.uri}');
      return selected;
    }

    debugPrint('✗ No connections found!');
    return null;
  }

  /// Gets the best connection URL for a server.
  String? getBestConnectionUrl(List<PlexConnection> connections) {
    return findBestConnection(connections)?.uri;
  }

  /// Creates a mapping of server machine identifiers to their best connection URLs.
  Map<String, String> buildServerUrlMap(List<PlexServer> servers) {
    final Map<String, String> urlMap = {};

    for (var server in servers) {
      final bestUrl = getBestConnectionUrl(server.connections);
      if (bestUrl != null) {
        urlMap[server.machineIdentifier] = bestUrl;
        debugPrint('Server "${server.name}" (${server.machineIdentifier}) -> $bestUrl');
      }
    }

    return urlMap;
  }

  /// Finds the server that has the selected libraries.
  PlexServer? findServerWithSelectedLibraries(
    List<PlexServer> servers,
    Map<String, List<String>> selectedLibraries,
  ) {
    for (var server in servers) {
      final libraryKeys = selectedLibraries[server.machineIdentifier];
      if (libraryKeys != null && libraryKeys.isNotEmpty) {
        debugPrint('Found server with selected libraries: ${server.name}');
        return server;
      }
    }
    return null;
  }

  /// Gets the connection URL for the server with selected libraries.
  Future<String?> getSelectedServerUrl(
    String token,
    Map<String, List<String>> selectedLibraries,
  ) async {
    final servers = await getServers(token);
    final selectedServer = findServerWithSelectedLibraries(servers, selectedLibraries);

    if (selectedServer == null) {
      debugPrint('No server with selected libraries found');
      return null;
    }

    return getBestConnectionUrl(selectedServer.connections);
  }
}
