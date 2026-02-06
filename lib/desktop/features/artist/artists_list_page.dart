import 'package:flutter/material.dart';
import 'package:apollo/core/models/artist.dart';
import 'package:apollo/core/database/database_service.dart';
import 'package:apollo/core/services/audio_player_service.dart';
import 'package:apollo/core/services/storage_service.dart';
import 'artist_page.dart';

/// Page displaying all artists in a grid with circular images.
class ArtistsListPage extends StatefulWidget {
  final void Function(Widget)? onNavigate;
  final AudioPlayerService? audioPlayerService;
  final VoidCallback? onHomeTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onProfileTap;

  const ArtistsListPage({
    super.key,
    this.onNavigate,
    this.audioPlayerService,
    this.onHomeTap,
    this.onSettingsTap,
    this.onProfileTap,
  });

  @override
  State<ArtistsListPage> createState() => _ArtistsListPageState();
}

class _ArtistsListPageState extends State<ArtistsListPage> {
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();

  List<Artist> _artists = [];
  bool _isLoading = true;
  String? _token;
  String? _serverUrl;
  int _hoveredIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final token = await _storageService.getPlexToken();
    final serverUrl = await _storageService.getSelectedServerUrl() ??
        await _storageService.getServerUrl();
    final artists = await _dbService.artists.getAll();

    if (mounted) {
      setState(() {
        _token = token;
        _serverUrl = serverUrl;
        _artists = artists;
        _isLoading = false;
      });
    }
  }

  void _navigateToArtist(Artist artist) {
    if (_token == null || _serverUrl == null || widget.onNavigate == null) return;

    widget.onNavigate!(ArtistPage(
      artistId: artist.ratingKey,
      artistName: artist.name,
      serverUrl: _serverUrl!,
      token: _token!,
      audioPlayerService: widget.audioPlayerService,
      onNavigate: widget.onNavigate,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Text(
                'Artists',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
            ),
          ),
          // Artist count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Text(
                '${_artists.length} artists',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
          ),
          // Artist grid
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final artist = _artists[index];
                  return _ArtistCard(
                    artist: artist,
                    serverUrl: _serverUrl,
                    token: _token,
                    isHovered: _hoveredIndex == index,
                    onHoverChanged: (hovered) {
                      setState(() => _hoveredIndex = hovered ? index : -1);
                    },
                    onTap: () => _navigateToArtist(artist),
                  );
                },
                childCount: _artists.length,
              ),
            ),
          ),
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }
}

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  final String? serverUrl;
  final String? token;
  final bool isHovered;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onTap;

  const _ArtistCard({
    required this.artist,
    required this.serverUrl,
    required this.token,
    required this.isHovered,
    required this.onHoverChanged,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isHovered ? Colors.grey[850] : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Circular artist image
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[800],
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    child: ClipOval(
                      child: _buildImage(),
                    ),
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
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              // Subtitle
              Text(
                'Artist',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (artist.thumb != null && serverUrl != null && token != null) {
      return Image.network(
        '$serverUrl${artist.thumb}?X-Plex-Token=$token',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[800],
      child: const Center(
        child: Icon(
          Icons.person,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );
  }
}
