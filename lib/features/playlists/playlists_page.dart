import 'package:flutter/material.dart';
import '../../core/models/playlists.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/audio_player_service.dart';
import '../collection/collection_page.dart';
import '../collection/widgets/collection_header.dart';
import 'playlist_service.dart';

class PlaylistsPage extends StatefulWidget {
  final Function(Widget) onNavigate;
  final AudioPlayerService? audioPlayerService;

  const PlaylistsPage({
    super.key,
    required this.onNavigate,
    this.audioPlayerService,
  });

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  final PlaylistService _playlistService = PlaylistService();
  final StorageService _storageService = StorageService();
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  String? _token;
  String? _serverUrl;

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _storageService.getPlexToken();
      
      debugPrint('PLAYLISTS PAGE: Token: ${token != null ? "exists" : "null"}');

      if (token == null || token.isEmpty) {
        await _loadLocalPlaylists('No token');
        return;
      }

      _token = token;

      // Get the stored server URL for the selected server
      final serverUrl = await _storageService.getSelectedServerUrl();
      
      debugPrint('PLAYLISTS PAGE: Server URL from storage: $serverUrl');

      if (serverUrl == null) {
        await _loadLocalPlaylists('No server URL saved - please select a library in Settings');
        return;
      }

      _serverUrl = serverUrl;

      debugPrint('PLAYLISTS PAGE: Syncing playlists from server');
      final playlists = await _playlistService.syncPlaylists(
        _serverUrl!,
        _token!,
      );
      debugPrint('PLAYLISTS PAGE: Synced ${playlists.length} playlists');
      
      if (mounted) {
        setState(() {
          _playlists = playlists;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('PLAYLISTS PAGE: Error loading playlists: $e');
      debugPrint('PLAYLISTS PAGE: Stack trace: $stackTrace');
      await _loadLocalPlaylists('Error: $e');
    }
  }

  Future<void> _loadLocalPlaylists(String reason) async {
    debugPrint('PLAYLISTS PAGE: $reason, loading local playlists');
    try {
      final localPlaylists = await _playlistService.getLocalPlaylists();
      debugPrint('PLAYLISTS PAGE: Loaded ${localPlaylists.length} local playlists');
      if (mounted) {
        setState(() {
          _playlists = localPlaylists;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PLAYLISTS PAGE: Failed to load local playlists: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_playlists.isEmpty) {
      return const Center(
        child: Text(
          'No playlists found',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          childAspectRatio: 1.0,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _playlists.length,
        itemBuilder: (context, index) {
          final playlist = _playlists[index];
          return _PlaylistCard(
            playlist: playlist,
            serverUrl: _serverUrl ?? '',
            token: _token ?? '',
            onTap: () => _navigateToPlaylist(playlist),
          );
        },
      ),
    );
  }

  void _navigateToPlaylist(Playlist playlist) {
    final imageUrl = playlist.composite != null
        ? '$_serverUrl${playlist.composite}?X-Plex-Token=$_token'
        : null;

    widget.onNavigate(
      _PlaylistDetailPage(
        playlist: playlist,
        serverUrl: _serverUrl!,
        token: _token!,
        imageUrl: imageUrl,
        audioPlayerService: widget.audioPlayerService,
        playlistService: _playlistService,
      ),
    );
  }
}

/// Wrapper page that loads playlist tracks and displays CollectionPage
class _PlaylistDetailPage extends StatefulWidget {
  final Playlist playlist;
  final String serverUrl;
  final String token;
  final String? imageUrl;
  final AudioPlayerService? audioPlayerService;
  final PlaylistService playlistService;

  const _PlaylistDetailPage({
    required this.playlist,
    required this.serverUrl,
    required this.token,
    this.imageUrl,
    this.audioPlayerService,
    required this.playlistService,
  });

  @override
  State<_PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<_PlaylistDetailPage> {
  List<Map<String, dynamic>>? _tracks;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlaylistTracks();
  }

  Future<void> _loadPlaylistTracks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tracks = await widget.playlistService.getPlaylistTracks(
        widget.serverUrl,
        widget.token,
        widget.playlist.id,
      );

      if (mounted) {
        setState(() {
          _tracks = tracks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading playlist: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                onPressed: _loadPlaylistTracks,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return CollectionPage(
      title: widget.playlist.title,
      subtitle: '${widget.playlist.leafCount} songs',
      collectionType: CollectionType.playlist,
      audioPlayerService: widget.audioPlayerService,
      tracks: _tracks,
      imageUrl: widget.imageUrl,
      currentToken: widget.token,
      serverUrls: {}, // Playlist tracks don't need server mapping
      currentServerUrl: widget.serverUrl,
      emptyMessage: 'This playlist is empty.',
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final Playlist playlist;
  final String serverUrl;
  final String token;
  final VoidCallback onTap;

  const _PlaylistCard({
    required this.playlist,
    required this.serverUrl,
    required this.token,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = playlist.composite != null
        ? '$serverUrl${playlist.composite}?X-Plex-Token=$token'
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                  image: imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageUrl == null
                    ? const Icon(Icons.music_note, size: 64, color: Colors.white24)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            playlist.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${playlist.leafCount} tracks',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}