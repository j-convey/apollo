import 'package:flutter/material.dart';
import '../../core/services/audio_player_service.dart';
import '../../core/services/storage_service.dart';
import '../songs/songs_page.dart';
import '../playlists/playlists_page.dart';

class HomePage extends StatelessWidget {
  final Function(Widget)? onNavigate;
  final AudioPlayerService? audioPlayerService;
  final StorageService? storageService;
  final String? token;
  final String? serverUrl;

  const HomePage({
    super.key,
    this.onNavigate,
    this.audioPlayerService,
    this.storageService,
    this.token,
    this.serverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${_getTimeOfDay()}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 24),
            // Quick access tiles
            Row(
              children: [
                Expanded(
                  child: _QuickAccessTile(
                    icon: Icons.library_music,
                    label: 'Library',
                    color: Colors.purple,
                    onTap: () {
                      if (onNavigate != null) {
                        onNavigate!(SongsPage(audioPlayerService: audioPlayerService));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _QuickAccessTile(
                    icon: Icons.playlist_play,
                    label: 'Playlists',
                    color: Colors.blue,
                    onTap: () {
                      if (onNavigate != null) {
                        onNavigate!(PlaylistsPage(
                          onNavigate: onNavigate!,
                          audioPlayerService: audioPlayerService,
                        ));
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            // Recently played section (placeholder for future)
            Text(
              'Recently played',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 16),
            const Expanded(
              child: Center(
                child: Text(
                  'No recent activity',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }
}

class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 80,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
