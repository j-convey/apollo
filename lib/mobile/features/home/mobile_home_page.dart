import 'package:flutter/material.dart';
import 'widgets/home_nav_bar.dart';

/// Mobile home page with quick access buttons matching the desktop layout.
class MobileHomePage extends StatelessWidget {
  final VoidCallback? onNavigateToLibrary;
  final VoidCallback? onOpenDrawer;
  
  const MobileHomePage({
    super.key,
    this.onNavigateToLibrary,
    this.onOpenDrawer,
  });

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top navigation bar with profile and filters
            HomeNavBar(onOpenDrawer: onOpenDrawer),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Good ${_getTimeOfDay()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Quick access grid - 2 columns
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3,
                      children: [
                        _QuickAccessTile(
                          icon: Icons.library_music,
                          label: 'Library',
                          color: Colors.purple,
                          onTap: () {
                            onNavigateToLibrary?.call();
                          },
                        ),
                        _QuickAccessTile(
                          icon: Icons.playlist_play,
                          label: 'Playlists',
                          color: Colors.blue,
                          onTap: () {
                            // TODO: Navigate to playlists
                          },
                        ),
                        _QuickAccessTile(
                          icon: Icons.person,
                          label: 'Artists',
                          color: Colors.orange,
                          onTap: () {
                            // TODO: Navigate to artists
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Recently played',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
            ),
          ],
        ),
      ),
    );
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
