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
  final bool isRelay;
  final String protocol;
  final int port;

  PlexConnection({
    required this.uri,
    required this.isLocal,
    required this.isRelay,
    required this.protocol,
    required this.port,
  });

  factory PlexConnection.fromJson(Map<String, dynamic> json) {
    return PlexConnection(
      uri: json['uri'] as String,
      isLocal: json['local'] as bool? ?? false,
      isRelay: json['relay'] as bool? ?? false,
      protocol: json['protocol'] as String? ?? 'https',
      port: json['port'] as int? ?? 32400,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'local': isLocal,
      'relay': isRelay,
      'protocol': protocol,
      'port': port,
    };
  }

  bool get isHttps => protocol == 'https' || uri.startsWith('https://');
  bool get isRemote => !isLocal;
  bool get isDirect => !isRelay && !isLocal;
}

/// Manages Plex server discovery and connection selection.
/// Single responsibility: Server and connection management.
class PlexServerService {
  final PlexApiClient _apiClient = PlexApiClient();

  /// Fetches all owned Plex servers for the authenticated user.
  Future<List<PlexServer>> getServers(String token) async {
    try {
      debugPrint('PLEX_SERVER_SERVICE: Fetching servers from Plex API...');
      final response = await _apiClient.get(
        '${PlexConstants.plexApiUrl}/api/v2/resources?includeHttps=1&includeRelay=1',
        token: token,
      );

      debugPrint(
        'PLEX_SERVER_SERVICE: Response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = _apiClient.decodeJson(response);
        debugPrint('PLEX_SERVER_SERVICE: Found ${data.length} total resources');

        final servers = data
            .where((resource) {
              final isMediaServer = resource['product'] == 'Plex Media Server';
              final isOwned = resource['owned'] == true;
              debugPrint(
                'PLEX_SERVER_SERVICE: Resource "${resource['name']}" - '
                'Product: ${resource['product']}, Owned: ${resource['owned']}',
              );
              return isMediaServer && isOwned;
            })
            .map((resource) => PlexServer.fromJson(resource))
            .toList();

        debugPrint(
          'PLEX_SERVER_SERVICE: Filtered to ${servers.length} owned Plex Media Servers',
        );
        for (var server in servers) {
          debugPrint(
            'PLEX_SERVER_SERVICE: - ${server.name} (${server.machineIdentifier}) with ${server.connections.length} connections',
          );
        }

        return servers;
      }
      debugPrint('PLEX_SERVER_SERVICE: Non-200 response, returning empty list');
      return [];
    } catch (e, stackTrace) {
      debugPrint('PLEX_SERVER_SERVICE: ❌ Error fetching servers: $e');
      debugPrint('PLEX_SERVER_SERVICE: Stack trace: $stackTrace');
      return [];
    }
  }

  /// Finds the best remote HTTPS connection for a server.
  /// Priority order (always prefer remote direct):
  /// 1. Remote direct HTTPS (non-relay, non-local) - PREFERRED
  /// 2. Any remote HTTPS connection
  /// 3. Relay HTTPS (if no direct available)
  /// 4. Any HTTPS connection (including local)
  /// 5. Any connection as fallback
  PlexConnection? findBestConnection(
    List<PlexConnection> connections, {
    String? serverName,
  }) {
    debugPrint('========== CONNECTION SELECTION ==========');
    if (serverName != null) {
      debugPrint('Server: $serverName');
    }
    debugPrint('Available connections: ${connections.length}');
    for (var conn in connections) {
      debugPrint('  - URI: ${conn.uri}');
      debugPrint(
        '    Local: ${conn.isLocal}, Remote: ${conn.isRemote}, Relay: ${conn.isRelay}, Direct: ${conn.isDirect}',
      );
      debugPrint('    Protocol: ${conn.protocol}, Port: ${conn.port}');
    }

    // Priority 1: Remote direct HTTPS connections (non-relay, non-local) - ALWAYS PREFERRED
    // Sort by port DESCENDING to prefer user-configured ports (usually higher than default 32400)
    final remoteDirectHttps =
        connections.where((c) => c.isRemote && c.isDirect && c.isHttps).toList()
          ..sort(
            (a, b) => b.port.compareTo(a.port),
          ); // Descending - prefer higher ports

    if (remoteDirectHttps.isNotEmpty) {
      final selected = remoteDirectHttps.first;
      debugPrint(
        '✓ Selected REMOTE DIRECT HTTPS connection (PREFERRED): ${selected.uri}',
      );
      return selected;
    }

    // Priority 2: Any remote HTTPS connection (including non-direct)
    final remoteHttps =
        connections.where((c) => c.isRemote && c.isHttps).toList()
          ..sort((a, b) => b.port.compareTo(a.port)); // Descending

    if (remoteHttps.isNotEmpty) {
      final selected = remoteHttps.first;
      debugPrint('✓ Selected remote HTTPS connection: ${selected.uri}');
      return selected;
    }

    // Priority 3: Relay HTTPS connections (slower but still works)
    final relayHttps = connections
        .where((c) => c.isRelay && c.isHttps)
        .toList();

    if (relayHttps.isNotEmpty) {
      final selected = relayHttps.first;
      debugPrint('✓ Selected RELAY HTTPS connection: ${selected.uri}');
      return selected;
    }

    // Priority 4: Any HTTPS connection (including local)
    final anyHttps = connections.where((c) => c.isHttps).toList();
    if (anyHttps.isNotEmpty) {
      final selected = anyHttps.first;
      debugPrint('✓ Selected HTTPS connection: ${selected.uri}');
      return selected;
    }

    // Priority 5: Any connection as fallback
    if (connections.isNotEmpty) {
      final selected = connections.first;
      debugPrint('⚠ Selected fallback connection: ${selected.uri}');
      return selected;
    }

    debugPrint('✗ No connections found!');
    return null;
  }

  /// Gets the best connection URL for a server.
  String? getBestConnectionUrl(
    List<PlexConnection> connections, {
    String? serverName,
  }) {
    return findBestConnection(connections, serverName: serverName)?.uri;
  }

  /// Gets the best connection URL for a PlexServer object.
  String? getBestConnectionUrlForServer(PlexServer server) {
    return findBestConnection(server.connections, serverName: server.name)?.uri;
  }

  /// Creates a mapping of server machine identifiers to their best connection URLs.
  Map<String, String> buildServerUrlMap(List<PlexServer> servers) {
    final Map<String, String> urlMap = {};

    for (var server in servers) {
      final bestUrl = getBestConnectionUrlForServer(server);
      if (bestUrl != null) {
        urlMap[server.machineIdentifier] = bestUrl;
        debugPrint(
          'Server "${server.name}" (${server.machineIdentifier}) -> $bestUrl',
        );
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
    final selectedServer = findServerWithSelectedLibraries(
      servers,
      selectedLibraries,
    );

    if (selectedServer == null) {
      debugPrint('No server with selected libraries found');
      return null;
    }

    return getBestConnectionUrlForServer(selectedServer);
  }

  /// Fetches all servers and builds a URL map in one call.
  /// Returns a map of serverId -> best connection URL.
  /// This is the primary method for getting server URLs.
  Future<Map<String, String>> fetchServerUrlMap(String token) async {
    final servers = await getServers(token);
    return buildServerUrlMap(servers);
  }

  /// Gets the best URL for a specific server by its machineIdentifier.
  /// If serverId is null or not found, returns null.
  Future<String?> getUrlForServer(String token, String? serverId) async {
    if (serverId == null) return null;

    final servers = await getServers(token);
    final server = servers
        .where((s) => s.machineIdentifier == serverId)
        .firstOrNull;

    if (server == null) {
      debugPrint('Server not found: $serverId');
      return null;
    }

    return getBestConnectionUrlForServer(server);
  }

  /// Gets all servers with their best URLs as a convenience wrapper.
  Future<List<({PlexServer server, String? url})>> getServersWithUrls(
    String token,
  ) async {
    final servers = await getServers(token);
    return servers
        .map((s) => (server: s, url: getBestConnectionUrlForServer(s)))
        .toList();
  }
}
