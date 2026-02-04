import 'package:flutter/material.dart';
import '../../../core/services/audio_player_service.dart';

/// A single track list item for collection pages.
/// Displays track info and handles play interactions.
class CollectionTrackListItem extends StatelessWidget {
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
  final String Function(int) formatDuration;
  final String Function(int?) formatDate;

  const CollectionTrackListItem({
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
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => onHoverEnter(),
      onExit: (_) => onHoverExit(),
      child: InkWell(
        onTap: () => _onTrackTapped(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: isHovered ? Colors.grey[900] : Colors.transparent,
          child: Row(
            children: [
              // # or play button
              SizedBox(
                width: 40,
                child: isHovered
                    ? const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
              ),
              // Title with album art and artist
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    _buildAlbumArt(),
                    const SizedBox(width: 12),
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
                            ),
                          ),
                          Text(
                            track['artist'] as String,
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
              // Album
              Expanded(
                flex: 2,
                child: Text(
                  track['album'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
              // Date added
              Expanded(
                flex: 1,
                child: Text(
                  formatDate(track['addedAt'] as int?),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),
              // Duration
              SizedBox(
                width: 110,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isHovered) ...[
                      IconButton(
                        icon: const Icon(Icons.favorite_border, size: 18),
                        color: Colors.grey[400],
                        onPressed: () {
                          // TODO: Like song
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      formatDuration(track['duration'] as int),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    if (isHovered) ...[
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
            ],
          ),
        ),
      ),
    );
  }

  void _onTrackTapped() {
    debugPrint('TRACK_ITEM: ===== Track tapped: ${track['title']} =====');
    if (audioPlayerService != null && currentToken != null) {
      // Get the correct server URL based on the track's serverId
      final trackServerId = track['serverId'] as String?;
      final trackServerUrl = trackServerId != null && serverUrls.containsKey(trackServerId)
          ? serverUrls[trackServerId]!
          : currentServerUrl;

      if (trackServerUrl == null) {
        debugPrint('TRACK_ITEM: ERROR - No server URL found for track (serverId: $trackServerId)');
        return;
      }

      debugPrint('TRACK_ITEM: Track serverId: $trackServerId');
      debugPrint('TRACK_ITEM: Using server URL: $trackServerUrl');
      debugPrint('TRACK_ITEM: Calling setPlayQueue with ${tracks.length} tracks, index $index');

      final startTime = DateTime.now();
      audioPlayerService!.setPlayQueue(tracks, index);
      final endTime = DateTime.now();
      debugPrint('TRACK_ITEM: setPlayQueue took ${endTime.difference(startTime).inMilliseconds}ms');

      debugPrint('TRACK_ITEM: Calling playTrack');
      final playStartTime = DateTime.now();
      audioPlayerService!.playTrack(
        track,
        currentToken!,
        trackServerUrl,
      );
      final playEndTime = DateTime.now();
      debugPrint('TRACK_ITEM: playTrack call returned in ${playEndTime.difference(playStartTime).inMilliseconds}ms');
    } else {
      debugPrint('TRACK_ITEM: Missing required data - service: ${audioPlayerService != null}, token: ${currentToken != null}');
    }
  }

  Widget _buildAlbumArt() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(4),
      ),
      child: track['thumb'] != null && currentToken != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Builder(
                builder: (context) {
                  final serverId = track['serverId'] as String?;
                  final serverUrl = serverId != null ? serverUrls[serverId] : currentServerUrl;

                  if (serverUrl == null) {
                    return const Icon(
                      Icons.music_note,
                      color: Colors.grey,
                      size: 20,
                    );
                  }

                  return Image.network(
                    '$serverUrl${track['thumb']}?X-Plex-Token=$currentToken',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.music_note,
                        color: Colors.grey,
                        size: 20,
                      );
                    },
                  );
                },
              ),
            )
          : const Icon(
              Icons.music_note,
              color: Colors.grey,
              size: 20,
            ),
    );
  }
}
