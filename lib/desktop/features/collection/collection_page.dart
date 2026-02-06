import 'package:flutter/material.dart';
import 'package:apollo/core/services/audio_player_service.dart';
import 'widgets/collection_header.dart';
import 'widgets/collection_action_buttons.dart';
import 'widgets/collection_sticky_header_delegate.dart';
import 'widgets/collection_scrollbar.dart';
import 'widgets/collection_track_list_item.dart';
import 'package:apollo/core/utils/collection_utils.dart';

/// A reusable page for displaying collections of tracks.
/// Can be used for Library, Playlists, Albums, and Artist views.
class CollectionPage extends StatefulWidget {
  /// The title of the collection (e.g., "Library", "My Playlist", album name)
  final String title;

  /// Optional subtitle override. If null, defaults to "$title • $trackCount songs"
  final String? subtitle;

  /// The type of collection being displayed
  final CollectionType collectionType;

  /// The audio player service for playback
  final AudioPlayerService? audioPlayerService;

  /// The tracks to display. If null, will load from database for library.
  final List<Map<String, dynamic>>? tracks;

  /// Optional custom cover image widget
  final Widget? coverImage;

  /// Optional cover image URL
  final String? imageUrl;

  /// Optional gradient colors for the header
  final List<Color>? gradientColors;

  /// Callback to load tracks if not provided directly
  final Future<List<Map<String, dynamic>>> Function()? onLoadTracks;

  /// Current Plex token
  final String? currentToken;

  /// Map of server IDs to URLs
  final Map<String, String>? serverUrls;

  /// Current server URL
  final String? currentServerUrl;

  /// Error message to show when no tracks are available
  final String? emptyMessage;

  /// Navigation callback for album pages
  final void Function(Widget)? onNavigate;

  /// Home button callback
  final VoidCallback? onHomeTap;

  /// Settings button callback
  final VoidCallback? onSettingsTap;

  /// Profile button callback
  final VoidCallback? onProfileTap;

  const CollectionPage({
    super.key,
    required this.title,
    this.subtitle,
    this.collectionType = CollectionType.library,
    this.audioPlayerService,
    this.tracks,
    this.coverImage,
    this.imageUrl,
    this.gradientColors,
    this.onLoadTracks,
    this.currentToken,
    this.serverUrls,
    this.currentServerUrl,
    this.emptyMessage,
    this.onNavigate,
    this.onHomeTap,
    this.onSettingsTap,
    this.onProfileTap,
  });

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _tracks = [];
  bool _isLoading = true;
  String? _error;
  int? _hoveredIndex;
  double _scrollOffset = 0.0;

  // Fade animation for sticky header play button
  static const double _fadeStartOffset = 250.0;
  static const double _fadeEndOffset = 384.0;

  // Sorting state
  String _sortColumn = 'addedAt';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeTracks();
  }

  @override
  void didUpdateWidget(CollectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if tracks changed
    if (widget.tracks != oldWidget.tracks) {
      _initializeTracks();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    }
  }

  Future<void> _initializeTracks() async {
    debugPrint('[COLLECTION] ===== _initializeTracks START =====');
    debugPrint('[COLLECTION] tracks provided: ${widget.tracks != null ? widget.tracks!.length : 'null'}');
    debugPrint('[COLLECTION] onLoadTracks provided: ${widget.onLoadTracks != null}');
    debugPrint('[COLLECTION] collectionType: ${widget.collectionType}');
    
    if (widget.tracks != null && widget.tracks!.isNotEmpty) {
      debugPrint('[COLLECTION] First track album: ${widget.tracks![0]['album']}');
    }
    
    if (widget.tracks != null) {
      // Use provided tracks directly
      debugPrint('[COLLECTION] Using provided tracks: ${widget.tracks!.length} tracks');
      setState(() {
        _tracks = List.from(widget.tracks!);
        _isLoading = false;
      });
    } else if (widget.onLoadTracks != null) {
      // Load tracks using callback
      debugPrint('[COLLECTION] Calling onLoadTracks callback...');
      await _loadTracks();
    } else {
      debugPrint('[COLLECTION] No tracks or loader provided');
      setState(() {
        _error = widget.emptyMessage ?? 'No tracks available.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTracks() async {
    debugPrint('[COLLECTION] ===== _loadTracks START =====');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (widget.onLoadTracks != null) {
        debugPrint('[COLLECTION] Awaiting onLoadTracks callback...');
        final loadedTracks = await widget.onLoadTracks!();
        debugPrint('[COLLECTION] onLoadTracks returned ${loadedTracks.length} tracks');
        if (mounted) {
          setState(() {
            _tracks = loadedTracks;
            _isLoading = false;
          });
          debugPrint('[COLLECTION] Loaded ${_tracks.length} tracks into state');
        }
      }
    } catch (e) {
      debugPrint('[COLLECTION] ERROR loading tracks: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading tracks: $e';
          _isLoading = false;
        });
      }
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
      CollectionUtils.sortTracks(_tracks, column, _sortAscending);
    });
  }

  void _playFromStart() {
    if (_tracks.isNotEmpty &&
        widget.audioPlayerService != null &&
        _currentToken != null) {
      final track = _tracks[0];
      final serverId = track['serverId'] as String?;
      final serverUrl = serverId != null
          ? _serverUrls[serverId]
          : _currentServerUrl;

      if (serverUrl != null) {
        widget.audioPlayerService!.setPlayQueue(_tracks, 0);
        widget.audioPlayerService!.playTrack(
          track,
          _currentToken!,
          serverUrl,
        );
      }
    }
  }

  // Getters for server info - use widget values or defaults
  String? get _currentToken => widget.currentToken;
  Map<String, String> get _serverUrls => widget.serverUrls ?? {};
  String? get _currentServerUrl => widget.currentServerUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
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
            if (widget.onLoadTracks != null)
              ElevatedButton(
                onPressed: _loadTracks,
                child: const Text('Retry'),
              ),
          ],
        ),
      );
    }

    if (_tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.music_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              widget.emptyMessage ?? 'No songs found',
              style: const TextStyle(color: Colors.grey),
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
        CollectionScrollbar(
          scrollController: _scrollController,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: CollectionHeader(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  trackCount: _tracks.length,
                  collectionType: widget.collectionType,
                  coverImage: widget.coverImage,
                  imageUrl: widget.imageUrl,
                  gradientColors: widget.gradientColors,
                ),
              ),
              SliverToBoxAdapter(
                child: CollectionActionButtons(
                  tracks: _tracks,
                  audioPlayerService: widget.audioPlayerService,
                  currentToken: _currentToken,
                  serverUrls: _serverUrls,
                  currentServerUrl: _currentServerUrl,
                ),
              ),
              // Sticky header with column headers only
              SliverPersistentHeader(
                pinned: true,
                delegate: CollectionStickyHeaderDelegate(
                  minHeight: 48 + (playButtonOpacity > 0 ? 64 : 0),
                  maxHeight: 48 + (playButtonOpacity > 0 ? 64 : 0),
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  onSort: _sortTracks,
                  topPadding: playButtonOpacity > 0 ? 64.0 : 0.0,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = _tracks[index];
                    return CollectionTrackListItem(
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
                      formatDuration: CollectionUtils.formatDuration,
                      formatDate: CollectionUtils.formatDate,
                      onNavigate: widget.onNavigate,
                      onHomeTap: widget.onHomeTap,
                      onSettingsTap: widget.onSettingsTap,
                      onProfileTap: widget.onProfileTap,
                    );
                  },
                  childCount: _tracks.length,
                ),
              ),
            ],
          ),
        ),
        // Overlay play button at the very top that fades in
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
}
