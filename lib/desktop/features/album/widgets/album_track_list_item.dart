import 'package:flutter/material.dart';
import 'package:apollo/core/services/audio_player_service.dart';

/// A single track list item for album pages.
class AlbumTrackListItem extends StatefulWidget {
  final List<Map<String, dynamic>> tracks;
  final Map<String, dynamic> track;
  final int index;
  final bool isHovered;
  final VoidCallback onHoverEnter;
  final VoidCallback onHoverExit;
  final String? currentToken;
  final Map<String, String> serverUrls;
  final String? currentServerUrl;
  final AudioPlayerService? audioPlayerService;
  final String Function(int?) formatDuration;
  final String Function(int?) formatDate;

  const AlbumTrackListItem({
    super.key,
    required this.tracks,
    required this.track,
    required this.index,
    required this.isHovered,
    required this.onHoverEnter,
    required this.onHoverExit,
    required this.currentToken,
    required this.serverUrls,
    required this.currentServerUrl,
    required this.audioPlayerService,
    required this.formatDuration,
    required this.formatDate,
  });

  @override
  State<AlbumTrackListItem> createState() => _AlbumTrackListItemState();
}

class _AlbumTrackListItemState extends State<AlbumTrackListItem> {
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: InkWell(
        onTap: () => _onTrackTapped(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: widget.isHovered ? Colors.grey[900] : Colors.transparent,
          child: Row(
            children: [
              // Track number or play button
              SizedBox(
                width: 40,
                child: widget.isHovered
                    ? const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${widget.index + 1}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
              ),
              // Track info (no album art for album view)
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.track['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      widget.track['artist'] as String,
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
              // Duration
              Expanded(
                flex: 1,
                child: Text(
                  widget.formatDuration(widget.track['duration'] as int?),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (widget.isHovered) ...[
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.more_horiz, size: 20),
                  color: Colors.grey[400],
                  onPressed: () {
                    // TODO: Show context menu
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onTrackTapped() {
    debugPrint('ALBUM_TRACK_ITEM: ===== Track tapped: ${widget.track['title']} =====');
    if (widget.audioPlayerService != null && widget.currentToken != null) {
      // Get the correct server URL based on the track's serverId
      final trackServerId = widget.track['serverId'] as String?;
      final trackServerUrl = trackServerId != null && widget.serverUrls.containsKey(trackServerId)
          ? widget.serverUrls[trackServerId]!
          : widget.currentServerUrl;

      if (trackServerUrl == null) {
        debugPrint('ALBUM_TRACK_ITEM: ERROR - No server URL found for track (serverId: $trackServerId)');
        return;
      }

      debugPrint('ALBUM_TRACK_ITEM: Track serverId: $trackServerId');
      debugPrint('ALBUM_TRACK_ITEM: Using server URL: $trackServerUrl');
      debugPrint('ALBUM_TRACK_ITEM: Calling setPlayQueue with ${widget.tracks.length} tracks, index ${widget.index}');

      final startTime = DateTime.now();
      widget.audioPlayerService!.setPlayQueue(widget.tracks, widget.index);
      final endTime = DateTime.now();
      debugPrint('ALBUM_TRACK_ITEM: setPlayQueue took ${endTime.difference(startTime).inMilliseconds}ms');

      debugPrint('ALBUM_TRACK_ITEM: Calling playTrack');
      final playStartTime = DateTime.now();
      widget.audioPlayerService!.playTrack(
        widget.track,
        widget.currentToken!,
        trackServerUrl,
      );
      final playEndTime = DateTime.now();
      debugPrint('ALBUM_TRACK_ITEM: playTrack call returned in ${playEndTime.difference(playStartTime).inMilliseconds}ms');
    } else {
      debugPrint('ALBUM_TRACK_ITEM: Missing required data - service: ${widget.audioPlayerService != null}, token: ${widget.currentToken != null}');
    }
  }
}
