import 'package:flutter/material.dart';
import '../../../../core/models/track.dart';

class TrackOptionsSheet extends StatelessWidget {
  final Track track;
  final String? imageUrl;

  const TrackOptionsSheet({
    super.key,
    required this.track,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${track.artistName} • ${track.albumName}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: Colors.white10),
          const SizedBox(height: 8),

          // Actions
          _buildActionItem(
            context,
            icon: Icons.add_circle_outline,
            label: 'Add to other playlist',
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement Add to playlist
            },
          ),
          _buildActionItem(
            context,
            icon: Icons.queue_music,
            label: 'Add to Queue',
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement Add to Queue
            },
          ),
          _buildActionItem(
            context,
            icon: Icons.album,
            label: 'Go to album',
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement Go to album
            },
          ),
          _buildActionItem(
            context,
            icon: Icons.person_outline,
            label: 'Go to artist',
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement Go to artist
            },
          ),
          const SizedBox(height: 32), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      color: const Color(0xFF282828),
      child: const Icon(Icons.music_note, color: Colors.grey),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey[400]),
      title: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      visualDensity: VisualDensity.compact,
    );
  }
}
