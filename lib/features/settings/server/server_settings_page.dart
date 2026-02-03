import 'package:flutter/material.dart';
import 'package:apollo/core/services/plex_auth_service.dart';
import 'package:apollo/core/services/storage_service.dart';
import '../../../core/database/database_service.dart';

class ServerSettingsPage extends StatefulWidget {
  const ServerSettingsPage({super.key});

  @override
  State<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends State<ServerSettingsPage> {
  final PlexAuthService _authService = PlexAuthService();
  final StorageService _storageService = StorageService();
  final DatabaseService _dbService = DatabaseService();
  bool _isAuthenticated = false;
  bool _isLoading = false;
  bool _isLoadingServers = false;
  bool _isSyncing = false;
  String? _username;
  List<Map<String, dynamic>> _servers = [];
  Map<String, List<Map<String, dynamic>>> _serverLibraries = {};
  Map<String, Set<String>> _selectedLibraries = {};
  Map<String, dynamic>? _syncStatus;

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

      int totalTracks = 0;
      
      // Sync tracks from all selected libraries
      for (var server in _servers) {
        final machineIdentifier = server['clientIdentifier'] as String;
        final libraryKeys = selectedServers[machineIdentifier];
        
        if (libraryKeys != null && libraryKeys.isNotEmpty) {
          final connections = server['connections'] as List<dynamic>;
          final serverUrl = _authService.getBestConnectionUrl(connections);
          
          if (serverUrl != null) {
            for (var libraryKey in libraryKeys) {
              print('Syncing library $libraryKey from server $machineIdentifier...');
              
              final tracks = await _authService.getTracks(token, serverUrl, libraryKey);
              
              // Add serverId to each track
              final tracksWithServerId = tracks.map((track) {
                track['serverId'] = machineIdentifier;
                return track;
              }).toList();
              
              await _dbService.saveTracks(machineIdentifier, libraryKey, tracksWithServerId);
              totalTracks += tracks.length;
              
              print('Synced ${tracks.length} tracks from library $libraryKey');
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
        setState(() => _isSyncing = false);
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
      _servers = await _authService.getServers(token);
      
      // Load saved selections
      final savedSelections = await _storageService.getSelectedServers();
      _selectedLibraries = savedSelections.map(
        (key, value) => MapEntry(key, value.toSet())
      );

      // Get libraries for all servers in parallel
      final libraryFutures = _servers.map((server) async {
        if (!mounted) return MapEntry('', <Map<String, dynamic>>[]);
        final connections = server['connections'] as List<dynamic>;
        final serverUrl = _authService.getBestConnectionUrl(connections);
        
        if (serverUrl != null) {
          try {
            final libraries = await _authService.getLibraries(token, serverUrl);
            return MapEntry(server['clientIdentifier'] as String, libraries);
          } catch (e) {
            // Error fetching libraries - return empty list
            return MapEntry(server['clientIdentifier'] as String, <Map<String, dynamic>>[]);
          }
        }
        return MapEntry(server['clientIdentifier'] as String, <Map<String, dynamic>>[]);
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
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server selections saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
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
                            if (_syncStatus != null) ...[
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
                            final serverId = server['clientIdentifier'] as String;
                            final serverName = server['name'] as String;
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
