import 'package:flutter/material.dart';
import 'package:apollo/core/services/plex/plex_services.dart';
import 'package:apollo/core/services/storage_service.dart';
import 'package:apollo/core/database/database_service.dart';

class MobileServerSettingsPage extends StatefulWidget {
  const MobileServerSettingsPage({super.key});

  @override
  State<MobileServerSettingsPage> createState() => _MobileServerSettingsPageState();
}

class _MobileServerSettingsPageState extends State<MobileServerSettingsPage> {
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

  static const Color _backgroundColor = Color(0xFF121212);

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
        await _loadServersAndLibraries();
      } else {
        await _storageService.clearPlexCredentials();
      }
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
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
      debugPrint('Error loading sync status: $e');
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
        _estimatedTotalTracks = 1;
      });

      int totalTracks = 0;
      int librariesCompleted = 0;
      
      for (var server in _servers) {
        final libraryKeys = selectedServers[server.machineIdentifier];
        
        if (libraryKeys != null && libraryKeys.isNotEmpty) {
          final serverUrl = _serverService.getBestConnectionUrlForServer(server);
          
          if (serverUrl != null) {
            for (var libraryKey in libraryKeys) {
              if (!mounted) return;
              
              final libraryInfo = _serverLibraries[server.machineIdentifier]
                  ?.firstWhere(
                    (lib) => lib['key'] == libraryKey,
                    orElse: () => {'title': 'Library $libraryKey'},
                  );
              final libraryTitle = libraryInfo?['title'] as String? ?? 'Library $libraryKey';
              
              setState(() {
                _currentSyncingLibrary = '$libraryTitle (fetching...)';
              });

              debugPrint('Fetching library $libraryKey from server ${server.machineIdentifier}...');
              
              final tracks = await _libraryService.getTracks(token, serverUrl, libraryKey);
              
              final tracksWithServerId = tracks.map((track) {
                track['serverId'] = server.machineIdentifier;
                return track;
              }).toList();
              
              if (!mounted) return;
              setState(() {
                _currentSyncingLibrary = '$libraryTitle (saving...)';
                _estimatedTotalTracks = totalTracks + tracks.length;
              });
              
              debugPrint('Saving ${tracks.length} tracks from library $libraryKey...');
              
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
              
              debugPrint('Completed ${tracks.length} tracks from library $libraryKey');
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
      _servers = await _serverService.getServers(token);
      
      final savedSelections = await _storageService.getSelectedServers();
      _selectedLibraries = savedSelections.map(
        (key, value) => MapEntry(key, value.toSet())
      );

      final libraryFutures = _servers.map((server) async {
        if (!mounted) return MapEntry('', <Map<String, dynamic>>[]);
        final serverUrl = _serverService.getBestConnectionUrlForServer(server);
        
        if (serverUrl != null) {
          try {
            final libraries = await _libraryService.getLibraries(token, serverUrl);
            final musicLibraries = libraries.where((l) => l.isMusicLibrary).toList();
            return MapEntry(server.machineIdentifier, musicLibraries.map((l) => l.toJson()).toList());
          } catch (e) {
            return MapEntry(server.machineIdentifier, <Map<String, dynamic>>[]);
          }
        }
        return MapEntry('', <Map<String, dynamic>>[]);
      }).toList();

      final libraryResults = await Future.wait(libraryFutures);
      
      if (!mounted) return;
      
      for (var entry in libraryResults) {
        if (entry.key.isEmpty) continue;
        _serverLibraries[entry.key] = entry.value;
        
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
        backgroundColor: const Color(0xFF282828),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to disconnect from Plex?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Server Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Plex Connection Card
                  Card(
                    color: const Color(0xFF282828),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _isAuthenticated ? Icons.check_circle : Icons.cloud_off,
                                color: _isAuthenticated ? Colors.green : Colors.grey,
                                size: 32,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isAuthenticated ? 'Connected' : 'Not Connected',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if (_username != null)
                                      Text(
                                        _username!,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: Color(0xFF404040)),
                          const SizedBox(height: 16),
                          const Text(
                            'Plex Server',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isAuthenticated
                                ? 'Your Plex account is connected. Select libraries below to sync.'
                                : 'Connect to your Plex account to access your media libraries.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
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
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _signOut,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF404040),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),
                            if (_isSyncing && _estimatedTotalTracks > 0) ...[
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _currentSyncingLibrary ?? 'Syncing...',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                      Text(
                                        '${(_syncProgress * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: _syncProgress,
                                      backgroundColor: const Color(0xFF404040),
                                      color: Colors.purple,
                                      minHeight: 8,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '$_totalTracksSynced tracks synced',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_syncStatus != null && !_isSyncing) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1a1a1a),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Last Sync',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          _formatSyncDate(_syncStatus!['lastSync']),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text(
                                          'Tracks',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          '${_syncStatus!['trackCount']}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ] else
                            ElevatedButton.icon(
                              onPressed: _signIn,
                              icon: const Icon(Icons.login),
                              label: const Text('Sign In with Plex'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
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
                        color: Color(0xFF282828),
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                            child: CircularProgressIndicator(color: Colors.purple),
                          ),
                        ),
                      )
                    else if (_servers.isEmpty)
                      Card(
                        color: const Color(0xFF282828),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.orange, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                'No servers found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Make sure your Plex Media Server is running and accessible.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.white70),
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
                              const Text(
                                'Select Libraries',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              TextButton(
                                onPressed: _saveSelections,
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Choose which music libraries you want to use in Apollo',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._servers.map((server) {
                            final serverId = server.machineIdentifier;
                            final serverName = server.name;
                            final libraries = _serverLibraries[serverId] ?? [];
                            
                            return Card(
                              color: const Color(0xFF282828),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.dns, color: Colors.purple, size: 24),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            serverName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (libraries.isEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Text(
                                        'No music libraries found',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.white54,
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 12),
                                      ...libraries.map((library) {
                                        final libraryKey = library['key'] as String;
                                        final libraryTitle = library['title'] as String;
                                        final isSelected = _selectedLibraries[serverId]?.contains(libraryKey) ?? false;
                                        
                                        return CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            libraryTitle,
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          value: isSelected,
                                          activeColor: Colors.purple,
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
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                  ],
                  
                  // How Authentication Works
                  const SizedBox(height: 16),
                  Card(
                    color: const Color(0xFF282828),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How Authentication Works',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '1. Click "Sign In with Plex"\n'
                            '2. Your browser will open to Plex login page\n'
                            '3. Sign in with your Plex credentials\n'
                            '4. Once authenticated, return to this app\n'
                            '5. Your credentials will be securely stored',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                              height: 1.5,
                            ),
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
