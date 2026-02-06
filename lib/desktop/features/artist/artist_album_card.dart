import 'package:flutter/material.dart';

/// A card widget displaying an album in the artist page carousel.
/// Follows Spotify-like design with hover effects and album art.
class ArtistAlbumCard extends StatefulWidget {
  /// Album data map from Plex API
  final Map<String, dynamic> album;

  /// The base server URL for building image URLs
  final String serverUrl;

  /// The Plex authentication token
  final String token;

  /// Callback when the album is tapped
  final VoidCallback? onTap;

  const ArtistAlbumCard({
    super.key,
    required this.album,
    required this.serverUrl,
    required this.token,
    this.onTap,
  });

  @override
  State<ArtistAlbumCard> createState() => _ArtistAlbumCardState();
}

class _ArtistAlbumCardState extends State<ArtistAlbumCard> {
  bool _isHovered = false;

  String _buildImageUrl(String? thumbPath) {
    if (thumbPath == null) return '';
    final cleanUrl = widget.serverUrl.replaceAll(RegExp(r'/$'), '');
    final cleanPath = thumbPath.replaceAll(RegExp(r'^/'), '');
    return '$cleanUrl/$cleanPath?X-Plex-Token=${widget.token}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.album['title'] as String? ?? 'Unknown Album';
    final year = widget.album['year'] as int?;
    final thumbPath = widget.album['thumb'] as String?;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0xFF282828)
                : const Color(0xFF181818),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Album cover with play button overlay on hover
              Stack(
                children: [
                  // Album art
                  Container(
                    width: 136,
                    height: 136,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: thumbPath != null
                          ? Image.network(
                              _buildImageUrl(thumbPath),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.album,
                                  color: Colors.grey,
                                  size: 48,
                                );
                              },
                            )
                          : const Icon(
                              Icons.album,
                              color: Colors.grey,
                              size: 48,
                            ),
                    ),
                  ),

                  // Play button on hover
                  if (_isHovered)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1DB954),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.black,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Album title
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Year
              if (year != null)
                Text(
                  '$year',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 13,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
