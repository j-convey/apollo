import 'package:flutter/material.dart';
import '../../core/models/artist.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/audio_player_service.dart';
import '../../core/database/database_service.dart';
import 'artist_page.dart';

/// Artists library page displaying all artists in a grid layout.
/// Inspired by Spotify's artist browsing design with circular images.
class ArtistsLibraryPage extends StatefulWidget {
  final AudioPlayerService? audioPlayerService;
  final void Function(Widget)? onNavigate;
  final VoidCallback? onHomeTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onProfileTap;

  const ArtistsLibraryPage({
    super.key,
    this.audioPlayerService,
    this.onNavigate,
    this.onHomeTap,
    this.onSettingsTap,
    this.onProfileTap,
  });

  @override
  State<ArtistsLibraryPage> createState() => _ArtistsLibraryPageState();
}

class _ArtistsLibraryPageState extends State<ArtistsLibraryPage> {
  final StorageService _storageService = StorageService();
  final DatabaseService _dbService = DatabaseService();

  List<Artist> _artists = [];
  bool _isLoading = true;
  String? _error;
  String? _currentToken;
  String? _currentServerUrl;

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  Future<void> _loadArtists() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load server credentials first
      await _loadServerCredentials();

      // Fetch all artists from database (already sorted alphabetically by repository)
      final artists = await _dbService.artists.getAll();

      if (artists.isNotEmpty) {
        if (mounted) {
          setState(() {
            _artists = artists;
            _isLoading = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _error =
              'No artists in library. Please go to Settings > Server Settings and tap "Sync Library" to download your music library.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ARTISTS_LIBRARY: Error loading artists: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading artists: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadServerCredentials() async {
    try {
      final token = await _storageService.getPlexToken();
      final serverUrl = await _storageService.getSelectedServerUrl();

      _currentToken = token;
      _currentServerUrl = serverUrl;

      debugPrint('ARTISTS_LIBRARY: Loaded server URL: $serverUrl');
    } catch (e) {
      debugPrint('ARTISTS_LIBRARY: Error loading server credentials: $e');
    }
  }

  String _buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return '';
    if (_currentServerUrl == null || _currentToken == null) return '';
    return '$_currentServerUrl$imagePath?X-Plex-Token=$_currentToken';
  }

  void _navigateToArtist(Artist artist) {
    if (widget.onNavigate == null) return;
    if (_currentServerUrl == null || _currentToken == null) {
      debugPrint('ARTISTS_LIBRARY: Cannot navigate - missing server credentials');
      return;
    }

    widget.onNavigate!(
      ArtistPage(
        artistId: artist.ratingKey,
        artistName: artist.name,
        serverUrl: _currentServerUrl!,
        token: _currentToken!,
        audioPlayerService: widget.audioPlayerService,
        onNavigate: widget.onNavigate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1DB954)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[600],
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadArtists,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  foregroundColor: Colors.black,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Artists',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_artists.length} artists',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Artists grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              childAspectRatio: 0.7,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildArtistCard(_artists[index]),
              childCount: _artists.length,
            ),
          ),
        ),

        // Bottom padding for player bar
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }

  Widget _buildArtistCard(Artist artist) {
    final imageUrl = _buildImageUrl(artist.thumb ?? artist.art);
    final hasImage = imageUrl.isNotEmpty;

    return InkWell(
      onTap: () => _navigateToArtist(artist),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Circular artist image
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholderIcon();
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              color: Colors.grey[600],
                              strokeWidth: 2,
                            ),
                          );
                        },
                      )
                    : _buildPlaceholderIcon(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Artist name
          Text(
            artist.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),

          // "Artist" label
          Text(
            'Artist',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: Colors.grey[800],
      child: Icon(
        Icons.person,
        size: 48,
        color: Colors.grey[600],
      ),
    );
  }
}
