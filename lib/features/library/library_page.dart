import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/audio_player_service.dart';
import '../../../core/database/database_service.dart';
import '../collection/collection_page.dart';
import '../collection/widgets/collection_header.dart';

/// Library page that displays the user's entire library.
/// Uses the reusable CollectionPage component.
class LibraryPage extends StatefulWidget {
  final AudioPlayerService? audioPlayerService;
  final void Function(Widget)? onNavigate;
  final VoidCallback? onHomeTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onProfileTap;

  const LibraryPage({
    super.key,
    this.audioPlayerService,
    this.onNavigate,
    this.onHomeTap,
    this.onSettingsTap,
    this.onProfileTap,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final StorageService _storageService = StorageService();
  final DatabaseService _dbService = DatabaseService();

  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = true;
  String? _error;
  String? _currentToken;
  String? _currentServerUrl;
  Map<String, String> _serverUrls = {};

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    debugPrint('[LIBRARY] ===== _loadTracks() START =====');
    final startTime = DateTime.now();
    setState(() {
      debugPrint('[LIBRARY] setState: Setting _isLoading = true');
      _isLoading = true;
      _error = null;
    });

    try {
      debugPrint('[LIBRARY] Querying database...');
      final dbStartTime = DateTime.now();
      // Use new type-safe repository pattern
      final trackModels = await _dbService.tracks.getAll();
      // Convert to maps for UI compatibility
      final cachedTracks = trackModels.map((t) => t.toJson()).toList();
      final dbEndTime = DateTime.now();
      debugPrint(
        '[LIBRARY] Database query took: ${dbEndTime.difference(dbStartTime).inMilliseconds}ms',
      );
      debugPrint(
        '[LIBRARY] Retrieved ${cachedTracks.length} tracks from database',
      );

      if (cachedTracks.isNotEmpty) {
        if (mounted) {
          debugPrint(
            '[LIBRARY] Setting ${cachedTracks.length} tracks in state...',
          );
          final setStateStartTime = DateTime.now();
          setState(() {
            _tracks = cachedTracks;
            _isLoading = false;
          });
          final setStateEndTime = DateTime.now();
          debugPrint(
            '[LIBRARY] setState completed in: ${setStateEndTime.difference(setStateStartTime).inMilliseconds}ms',
          );
        }

        debugPrint('[LIBRARY] Loading server URLs...');
        await _loadServerUrls();
        final endTime = DateTime.now();
        debugPrint(
          '[LIBRARY] ===== _loadTracks() COMPLETE in ${endTime.difference(startTime).inMilliseconds}ms =====',
        );
        return;
      }

      if (mounted) {
        setState(() {
          _error =
              'No songs in library. Please go to Settings > Server Settings and tap "Sync Library" to download your music library.';
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

      // Use the single selected server URL
      final serverUrl = await _storageService.getSelectedServerUrl();
      final serverId = await _storageService.getSelectedServer();

      if (serverUrl != null && serverId != null) {
        _serverUrls = {serverId: serverUrl};
        _currentServerUrl = serverUrl;
        debugPrint('LIBRARY_PAGE: Using selected server URL: $serverUrl');
      } else {
        debugPrint('LIBRARY_PAGE: No server selected yet');
      }

      // Pass server URLs to audio service
      if (widget.audioPlayerService != null) {
        widget.audioPlayerService!.setServerUrls(_serverUrls);
      }

      // Trigger rebuild with server URLs
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('LIBRARY_PAGE: Error loading server URLs: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[LIBRARY] build() called - _isLoading: $_isLoading, tracks: ${_tracks.length}',
    );

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(
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
        ),
      );
    }

    return CollectionPage(
      title: 'Library',
      subtitle: 'Library • ${_tracks.length} songs',
      collectionType: CollectionType.library,
      audioPlayerService: widget.audioPlayerService,
      tracks: _tracks,
      currentToken: _currentToken,
      serverUrls: _serverUrls,
      currentServerUrl: _currentServerUrl,
      emptyMessage:
          'No songs in library. Please go to Settings > Server Settings and tap "Sync Library" to download your music library.',
      onNavigate: widget.onNavigate,
      onHomeTap: widget.onHomeTap,
      onSettingsTap: widget.onSettingsTap,
      onProfileTap: widget.onProfileTap,
    );
  }
}
