import 'package:flutter/material.dart';
import 'package:apollo/core/services/audio_player_service.dart';
import 'package:apollo/core/services/plex/plex_services.dart';
import 'package:apollo/core/database/database_service.dart';
import 'package:apollo/desktop/features/artist/artist_page.dart';

class PlayerBar extends StatefulWidget {
  final AudioPlayerService playerService;
  final void Function(Widget)? onNavigate;

  const PlayerBar({
    super.key,
    required this.playerService,
    this.onNavigate,
  });

  @override
  State<PlayerBar> createState() => _PlayerBarState();
}

class _PlayerBarState extends State<PlayerBar> {
  late double _currentVolume;
  final PlexServerService _serverService = PlexServerService();
  final DatabaseService _dbService = DatabaseService();
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _currentVolume = 0.7;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.playerService,
      builder: (context, child) {
        final track = widget.playerService.currentTrack;
        
        if (track == null) {
          return const SizedBox.shrink();
        }

        // Check like status from track data
        final userRating = track['user_rating'] as double?;
        _isLiked = userRating != null && userRating >= 10.0;

        return Container(
          height: 90,
          decoration: const BoxDecoration(
            color: Colors.black,
            border: Border(
              top: BorderSide(color: Colors.black),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Left section: Track info (30%)
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      // Album art
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: track['thumb'] != null &&
                                widget.playerService.currentServerUrl != null &&
                                widget.playerService.currentToken != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  '${widget.playerService.currentServerUrl}${track['thumb']}?X-Plex-Token=${widget.playerService.currentToken}',
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.music_note,
                                      color: Colors.grey,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.music_note,
                                color: Colors.grey,
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Track details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              track['title'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final artistId = track['grandparentRatingKey']?.toString();
                                final artistName = track['artist'] as String? ??
                                    track['grandparentTitle'] as String? ??
                                    'Unknown Artist';
                                final token = widget.playerService.currentToken;
                                final trackServerId = track['serverId'] as String?;

                                // Use centralized server URL lookup
                                String? serverUrl = widget.playerService.currentServerUrl;
                                if (token != null && trackServerId != null) {
                                  try {
                                    serverUrl = await _serverService.getUrlForServer(token, trackServerId);
                                    debugPrint('PLAYER_BAR: Got URL for server $trackServerId: $serverUrl');
                                  } catch (e) {
                                    debugPrint('PLAYER_BAR: Error getting server URL: $e');
                                  }
                                }
                                
                                // Fallback to current server URL if lookup failed
                                serverUrl ??= widget.playerService.currentServerUrl;

                                debugPrint('PLAYER_BAR: Artist tap - artistId: $artistId, serverUrl: $serverUrl, token exists: ${token != null}');

                                if (artistId != null &&
                                    serverUrl != null &&
                                    token != null &&
                                    widget.onNavigate != null) {
                                  debugPrint('PLAYER_BAR: Navigating to artist page for: $artistName with serverUrl: $serverUrl');
                                  widget.onNavigate!(
                                    ArtistPage(
                                      artistId: artistId,
                                      artistName: artistName,
                                      serverUrl: serverUrl,
                                      token: token,
                                      audioPlayerService: widget.playerService,
                                      onNavigate: widget.onNavigate,
                                    ),
                                  );
                                } else {
                                  debugPrint('PLAYER_BAR: Cannot navigate - missing data. artistId: $artistId, serverUrl: $serverUrl, token: ${token != null}, onNavigate: ${widget.onNavigate != null}');
                                }
                              },
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Text(
                                  track['artist'] as String? ?? 'Unknown Artist',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Like button
                      IconButton(
                        icon: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                        ),
                        color: _isLiked ? Colors.green : Colors.grey[400],
                        onPressed: () async {
                          final ratingKey = track['ratingKey']?.toString() ??
                              track['rating_key']?.toString();
                          if (ratingKey == null) return;

                          final newRating = _isLiked ? 0.0 : 10.0;
                          await _dbService.tracks.updateRating(ratingKey, newRating);

                          // Update the track map so the UI reflects the change
                          track['user_rating'] = newRating;
                          setState(() {
                            _isLiked = !_isLiked;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                
                // Center section: Playback controls (40%)
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Control buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Shuffle button
                          IconButton(
                            icon: const Icon(Icons.shuffle, size: 16),
                            color: Colors.grey[400],
                            onPressed: () {
                              // TODO: Implement shuffle
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          // Previous button
                          IconButton(
                            icon: const Icon(Icons.skip_previous, size: 28),
                            color: Colors.white,
                            onPressed: () {
                              widget.playerService.previous();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          // Play/Pause button
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                widget.playerService.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                size: 18,
                              ),
                              color: Colors.black,
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                widget.playerService.togglePlayPause();
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Next button
                          IconButton(
                            icon: const Icon(Icons.skip_next, size: 28),
                            color: Colors.white,
                            onPressed: () {
                              widget.playerService.next();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 16),
                          // Repeat button
                          IconButton(
                            icon: const Icon(Icons.repeat, size: 16),
                            color: Colors.grey[400],
                            onPressed: () {
                              // TODO: Implement repeat
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress bar with time stamps
                      Row(
                        children: [
                          // Current time
                          Text(
                            _formatDuration(widget.playerService.position),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Progress bar
                          Expanded(
                            child: SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 4,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                                thumbColor: Colors.white,
                                activeTrackColor: Colors.white,
                                inactiveTrackColor: Colors.grey[700],
                              ),
                              child: Slider(
                                value: widget.playerService.position.inSeconds.toDouble(),
                                max: widget.playerService.duration.inSeconds.toDouble() > 0
                                    ? widget.playerService.duration.inSeconds.toDouble()
                                    : 1.0,
                                onChanged: (value) {
                                  widget.playerService.seek(Duration(seconds: value.toInt()));
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Total duration
                          Text(
                            _formatDuration(widget.playerService.duration),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Right section: Additional controls (30%)
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.queue_music, size: 20),
                        color: Colors.grey[400],
                        onPressed: () {
                          // TODO: Implement queue
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.devices, size: 20),
                        color: Colors.grey[400],
                        onPressed: () {
                          // TODO: Implement connect to device
                        },
                      ),
                      // Volume control
                      Icon(
                        _currentVolume == 0 
                          ? Icons.volume_mute 
                          : _currentVolume < 0.5 
                            ? Icons.volume_down 
                            : Icons.volume_up,
                        size: 20,
                        color: _currentVolume == 0 ? Colors.red : Colors.grey[400],
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            thumbColor: Colors.white,
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.grey[700],
                          ),
                          child: Slider(
                            value: _currentVolume,
                            min: 0.0,
                            max: 1.0,
                            onChanged: (value) {
                              setState(() {
                                _currentVolume = value;
                              });
                              widget.playerService.setVolume(value);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.fullscreen, size: 20),
                        color: Colors.grey[400],
                        onPressed: () {
                          // TODO: Implement fullscreen/miniplayer
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
