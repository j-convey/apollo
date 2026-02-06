import 'package:flutter/material.dart';
import 'package:apollo/core/models/artist.dart';
import 'package:apollo/core/services/plex/plex_artist_service.dart';
import 'package:apollo/core/services/audio_player_service.dart';

/// Artist page displaying artist info and popular tracks.
/// Inspired by Spotify's artist page design.
class ArtistPage extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String serverUrl;
  final String token;
  final AudioPlayerService? audioPlayerService;
  final void Function(Widget)? onNavigate;

  const ArtistPage({
    super.key,
    required this.artistId,
    required this.artistName,
    required this.serverUrl,
    required this.token,
    this.audioPlayerService,
    this.onNavigate,
  });

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final PlexArtistService _artistService = PlexArtistService();

  Artist? _artist;
  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = true;
  bool _showAllTracks = false;
  int _hoveredTrackIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  @override
  void didUpdateWidget(ArtistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.artistId != oldWidget.artistId) {
      _loadArtistData();
    }
  }

  Future<void> _loadArtistData() async {
    setState(() => _isLoading = true);

    try {
      // Fetch artist details and tracks in parallel
      final results = await Future.wait([
        _artistService.getArtistDetails(
          artistId: widget.artistId,
          serverUrl: widget.serverUrl,
          token: widget.token,
        ),
        _artistService.getArtistTracks(
          artistId: widget.artistId,
          serverUrl: widget.serverUrl,
          token: widget.token,
        ),
      ]);

      setState(() {
        _artist = results[0] as Artist?;
        _tracks = results[1] as List<Map<String, dynamic>>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ARTIST_PAGE: Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int? milliseconds) {
    if (milliseconds == null) return '0:00';
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _buildImageUrl(String? imagePath) {
    if (imagePath == null) return '';
    return _artistService.buildImageUrl(
      imagePath: imagePath,
      serverUrl: widget.serverUrl,
      token: widget.token,
    );
  }

  void _playTrack(int index) async {
    if (widget.audioPlayerService == null) return;

    final allTracks = _tracks.map((track) {
      // Add grandparent info for navigation back to artist
      track['grandparentRatingKey'] = widget.artistId;
      track['grandparentTitle'] = _artist?.name ?? widget.artistName;
      track['grandparentThumb'] = _artist?.thumb;
      track['grandparentArt'] = _artist?.art;
      // Set artist field for player bar display
      track['artist'] = _artist?.name ?? widget.artistName;
      return track;
    }).toList();

    // Set the queue and play the selected track
    widget.audioPlayerService!.setPlayQueue(allTracks, index);
    await widget.audioPlayerService!.playTrack(
      allTracks[index],
      widget.token,
      widget.serverUrl,
    );
  }

  void _playAllTracks() {
    if (_tracks.isNotEmpty) {
      _playTrack(0);
    }
  }

  Future<void> _shufflePlay() async {
    if (_tracks.isEmpty || widget.audioPlayerService == null) return;

    final shuffledTracks = List<Map<String, dynamic>>.from(_tracks)..shuffle();
    for (var track in shuffledTracks) {
      track['grandparentRatingKey'] = widget.artistId;
      track['grandparentTitle'] = _artist?.name ?? widget.artistName;
      track['grandparentThumb'] = _artist?.thumb;
      track['grandparentArt'] = _artist?.art;
      // Set artist field for player bar display
      track['artist'] = _artist?.name ?? widget.artistName;
    }

    // Set the queue and play the first shuffled track
    widget.audioPlayerService!.setPlayQueue(shuffledTracks, 0);
    await widget.audioPlayerService!.playTrack(
      shuffledTracks[0],
      widget.token,
      widget.serverUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    return Container(
      color: const Color(0xFF121212),
      child: CustomScrollView(
        slivers: [
          // Hero header with artist image
          _buildHeroHeader(),

          // Action buttons (Play, Shuffle, Follow)
          SliverToBoxAdapter(child: _buildActionButtons()),

          // Popular section
          SliverToBoxAdapter(child: _buildPopularHeader()),

          // Track list
          _buildTrackList(),

          // Show more/less button
          SliverToBoxAdapter(child: _buildShowMoreButton()),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    final artistArt = _artist?.art ?? _artist?.thumb;
    final hasImage = artistArt != null;

    return SliverToBoxAdapter(
      child: Container(
        height: 340,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[800]!,
              const Color(0xFF121212),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background image with gradient overlay
            if (hasImage)
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.8),
                        const Color(0xFF121212),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.srcOver,
                  child: Image.network(
                    _buildImageUrl(artistArt),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(color: Colors.grey[900]);
                    },
                  ),
                ),
              ),

            // Artist name at bottom
            Positioned(
              left: 24,
              right: 24,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Verified badge (optional)
                  Row(
                    children: [
                      Icon(
                        Icons.verified,
                        color: Colors.blue[400],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Verified Artist',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Artist name
                  Text(
                    _artist?.name ?? widget.artistName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),

                  // Stats
                  Text(
                    '${_tracks.length} songs • ${_artist?.albumCount ?? 0} albums',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          // Play button
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFF1DB954),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.play_arrow, size: 32),
              color: Colors.black,
              onPressed: _playAllTracks,
            ),
          ),
          const SizedBox(width: 16),

          // Shuffle button
          IconButton(
            icon: const Icon(Icons.shuffle, size: 28),
            color: Colors.grey[400],
            onPressed: _shufflePlay,
          ),
          const SizedBox(width: 8),

          // Follow button
          OutlinedButton(
            onPressed: () {
              // TODO: Implement follow functionality
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[600]!),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Follow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),

          // More options
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 28),
            color: Colors.grey[400],
            onPressed: () {
              // TODO: Show more options menu
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPopularHeader() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text(
        'Popular',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTrackList() {
    final displayTracks =
        _showAllTracks ? _tracks : _tracks.take(5).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final track = displayTracks[index];
          final isHovered = _hoveredTrackIndex == index;

          return _buildTrackRow(track, index, isHovered);
        },
        childCount: displayTracks.length,
      ),
    );
  }

  Widget _buildTrackRow(Map<String, dynamic> track, int index, bool isHovered) {
    final thumbPath = track['thumb'] ?? track['parentThumb'];
    final duration = track['duration'] as int?;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTrackIndex = index),
      onExit: (_) => setState(() => _hoveredTrackIndex = -1),
      child: InkWell(
        onTap: () => _playTrack(index),
        child: Container(
          color: isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              // Track number or play icon
              SizedBox(
                width: 32,
                child: Center(
                  child: isHovered
                      ? const Icon(Icons.play_arrow, color: Colors.white, size: 20)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Album art thumbnail
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: thumbPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          _buildImageUrl(thumbPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.music_note,
                              color: Colors.grey,
                              size: 20,
                            );
                          },
                        ),
                      )
                    : const Icon(
                        Icons.music_note,
                        color: Colors.grey,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 16),

              // Track title and album
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track['title'] ?? 'Unknown Title',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (track['parentTitle'] != null)
                      Text(
                        track['parentTitle'],
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),

              // Duration
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
              ),

              // More options on hover
              if (isHovered)
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: IconButton(
                    icon: Icon(Icons.more_horiz, color: Colors.grey[400]),
                    onPressed: () {
                      // TODO: Show track options menu
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                )
              else
                const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShowMoreButton() {
    if (_tracks.length <= 5) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: TextButton(
        onPressed: () => setState(() => _showAllTracks = !_showAllTracks),
        child: Text(
          _showAllTracks ? 'Show less' : 'See more',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
