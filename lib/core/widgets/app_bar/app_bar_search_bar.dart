import 'package:flutter/material.dart';
import '../../../core/database/database_service.dart';
import '../../services/audio_player_service.dart';
import '../../services/storage_service.dart';

class AppBarSearchBar extends StatefulWidget {
  final AudioPlayerService? audioPlayerService;
  final String? currentToken;
  final String? currentServerUrl;

  const AppBarSearchBar({
    super.key,
    this.audioPlayerService,
    this.currentToken,
    this.currentServerUrl,
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
  
  List<Map<String, dynamic>> _searchResults = [];
  OverlayEntry? _overlayEntry;
  String? _token;
  String? _serverUrl;

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
  }

  void _onSearchChanged() {
    final query = _controller.text;
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      _removeOverlay();
      return;
    }

    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    final results = await _dbService.searchTracks(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
      });
      if (results.isNotEmpty && _focusNode.hasFocus) {
        _showOverlay();
      } else {
        _removeOverlay();
      }
    }
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus && _searchResults.isNotEmpty) {
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
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final track = _searchResults[index];
                  return _buildSearchResultItem(track);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultItem(Map<String, dynamic> track) {
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

  void _playTrack(Map<String, dynamic> track) async {
    final token = _token ?? widget.currentToken;
    final serverUrl = _serverUrl ?? widget.currentServerUrl;
    
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
        constraints: const BoxConstraints(maxWidth: 364),
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
