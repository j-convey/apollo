import 'package:flutter/material.dart';
import 'package:apollo/core/services/audio_player_service.dart';

/// Action buttons for album pages (Play, Shuffle, Download)
class AlbumActionButtons extends StatelessWidget {
  final List<Map<String, dynamic>> tracks;
  final AudioPlayerService? audioPlayerService;
  final String? currentToken;
  final Map<String, String> serverUrls;
  final String? currentServerUrl;

  const AlbumActionButtons({
    super.key,
    required this.tracks,
    required this.audioPlayerService,
    required this.currentToken,
    required this.serverUrls,
    required this.currentServerUrl,
  });

  void _onPlayPressed() {
    if (tracks.isNotEmpty &&
        audioPlayerService != null &&
        currentToken != null) {
      final track = tracks[0];
      final serverId = track['serverId'] as String?;
      final serverUrl = serverId != null
          ? serverUrls[serverId]
          : currentServerUrl;

      if (serverUrl != null) {
        audioPlayerService!.setPlayQueue(tracks, 0);
        audioPlayerService!.playTrack(
          track,
          currentToken!,
          serverUrl,
        );
      }
    }
  }

  void _onShufflePressed() {
    if (tracks.isNotEmpty &&
        audioPlayerService != null &&
        currentToken != null) {
      final shuffledTracks = List<Map<String, dynamic>>.from(tracks)..shuffle();
      final track = shuffledTracks[0];
      final serverId = track['serverId'] as String?;
      final serverUrl = serverId != null
          ? serverUrls[serverId]
          : currentServerUrl;

      if (serverUrl != null) {
        audioPlayerService!.setPlayQueue(shuffledTracks, 0);
        audioPlayerService!.playTrack(
          track,
          currentToken!,
          serverUrl,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.0), Colors.black.withValues(alpha: 0.3), Colors.black],
        ),
      ),
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
              icon: const Icon(Icons.play_arrow, size: 28),
              color: Colors.black,
              padding: EdgeInsets.zero,
              onPressed: _onPlayPressed,
            ),
          ),
          const SizedBox(width: 16),
          // Shuffle button
          IconButton(
            icon: const Icon(Icons.shuffle, size: 24),
            color: Colors.grey[400],
            onPressed: _onShufflePressed,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          // More options button
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 24),
            color: Colors.grey[400],
            onPressed: () {
              // TODO: Show more options
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
