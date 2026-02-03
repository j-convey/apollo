import 'package:flutter/material.dart';
import '../../core/services/plex_auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/audio_player_service.dart';
import '../../../core/database/database_service.dart';
import 'widgets/songs_header.dart';
import 'widgets/songs_action_buttons.dart';
import 'widgets/songs_table_header.dart';
import 'widgets/track_list_item.dart';
import 'utils/songs_utils.dart';

class SongsPage extends StatefulWidget {
  final AudioPlayerService? audioPlayerService;
  
  const SongsPage({super.key, this.audioPlayerService});

  @override
  State<SongsPage> createState() => _SongsPageState();
}

class _SongsPageState extends State<SongsPage> {
  final PlexAuthService _plexService = PlexAuthService();
  final StorageService _storageService = StorageService();
  final DatabaseService _dbService = DatabaseService();
  
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = true;
  String? _error;
  int? _hoveredIndex;
  String? _currentToken;
  String? _currentServerUrl;
  final Map<String, String> _serverUrls = {};
  
  // Sorting state
  String _sortColumn = 'addedAt';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    debugPrint('[SONGS] ===== _loadTracks() START =====');
    final startTime = DateTime.now();
    setState(() {
      debugPrint('[SONGS] setState: Setting _isLoading = true');
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('[SONGS] Querying database...');
      final dbStartTime = DateTime.now();
      final cachedTracks = await _dbService.getAllTracks();
      final dbEndTime = DateTime.now();
      debugPrint('[SONGS] Database query took: ${dbEndTime.difference(dbStartTime).inMilliseconds}ms');
      debugPrint('[SONGS] Retrieved ${cachedTracks.length} tracks from database');
      
      if (cachedTracks.isNotEmpty) {
        if (mounted) {
          debugPrint('[SONGS] Setting ${cachedTracks.length} tracks in state...');
          final setStateStartTime = DateTime.now();
          setState(() {
            _tracks = cachedTracks;
            _isLoading = false;
          });
          final setStateEndTime = DateTime.now();
          debugPrint('[SONGS] setState completed in: ${setStateEndTime.difference(setStateStartTime).inMilliseconds}ms');
        }
        
        debugPrint('[SONGS] Loading server URLs...');
        await _loadServerUrls();
        final endTime = DateTime.now();
        debugPrint('[SONGS] ===== _loadTracks() COMPLETE in ${endTime.difference(startTime).inMilliseconds}ms =====');
        return;
      }

      if (mounted) {
        setState(() {
          _error = 'No songs in library. Please go to Settings > Server Settings and tap "Sync Library" to download your music library.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading tracks: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadServerUrls() async {
    try {
      final token = await _storageService.getPlexToken();
      if (token == null) return;

      _currentToken = token;
      final servers = await _plexService.getServers(token);
      
      for (var server in servers) {
        final machineIdentifier = server['clientIdentifier'] as String;
        final connections = server['connections'] as List<dynamic>;
        final serverUrl = _plexService.getBestConnectionUrl(connections);
        
        if (serverUrl != null) {
          _serverUrls[machineIdentifier] = serverUrl;
        }
      }
      
      // Pass server URLs to audio service
      if (widget.audioPlayerService != null) {
        widget.audioPlayerService!.setServerUrls(_serverUrls);
      }
      
      if (_serverUrls.isNotEmpty) {
        _currentServerUrl = _serverUrls.values.first;
      }
    } catch (e) {
      // Silently fail - will fall back to current server URL
    }
  }

  void _sortTracks(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }

      SongsUtils.sortTracks(_tracks, column, _sortAscending);
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[SONGS] build() called - _isLoading: $_isLoading, tracks: ${_tracks.length}');
    final buildStartTime = DateTime.now();
    final result = Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _buildContent(),
    );
    final buildEndTime = DateTime.now();
    debugPrint('[SONGS] build() took: ${buildEndTime.difference(buildStartTime).inMilliseconds}ms');
    return result;
  }

  Widget _buildContent() {
    debugPrint('[SONGS] _buildContent() START - _isLoading: $_isLoading, tracks: ${_tracks.length}');
    
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTracks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tracks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No songs found', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SongsHeader(trackCount: _tracks.length),
        ),
        SliverToBoxAdapter(
          child: SongsActionButtons(
            tracks: _tracks,
            audioPlayerService: widget.audioPlayerService,
            currentToken: _currentToken,
            serverUrls: _serverUrls,
            currentServerUrl: _currentServerUrl,
          ),
        ),
        SliverToBoxAdapter(
          child: SongsTableHeader(
            sortColumn: _sortColumn,
            sortAscending: _sortAscending,
            onSort: _sortTracks,
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final track = _tracks[index];
              return TrackListItem(
                tracks: _tracks,
                track: track,
                index: index,
                isHovered: _hoveredIndex == index,
                onHoverEnter: () => setState(() => _hoveredIndex = index),
                onHoverExit: () => setState(() => _hoveredIndex = null),
                currentToken: _currentToken,
                serverUrls: _serverUrls,
                currentServerUrl: _currentServerUrl,
                audioPlayerService: widget.audioPlayerService,
                formatDuration: SongsUtils.formatDuration,
                formatDate: SongsUtils.formatDate,
              );
            },
            childCount: _tracks.length,
          ),
        ),
      ],
    );
  }
}
