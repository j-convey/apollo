import 'package:flutter/material.dart';
import 'package:apollo/core/services/audio_player_service.dart';
import 'widgets/album_header.dart';
import 'widgets/album_track_list_item.dart';
import 'widgets/album_action_buttons.dart';
import 'package:apollo/core/utils/collection_utils.dart';

/// Display widget for a single album with its tracks
class AlbumDisplay extends StatefulWidget {
  /// The title of the album
  final String title;

  /// Optional subtitle override
  final String? subtitle;

  /// The audio player service for playback
  final AudioPlayerService? audioPlayerService;

  /// The tracks to display
  final List<Map<String, dynamic>> tracks;

  /// Optional cover image URL
  final String? imageUrl;

  /// Optional gradient colors for the header
  final List<Color>? gradientColors;

  /// Current Plex token
  final String? currentToken;

  /// Map of server IDs to URLs
  final Map<String, String>? serverUrls;

  /// Current server URL
  final String? currentServerUrl;

  const AlbumDisplay({
    super.key,
    required this.title,
    this.subtitle,
    this.audioPlayerService,
    required this.tracks,
    this.imageUrl,
    this.gradientColors,
    this.currentToken,
    this.serverUrls,
    this.currentServerUrl,
  });

  @override
  State<AlbumDisplay> createState() => _AlbumDisplayState();
}

class _AlbumDisplayState extends State<AlbumDisplay> {
  late List<Map<String, dynamic>> _tracks;
  int? _hoveredIndex;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  // Fade animation for sticky header play button
  static const double _fadeStartOffset = 250.0;
  static const double _fadeEndOffset = 384.0;

  @override
  void initState() {
    super.initState();
    _tracks = List.from(widget.tracks);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  void _playFromStart() {
    if (_tracks.isNotEmpty &&
        widget.audioPlayerService != null &&
        widget.currentToken != null) {
      final track = _tracks[0];
      final serverId = track['serverId'] as String?;
      final serverUrl = serverId != null
          ? (widget.serverUrls?[serverId] ?? widget.currentServerUrl)
          : widget.currentServerUrl;

      if (serverUrl != null) {
        widget.audioPlayerService!.setPlayQueue(_tracks, 0);
        widget.audioPlayerService!.playTrack(
          track,
          widget.currentToken!,
          serverUrl,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.music_note, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No songs in this album',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    // Calculate opacity for the top play button
    double playButtonOpacity = 0.0;
    final range = _fadeEndOffset - _fadeStartOffset;
    if (range > 0) {
      if (_scrollOffset >= _fadeEndOffset) {
        playButtonOpacity = 1.0;
      } else if (_scrollOffset > _fadeStartOffset) {
        playButtonOpacity = ((_scrollOffset - _fadeStartOffset) / range).clamp(0.0, 1.0);
      }
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Album header
            SliverToBoxAdapter(
              child: AlbumHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                trackCount: _tracks.length,
                imageUrl: widget.imageUrl,
                gradientColors: widget.gradientColors,
              ),
            ),
            // Action buttons
            SliverToBoxAdapter(
              child: AlbumActionButtons(
                tracks: _tracks,
                audioPlayerService: widget.audioPlayerService,
                currentToken: widget.currentToken,
                serverUrls: widget.serverUrls ?? {},
                currentServerUrl: widget.currentServerUrl,
              ),
            ),
            // Track list header
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                color: const Color(0xFF121212),
                child: Row(
                  children: [
                    const SizedBox(width: 40),
                    const Expanded(
                      flex: 3,
                      child: Text(
                        'Title',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Expanded(
                      flex: 1,
                      child: Text(
                        'Duration',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: _hoveredIndex != null ? 56 : 16),
                  ],
                ),
              ),
            ),
            // Tracks list
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = _tracks[index];
                  return AlbumTrackListItem(
                    tracks: _tracks,
                    track: track,
                    index: index,
                    isHovered: _hoveredIndex == index,
                    onHoverEnter: () => setState(() => _hoveredIndex = index),
                    onHoverExit: () => setState(() => _hoveredIndex = null),
                    currentToken: widget.currentToken,
                    serverUrls: widget.serverUrls ?? {},
                    currentServerUrl: widget.currentServerUrl,
                    audioPlayerService: widget.audioPlayerService,
                    formatDuration: CollectionUtils.formatDurationNullable,
                    formatDate: CollectionUtils.formatDate,
                  );
                },
                childCount: _tracks.length,
              ),
            ),
            // Bottom padding for player bar
            const SliverToBoxAdapter(
              child: SizedBox(height: 100),
            ),
          ],
        ),
        // Overlay play button that fades in when scrolling
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: playButtonOpacity < 0.1,
            child: Opacity(
              opacity: playButtonOpacity,
              child: Container(
                color: const Color(0xFF121212),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1DB954),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.play_arrow, size: 24),
                        color: Colors.black,
                        padding: EdgeInsets.zero,
                        onPressed: _playFromStart,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get isHovered => _hoveredIndex != null;
}
