import 'package:flutter/material.dart';
import 'package:apollo/core/services/plex/plex_services.dart';
import 'server_settings_service.dart';

class MobileServerSettingsPage extends StatefulWidget {
  const MobileServerSettingsPage({super.key});

  @override
  State<MobileServerSettingsPage> createState() => _MobileServerSettingsPageState();
}

class _MobileServerSettingsPageState extends State<MobileServerSettingsPage> {
  final _service = ServerSettingsService();
  
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

  static const Color _backgroundColor = Color(0xFF121212);

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final token = await _service.getPlexToken();
    if (token != null) {
      final isValid = await _service.validateToken(token);
      if (isValid) {
        final user = await _service.getUsername();
        if (!mounted) return;
        setState(() {
          _isAuthenticated = true;
          _username = user;
        });
        await _loadServersAndLibraries();
      } else {
        await _service.clearCredentials();
      }
    }
    
    if (!mounted) return;
    setState(() => _isLoading = false);
    await _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    final syncStatus = await _service.loadSyncStatus();
    if (!mounted) return;
    setState(() => _syncStatus = syncStatus);
  }

  Future<void> _syncLibrary() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      await _service.syncLibrary(
        _servers,
        _serverLibraries,
        (library) {
          if (mounted) {
            setState(() => _currentSyncingLibrary = library);
          }
        },
        (progress) {
          if (mounted) {
            setState(() => _syncProgress = progress);
          }
        },
        (tracks) {
          if (mounted) {
            setState(() => _totalTracksSynced = tracks);
          }
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced $_totalTracksSynced songs'),
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
          _currentSyncingLibrary = null;
        });
      }
    }
  }

  Future<void> _loadServersAndLibraries() async {
    if (!mounted) return;
    setState(() => _isLoadingServers = true);
    
    final token = await _service.getPlexToken();
    if (token == null) {
      if (!mounted) return;
      setState(() => _isLoadingServers = false);
      return;
    }

    try {
      _servers = await _service.getServers(token);
      
      final savedSelections = await _service.getSelectedServers();
      _selectedLibraries = savedSelections.map(
        (key, value) => MapEntry(key, value.toSet())
      );

      final libraryFutures = _servers.map((server) async {
        final libraries = await _service.getLibrariesForServer(token, server);
        return MapEntry(server.machineIdentifier, libraries);
      }).toList();

      final libraryResults = await Future.wait(libraryFutures);
      
      if (!mounted) return;
      
      for (var entry in libraryResults) {
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
    await _service.saveSelections(_selectedLibraries);
    await _service.saveServerUrlMap(_servers);
    
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
      final result = await _service.signIn();
      
      if (result['success'] == true) {
        await _service.saveCredentials(result['token'], result['username']);
        
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
      await _service.clearCredentials();
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
                  _buildConnectionCard(),
                  if (_isAuthenticated) ...[
                    const SizedBox(height: 16),
                    _buildServerSelection(),
                  ],
                  const SizedBox(height: 16),
                  _buildAuthenticationInfo(),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
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
                          style: const TextStyle(fontSize: 14, color: Colors.grey),
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
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            _isAuthenticated ? _buildAuthenticatedActions() : _buildSignInButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthenticatedActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        if (_isSyncing) ...[
          const SizedBox(height: 16),
          _buildSyncProgress(),
        ],
        if (_syncStatus != null && !_isSyncing) ...[
          const SizedBox(height: 16),
          _buildSyncStatus(),
        ],
      ],
    );
  }

  Widget _buildSyncProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentSyncingLibrary ?? 'Syncing...',
          style: const TextStyle(fontSize: 13, color: Colors.white70),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_totalTracksSynced tracks synced',
              style: const TextStyle(fontSize: 12, color: Colors.white60),
            ),
            Text(
              '${(_syncProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSyncStatus() {
    return Container(
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
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                _service.formatSyncDate(_syncStatus!['lastSync']),
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
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
    );
  }

  Widget _buildSignInButton() {
    return ElevatedButton.icon(
      onPressed: _signIn,
      icon: const Icon(Icons.login),
      label: const Text('Sign In with Plex'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildServerSelection() {
    return _isLoadingServers
        ? const Card(
            color: Color(0xFF282828),
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: CircularProgressIndicator(color: Colors.purple),
              ),
            ),
          )
        : _servers.isEmpty
            ? _buildNoServersCard()
            : _buildServersList();
  }

  Widget _buildNoServersCard() {
    return Card(
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
    );
  }

  Widget _buildServersList() {
    return Column(
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
          style: TextStyle(fontSize: 14, color: Colors.white60),
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
    );
  }

  Widget _buildAuthenticationInfo() {
    return Card(
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
    );
  }
}
