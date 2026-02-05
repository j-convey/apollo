import 'package:flutter/material.dart';
import 'package:apollo/core/services/plex/plex_services.dart';
import 'package:apollo/core/services/storage_service.dart';
import '../../../core/database/database_service.dart';

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
  // Single selection: only one server and one library can be selected
  String? _selectedServerId;
  String? _selectedLibraryKey;
  Map<String, dynamic>? _syncStatus;
  double _syncProgress = 0.0;
  String? _currentSyncingLibrary;
  int _totalTracksSynced = 0;
  int _estimatedTotalTracks = 0;
  bool _isSavingToDatabase = false;
  int _tracksSavedToDb = 0;
  int _totalTracksToSave = 0;

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
      final syncMetadata = await _dbService.tracks.getAllSyncMetadata();
      final trackCount = await _dbService.tracks.getCount();

      if (syncMetadata.isNotEmpty) {
        final lastSync = syncMetadata.first['last_sync'] as int;
        final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSync);

        if (mounted) {
          setState(() {
            _syncStatus = {'trackCount': trackCount, 'lastSync': lastSyncDate};
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

      final selectedServer = await _storageService.getSelectedServer();
      final selectedLibrary = await _storageService.getSelectedLibrary();
      if (selectedServer == null || selectedLibrary == null) {
        throw Exception('No server or library selected');
      }

      // First pass: estimate total tracks by fetching counts
      int estimatedTracks = 0;
      final serverUrl = await _storageService.getSelectedServerUrl();
      if (serverUrl != null) {
        try {
          final tracks = await _libraryService.getTracks(
            token,
            serverUrl,
            selectedLibrary,
          );
          estimatedTracks += tracks.length;
        } catch (e) {
          // Continue if error
        }
      }

      if (!mounted) return;
      setState(() {
        _syncProgress = 0.0;
        _totalTracksSynced = 0;
        _estimatedTotalTracks = estimatedTracks > 0 ? estimatedTracks : 1;
      });

      int totalTracks = 0;

      // Sync tracks from the selected library
      if (serverUrl != null) {
        if (!mounted) return;

        // Update progress tracking
        final libraryInfo = _serverLibraries[selectedServer]?.firstWhere(
          (lib) => lib['key'] == selectedLibrary,
          orElse: () => {'title': 'Library $selectedLibrary'},
        );
        final libraryTitle =
            libraryInfo?['title'] as String? ?? 'Library $selectedLibrary';

        setState(() {
          _currentSyncingLibrary = libraryTitle;
        });

        // Allow UI to render progress update
        await Future.delayed(const Duration(milliseconds: 50));

        print(
          'Syncing library $selectedLibrary from server $selectedServer...',
        );

        final tracks = await _libraryService.getTracks(
          token,
          serverUrl,
          selectedLibrary,
        );

        // Update progress for each track after fetching
        for (int i = 0; i < tracks.length; i++) {
          if (!mounted) return;

          final track = tracks[i];
          track['serverId'] = selectedServer;

          // Update progress after each track
          setState(() {
            _totalTracksSynced++;
            _syncProgress = _estimatedTotalTracks > 0
                ? _totalTracksSynced / _estimatedTotalTracks
                : 0.0;
          });

          // Render update every 5 tracks or on last track
          if (i % 5 == 0 || i == tracks.length - 1) {
            await Future.delayed(const Duration(milliseconds: 16));
          }
        }

        // Add serverId to all tracks
        final tracksWithServerId = tracks.map((track) {
          track['serverId'] = selectedServer;
          return track;
        }).toList();

        // Update UI to show database save in progress
        if (!mounted) return;
        setState(() {
          _isSavingToDatabase = true;
          _tracksSavedToDb = 0;
          _totalTracksToSave = tracksWithServerId.length;
          _currentSyncingLibrary = 'Saving to database...';
        });

        await _dbService.saveTracks(
          selectedServer,
          selectedLibrary,
          tracksWithServerId,
          onProgress: (current, total) {
            if (mounted) {
              setState(() {
                _tracksSavedToDb = current;
                _totalTracksToSave = total;
              });
            }
          },
        );
        totalTracks += tracks.length;

        if (!mounted) return;

        print('Synced ${tracks.length} tracks from library $selectedLibrary');
      }

      if (mounted) {
        // Show success message with longer duration
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Successfully synced $totalTracks songs to local database',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );

        await _loadSyncStatus();
        
        // Keep the progress bar at 100% visible for a moment before clearing
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error syncing library: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
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
          _isSavingToDatabase = false;
          _tracksSavedToDb = 0;
          _totalTracksToSave = 0;
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
      debugPrint('SERVER_SETTINGS: Fetching servers...');
      _servers = await _serverService.getServers(token);
      debugPrint('SERVER_SETTINGS: Found ${_servers.length} servers');

      if (_servers.isEmpty) {
        debugPrint('SERVER_SETTINGS: No servers returned from API');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No Plex servers found. Make sure your server is online and accessible.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      // Load saved single selection
      _selectedServerId = await _storageService.getSelectedServer();
      _selectedLibraryKey = await _storageService.getSelectedLibrary();

      // Get libraries for all servers in parallel
      final libraryFutures = _servers.map((server) async {
        if (!mounted) return MapEntry('', <Map<String, dynamic>>[]);

        debugPrint(
          'SERVER_SETTINGS: Processing server "${server.name}" (${server.machineIdentifier})',
        );
        debugPrint(
          'SERVER_SETTINGS: Server has ${server.connections.length} connections',
        );

        final serverUrl = _serverService.getBestConnectionUrlForServer(server);

        if (serverUrl == null) {
          debugPrint(
            'SERVER_SETTINGS: ⚠️ No valid connection URL for server "${server.name}"',
          );
          return MapEntry(server.machineIdentifier, <Map<String, dynamic>>[]);
        }

        debugPrint('SERVER_SETTINGS: Using URL: $serverUrl');

        try {
          final libraries = await _libraryService.getMusicLibraries(
            token,
            serverUrl,
          );
          debugPrint(
            'SERVER_SETTINGS: Found ${libraries.length} music libraries for "${server.name}"',
          );
          return MapEntry(
            server.machineIdentifier,
            libraries.map((l) => l.toJson()).toList(),
          );
        } catch (e) {
          debugPrint(
            'SERVER_SETTINGS: ❌ Error fetching libraries for "${server.name}": $e',
          );
          // Error fetching libraries - return empty list
          return MapEntry(server.machineIdentifier, <Map<String, dynamic>>[]);
        }
      }).toList();

      final libraryResults = await Future.wait(libraryFutures);

      if (!mounted) return;

      // Update state with results
      int totalLibraries = 0;
      for (var entry in libraryResults) {
        if (entry.key.isEmpty)
          continue; // Skip empty entries from early returns
        _serverLibraries[entry.key] = entry.value;
        totalLibraries += entry.value.length;
      }

      debugPrint('SERVER_SETTINGS: Total libraries loaded: $totalLibraries');

      // Show warning if servers were found but no libraries
      if (_servers.isNotEmpty && totalLibraries == 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Servers found but no libraries could be loaded. Check server connectivity.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('SERVER_SETTINGS: ❌ Fatal error loading servers: $e');
      debugPrint('SERVER_SETTINGS: Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading servers: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 7),
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _isLoadingServers = false);
  }

  Future<void> _saveSelections() async {
    // Validate that both server and library are selected
    if (_selectedServerId == null || _selectedLibraryKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a server and a library'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Save single selection
    await _storageService.saveSelectedServer(_selectedServerId!);
    await _storageService.saveSelectedLibrary(_selectedLibraryKey!);

    // Only now determine and save the best connection URL for the selected server
    await _saveSelectedServerUrl();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Server selection saved!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Saves the best connection URL for the selected server only.
  /// This is only called when user explicitly saves their selection.
  Future<void> _saveSelectedServerUrl() async {
    if (_selectedServerId == null) return;

    final server = _servers.firstWhere(
      (s) => s.machineIdentifier == _selectedServerId,
      orElse: () => throw Exception('Selected server not found'),
    );

    // Get the best remote direct connection for the selected server
    final serverUrl = _serverService.getBestConnectionUrlForServer(server);
    if (serverUrl != null) {
      await _storageService.saveSelectedServerUrl(serverUrl);
      debugPrint('Saved selected server URL: $_selectedServerId -> $serverUrl');
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
      await _dbService.clearAllData();
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
        _username = null;
        _servers = [];
        _serverLibraries = {};
        _selectedServerId = null;
        _selectedLibraryKey = null;
        _syncStatus = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Disconnected from Plex and cleared local data'),
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
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                    if (_isAuthenticated && _username != null)
                                      Text(
                                        'Logged in as $_username',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodyMedium,
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
                                    label: Text(
                                      _isSyncing
                                          ? 'Syncing...'
                                          : 'Sync Library',
                                    ),
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
                                        const Icon(
                                          Icons.sync,
                                          size: 20,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _isSavingToDatabase
                                                ? 'Saving to database...'
                                                : 'Syncing $_currentSyncingLibrary',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _isSavingToDatabase
                                            ? (_totalTracksToSave > 0
                                                ? _tracksSavedToDb / _totalTracksToSave
                                                : 0.0)
                                            : _syncProgress,
                                        minHeight: 6,
                                        backgroundColor: Colors.grey[300],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.blue[600]!,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _isSavingToDatabase
                                          ? 'Saving $_tracksSavedToDb of $_totalTracksToSave songs to database'
                                          : '${(_syncProgress * 100).toStringAsFixed(0)}% • $_totalTracksSynced of $_estimatedTotalTracks songs',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                      ),
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
                          ] else
                            ElevatedButton.icon(
                              onPressed: _signIn,
                              icon: const Icon(Icons.login),
                              label: const Text('Sign In with Plex'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
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
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (_servers.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 48,
                                color: Colors.orange,
                              ),
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
                                'Select Server & Library',
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
                            'Choose one server and one music library to use in Apollo',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ..._servers.map((server) {
                            final serverId = server.machineIdentifier;
                            final serverName = server.name;
                            final libraries = _serverLibraries[serverId] ?? [];
                            final isServerSelected =
                                _selectedServerId == serverId;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                children: [
                                  // Server selection (radio button style)
                                  RadioListTile<String>(
                                    title: Row(
                                      children: [
                                        const Icon(Icons.dns),
                                        const SizedBox(width: 12),
                                        Text(serverName),
                                      ],
                                    ),
                                    subtitle: Text(
                                      '${libraries.length} music ${libraries.length == 1 ? 'library' : 'libraries'}',
                                    ),
                                    value: serverId,
                                    groupValue: _selectedServerId,
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedServerId = value;
                                        // Clear library selection when switching servers
                                        _selectedLibraryKey = null;
                                      });
                                    },
                                  ),
                                  // Only show libraries if this server is selected
                                  if (isServerSelected) ...[
                                    const Divider(height: 1),
                                    if (libraries.isEmpty)
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Text(
                                          'No music libraries found on this server',
                                          style: TextStyle(
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      )
                                    else
                                      ...libraries.map((library) {
                                        final libraryKey =
                                            library['key'] as String;
                                        final libraryTitle =
                                            library['title'] as String;

                                        return RadioListTile<String>(
                                          title: Text(libraryTitle),
                                          subtitle: Text(
                                            'Library ID: $libraryKey',
                                          ),
                                          value: libraryKey,
                                          groupValue: _selectedLibraryKey,
                                          onChanged: (String? value) {
                                            setState(() {
                                              _selectedLibraryKey = value;
                                            });
                                          },
                                          contentPadding: const EdgeInsets.only(
                                            left: 48,
                                            right: 16,
                                          ),
                                        );
                                      }),
                                  ],
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
