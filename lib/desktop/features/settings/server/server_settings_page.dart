import 'package:flutter/material.dart';
import 'package:apollo/core/services/plex/plex_services.dart';
import 'package:apollo/core/services/storage_service.dart';
import 'package:apollo/core/database/database_service.dart';

class ServerSettingsPage extends StatefulWidget {
  const ServerSettingsPage({super.key});

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  final PlexAuthService _authService = PlexAuthService();
  final PlexServerService _serverService = PlexServerService();
  final PlexLibraryService _libraryService = PlexLibraryService();
  final StorageService _storageService = StorageService();
  final DatabaseService _dbService = DatabaseService();
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isLoadingServers = false;
  bool _isSyncing = false;
  String? _username;
  List<PlexServer> _servers = [];
  Map<String, List<Map<String, dynamic>>> _serverLibraries = {};
  Map<String, Set<String>> _selectedLibraries = {};
  Map<String, dynamic>? _syncStatus;
  double _syncProgress = 0.0;
  String? _currentSyncingLibrary;
  int _totalTracksSynced = 0;
  int _estimatedTotalTracks = 0;

  static const Color _backgroundColor = Color(0xFF303030);

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final token = await _storageService.getPlexToken();
    if (token != null) {
      final isValid = await _authService.validateToken(token);
      if (isValid) {
        final user = await _storageService.getUsername();
        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
          _username = user;
        });
        // Load servers and libraries
        await _loadServersAndLibraries();
      } else {
        await _storageService.clearPlexCredentials();
      }
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    
    // Load sync status
    await _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    try {
      final syncMetadata = await _dbService.getAllSyncMetadata();
      final trackCount = await _dbService.getTrackCount();
      
      if (syncMetadata.isNotEmpty) {
        final lastSync = syncMetadata.first['last_sync'] as int;
        final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);
        
        if (mounted) {
          setState(() {
            _syncStatus = {
              'trackCount': trackCount,
              'lastSync': lastSyncDate,
            };
          });
        }
      }
    } catch (e) {
      print('Error loading sync status: $e');
    }
  }

  Future<void> _syncLibrary() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      final token = await _storageService.getPlexToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final selectedServers = await _storageService.getSelectedServers();
      if (selectedServers.isEmpty) {
        throw Exception('No libraries selected');
      }

      // Calculate total libraries to sync
      int totalLibraries = 0;
      for (var server in _servers) {
        final libraryKeys = selectedServers[server.machineIdentifier];
        if (libraryKeys != null && libraryKeys.isNotEmpty) {
          totalLibraries += libraryKeys.length;
        }
      }

      if (!mounted) return;
      setState(() {
        _syncProgress = 0.0;
        _totalTracksSynced = 0;
        _estimatedTotalTracks = 1; // Will be updated as we fetch
      });

      int totalTracks = 0;
      int librariesCompleted = 0;
      
      // Sync tracks from all selected libraries (fetch + save in one pass)
      for (var server in _servers) {
        final libraryKeys = selectedServers[server.machineIdentifier];
        
        if (libraryKeys != null && libraryKeys.isNotEmpty) {
          final serverUrl = _serverService.getBestConnectionUrlForServer(server);
          
          if (serverUrl != null) {
            for (var libraryKey in libraryKeys) {
              if (!mounted) return;
              
              // Update progress tracking
              final libraryInfo = _serverLibraries[server.machineIdentifier]
                  ?.firstWhere(
                    (lib) => lib['key'] == libraryKey,
                    orElse: () => {'title': 'Library $libraryKey'},
                  );
              final libraryTitle = libraryInfo?['title'] as String? ?? 'Library $libraryKey';
              
              setState(() {
                _currentSyncingLibrary = '$libraryTitle (fetching...)';
              });

              print('Fetching library $libraryKey from server ${server.machineIdentifier}...');
              
              final tracks = await _libraryService.getTracks(token, serverUrl, libraryKey);
              
              // Add serverId to all tracks (do once, not twice)
              final tracksWithServerId = tracks.map((track) {
                track['serverId'] = server.machineIdentifier;
                return track;
              }).toList();
              
              if (!mounted) return;
              setState(() {
                _currentSyncingLibrary = '$libraryTitle (saving...)';
                _estimatedTotalTracks = totalTracks + tracks.length; // Update estimate
              });
              
              print('Saving ${tracks.length} tracks from library $libraryKey...');
              
              // Save with progress callback
              await _dbService.saveTracks(
                server.machineIdentifier,
                libraryKey,
                tracksWithServerId,
                onProgress: (current, total) {
                  if (mounted) {
                    setState(() {
                      _currentSyncingLibrary = '$libraryTitle (saving $current/$total)';
                    });
                  }
                },
              );
              
              totalTracks += tracks.length;
              librariesCompleted++;
              
              if (!mounted) return;
              setState(() {
                _totalTracksSynced = totalTracks;
                _syncProgress = librariesCompleted / totalLibraries;
              });
              
              print('Completed ${tracks.length} tracks from library $libraryKey');
            }
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced $totalTracks songs to local database'),
            backgroundColor: Colors.green,
          ),
        );
        
        await _loadSyncStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing library: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncProgress = 0.0;
          _totalTracksSynced = 0;
          _estimatedTotalTracks = 0;
          _currentSyncingLibrary = null;
        });
      }
    }
  }

  Future<void> _loadServersAndLibraries() async {
    if (!mounted) return;
    setState(() => _isLoadingServers = true);
    
    final token = await _storageService.getPlexToken();
    if (token == null) {
      if (!mounted) return;
      setState(() => _isLoadingServers = false);
      return;
    }

    try {
      // Get servers
      _servers = await _serverService.getServers(token);
      
      // Load saved selections
      final savedSelections = await _storageService.getSelectedServers();
      _selectedLibraries = savedSelections.map(
        (key, value) => MapEntry(key, value.toSet())
      );

      // Get libraries for all servers in parallel
      final libraryFutures = _servers.map((server) async {
        if (!mounted) return MapEntry('', <Map<String, dynamic>>[]);
        final serverUrl = _serverService.getBestConnectionUrlForServer(server);
        
        if (serverUrl != null) {
          try {
            final libraries = await _libraryService.getLibraries(token, serverUrl);
            // Filter to only music libraries (type == 'artist')
            final musicLibraries = libraries.where((l) => l.isMusicLibrary).toList();
            return MapEntry(server.machineIdentifier, musicLibraries.map((l) => l.toJson()).toList());
          } catch (e) {
            // Error fetching libraries - return empty list
            return MapEntry(server.machineIdentifier, <Map<String, dynamic>>[]);
          }
        }
        return MapEntry('', <Map<String, dynamic>>[]);
      }).toList();

      final libraryResults = await Future.wait(libraryFutures);
      
      if (!mounted) return;
      
      // Update state with results
      for (var entry in libraryResults) {
        if (entry.key.isEmpty) continue; // Skip empty entries from early returns
        _serverLibraries[entry.key] = entry.value;
        
        // Initialize selection if not already set
        if (!_selectedLibraries.containsKey(entry.key)) {
          _selectedLibraries[entry.key] = {};
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading servers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    if (!mounted) return;
    setState(() => _isLoadingServers = false);
  }

  Future<void> _saveSelections() async {
    final selections = _selectedLibraries.map(
      (key, value) => MapEntry(key, value.toList())
    );
    await _storageService.saveSelectedServers(selections);
    
    // Build and save the server URL map for the selected servers
    await _saveServerUrlMap();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server selections saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Saves the mapping of server IDs to their best connection URLs.
  Future<void> _saveServerUrlMap() async {
    final Map<String, String> urlMap = {};
    
    for (var server in _servers) {
      final serverUrl = _serverService.getBestConnectionUrlForServer(server);
      if (serverUrl != null) {
        urlMap[server.machineIdentifier] = serverUrl;
        debugPrint('Saving server URL: ${server.machineIdentifier} -> $serverUrl');
      }
    }
    
    await _storageService.saveServerUrlMap(urlMap);
    debugPrint('Saved ${urlMap.length} server URLs to storage');
  }

  Future<void> _signIn() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final result = await _authService.signIn();
      
      if (result['success'] == true) {
        await _storageService.savePlexToken(result['token']);
        if (result['username'] != null) {
          await _storageService.saveUsername(result['username']);
        }
        
        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
          _username = result['username'];
        });
        
        // Load servers and libraries after successful sign-in
        await _loadServersAndLibraries();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Successfully connected to Plex!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sign in: ${result['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatSyncDate(DateTime date) {
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

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to disconnect from Plex?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storageService.clearPlexCredentials();
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _username = null;
        _servers = [];
        _serverLibraries = {};
        _selectedLibraries = {};
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from Plex'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isAuthenticated
                                    ? Icons.check_circle
                                    : Icons.cloud_off,
                                color: _isAuthenticated
                                    ? Colors.green
                                    : Colors.grey,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isAuthenticated
                                          ? 'Connected'
                                          : 'Not Connected',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    if (_isAuthenticated && _username != null)
                                      Text(
                                        'Logged in as $_username',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'Plex Server',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isAuthenticated
                                ? 'Your Plex account is connected. You can access your media libraries and content.'
                                : 'Connect to your Plex account to access your media libraries.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          if (_isAuthenticated) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _isSyncing ? null : _syncLibrary,
                                    icon: _isSyncing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.sync),
                                    label: Text(_isSyncing ? 'Syncing...' : 'Sync Library'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: _signOut,
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Sign Out'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            if (_isSyncing && _estimatedTotalTracks > 0) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.sync, size: 20, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Syncing $_currentSyncingLibrary',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _syncProgress,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey[300],
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(_syncProgress * 100).toStringAsFixed(0)}% • $_totalTracksSynced of $_estimatedTotalTracks songs',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_syncStatus != null && !_isSyncing) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${_syncStatus!['trackCount']} songs synced • Last sync: ${_formatSyncDate(_syncStatus!['lastSync'])}',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ]
                          else
                            ElevatedButton.icon(
                              onPressed: _signIn,
                              icon: const Icon(Icons.login),
                              label: const Text('Sign In with Plex'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Server and Library Selection
                  if (_isAuthenticated) ...[
                    const SizedBox(height: 16),
                    if (_isLoadingServers)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    else if (_servers.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(Icons.info_outline, size: 48, color: Colors.orange),
                              const SizedBox(height: 16),
                              Text(
                                'No servers found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Make sure you have a Plex Media Server set up and it\'s accessible.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Libraries',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              FilledButton.icon(
                                onPressed: _saveSelections,
                                icon: const Icon(Icons.save),
                                label: const Text('Save'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose which music libraries you want to use in Apollo',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._servers.map((server) {
                            final serverId = server.machineIdentifier;
                            final serverName = server.name;
                            final libraries = _serverLibraries[serverId] ?? [];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: ExpansionTile(
                                leading: const Icon(Icons.dns),
                                title: Text(serverName),
                                subtitle: Text('${libraries.length} music ${libraries.length == 1 ? 'library' : 'libraries'}'),
                                children: [
                                  if (libraries.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.all(16.0),
                                      child: Text(
                                        'No music libraries found on this server',
                                        style: TextStyle(fontStyle: FontStyle.italic),
                                      ),
                                    )
                                  else
                                    ...libraries.map((library) {
                                      final libraryKey = library['key'] as String;
                                      final libraryTitle = library['title'] as String;
                                      final isSelected = _selectedLibraries[serverId]?.contains(libraryKey) ?? false;
                                      
                                      return CheckboxListTile(
                                        title: Text(libraryTitle),
                                        subtitle: Text('Library ID: $libraryKey'),
                                        value: isSelected,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            if (value == true) {
                                              _selectedLibraries[serverId] ??= {};
                                              _selectedLibraries[serverId]!.add(libraryKey);
                                            } else {
                                              _selectedLibraries[serverId]?.remove(libraryKey);
                                            }
                                          });
                                        },
                                      );
                                    }),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                  ],
                  
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'How Authentication Works',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '1. Click "Sign In with Plex"\n'
                            '2. Your browser will open to Plex login page\n'
                            '3. Sign in with your Plex credentials\n'
                            '4. Once authenticated, return to this app\n'
                            '5. Your credentials will be securely stored',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
