import 'package:flutter/material.dart';
import '../../../core/services/audio_player_service.dart';

/// Compact play button shown in the sticky header when scrolling.
class StickyPlayButton extends StatelessWidget {
  final List<Map<String, dynamic>> tracks;
  final AudioPlayerService? audioPlayerService;
  final String? currentToken;
  final Map<String, String> serverUrls;
  final String? currentServerUrl;

  const StickyPlayButton({
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
      final serverUrl = serverId != null ? serverUrls[serverId] : currentServerUrl;
      
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

  @override
  Widget build(BuildContext context) {
    return Container(
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
        onPressed: _onPlayPressed,
      ),
    );
  }
}
