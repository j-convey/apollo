import 'package:flutter/material.dart';
import '../../../core/database/database_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/storage_service.dart';
import '../../../features/artist/artist_page.dart';

class AppBarSearchBar extends StatefulWidget {
  final AudioPlayerService? audioPlayerService;
  final String? currentToken;
  final String? currentServerUrl;
  final void Function(Widget)? onNavigate;

  const AppBarSearchBar({
    super.key,
    this.audioPlayerService,
    this.currentToken,
    this.currentServerUrl,
    this.onNavigate,
  });

  @override
  State<AppBarSearchBar> createState() => _AppBarSearchBarState();
}

class _AppBarSearchBarState extends State<AppBarSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final DatabaseService _dbService = DatabaseService();
  final StorageService _storageService = StorageService();
  final LayerLink _layerLink = LayerLink();
  
  List<Map<String, dynamic>> _trackResults = [];
  List<Map<String, dynamic>> _artistResults = [];
  OverlayEntry? _overlayEntry;
  String? _token;
  String? _serverUrl;
  Map<String, String> _serverUrls = {};

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _controller.addListener(_onSearchChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCredentials() async {
    _token = await _storageService.getPlexToken();
    _serverUrl = widget.currentServerUrl;
    _serverUrls = await _storageService.getServerUrlMap();
  }

  void _onSearchChanged() {
    final query = _controller.text;
    if (query.isEmpty) {
      setState(() {
        _trackResults = [];
        _artistResults = [];
      });
      _removeOverlay();
      return;
    }

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    final trackResults = await _dbService.searchTracks(query);
    final artistResults = await _dbService.searchArtists(query);
    
    if (mounted) {
      setState(() {
        _trackResults = trackResults;
        _artistResults = artistResults;
      });
      if ((trackResults.isNotEmpty || artistResults.isNotEmpty) && _focusNode.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && (_trackResults.isNotEmpty || _artistResults.isNotEmpty)) {
      _showOverlay();
    } else if (!_focusNode.hasFocus) {
      // Delay removal to allow clicking on results
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    var size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 8),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF282828),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                children: [
                  // Artists section
                  if (_artistResults.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        'Artists',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ..._artistResults.map((artist) => _buildArtistResultItem(artist)),
                    const SizedBox(height: 8),
                  ],
                  // Tracks section
                  if (_trackResults.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        'Songs',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ..._trackResults.map((track) => _buildTrackResultItem(track)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArtistResultItem(Map<String, dynamic> artist) {
    return InkWell(
      onTap: () {
        _navigateToArtist(artist);
        _controller.clear();
        _focusNode.unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Artist image
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                shape: BoxShape.circle,
              ),
              child: artist['artistThumb'] != null
                  ? ClipOval(
                      child: Image.network(
                        '${widget.currentServerUrl}${artist['artistThumb']}?X-Plex-Token=${widget.currentToken}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.person, color: Colors.grey);
                        },
                      ),
                    )
                  : const Icon(Icons.person, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            // Artist info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artist['artistName'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    'Artist',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
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

  Widget _buildTrackResultItem(Map<String, dynamic> track) {
    return InkWell(
      onTap: () {
        _playTrack(track);
        _controller.clear();
        _focusNode.unfocus();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Album art or music icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
              child: track['thumb'] != null && track['thumb'].toString().isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        '${widget.currentServerUrl}${track['thumb']}?X-Plex-Token=${widget.currentToken}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.music_note, color: Colors.grey);
                        },
                      ),
                    )
                  : const Icon(Icons.music_note, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            // Track info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track['title'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    '${track['artist']} • ${track['album']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
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

  void _navigateToArtist(Map<String, dynamic> artist) {
    final token = _token ?? widget.currentToken;
    final serverId = artist['serverId'] as String?;
    final serverUrl = serverId != null ? _serverUrls[serverId] : (widget.currentServerUrl ?? _serverUrl);
    
    if (widget.onNavigate != null && token != null && serverUrl != null) {
      final artistId = artist['artistId'] as String;
      final artistName = artist['artistName'] as String;
      
      widget.onNavigate!(
        ArtistPage(
          artistId: artistId,
          artistName: artistName,
          serverUrl: serverUrl,
          token: token,
          audioPlayerService: widget.audioPlayerService,
          onNavigate: widget.onNavigate,
        ),
      );
    }
  }

  void _playTrack(Map<String, dynamic> track) async {
    final token = _token ?? widget.currentToken;
    final serverId = track['serverId'] as String?;
    final serverUrl = serverId != null ? _serverUrls[serverId] : (widget.currentServerUrl ?? _serverUrl);
    
    if (widget.audioPlayerService != null && token != null && serverUrl != null) {
      // Get all tracks for queue context
      final allTracks = await _dbService.getAllTracks();
      final trackIndex = allTracks.indexWhere((t) => t['key'] == track['key']);
      
      widget.audioPlayerService!.setPlayQueue(allTracks, trackIndex >= 0 ? trackIndex : 0);
      widget.audioPlayerService!.playTrack(track, token, serverUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        height: 48,
        // Keep the search bar compact but usable; parent already constrains overall width
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 455),
        decoration: BoxDecoration(
          color: const Color(0xFF242424),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(
              Icons.search,
              color: Colors.grey[400],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
                decoration: InputDecoration(
                  hintText: 'What do you want to play?',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_controller.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, color: Colors.grey[400], size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _controller.clear();
                  _focusNode.unfocus();
                },
              ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
