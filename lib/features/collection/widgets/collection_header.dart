import 'package:flutter/material.dart';

/// Represents the type of collection being displayed
enum CollectionType {
  library,
  playlist,
  album,
  artist,
}

/// Header widget for collection pages (Library, Playlist, Album, Artist)
/// Displays the cover image, title, subtitle, and track count
class CollectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int trackCount;
  final CollectionType collectionType;
  final Widget? coverImage;
  final String? imageUrl;
  final List<Color>? gradientColors;

  const CollectionHeader({
    super.key,
    required this.title,
    required this.trackCount,
    this.subtitle,
    this.collectionType = CollectionType.library,
    this.coverImage,
    this.imageUrl,
    this.gradientColors,
  });

  String get _typeLabel {
    switch (collectionType) {
      case CollectionType.library:
        return 'Playlist';
      case CollectionType.playlist:
        return 'Playlist';
      case CollectionType.album:
        return 'Album';
      case CollectionType.artist:
        return 'Artist';
    }
  }

  List<Color> get _defaultGradientColors {
    switch (collectionType) {
      case CollectionType.library:
        return [
          Colors.purple.shade700,
          Colors.purple.shade900,
          Colors.black,
        ];
      case CollectionType.playlist:
        return [
          Colors.indigo.shade700,
          Colors.indigo.shade900,
          Colors.black,
        ];
      case CollectionType.album:
        return [
          Colors.teal.shade700,
          Colors.teal.shade900,
          Colors.black,
        ];
      case CollectionType.artist:
        return [
          Colors.orange.shade700,
          Colors.orange.shade900,
          Colors.black,
        ];
    }
  }

  Widget get _defaultCoverImage {
    switch (collectionType) {
      case CollectionType.library:
        return Container(
          width: 232,
          height: 232,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue.shade300,
                Colors.purple.shade400,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite,
            size: 80,
            color: Colors.white,
          ),
        );
      case CollectionType.playlist:
        return Container(
          width: 232,
          height: 232,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.queue_music,
            size: 80,
            color: Colors.white,
          ),
        );
      case CollectionType.album:
        return Container(
          width: 232,
          height: 232,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.album,
            size: 80,
            color: Colors.white,
          ),
        );
      case CollectionType.artist:
        return Container(
          width: 232,
          height: 232,
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person,
            size: 80,
            color: Colors.white,
          ),
        );
    }
  }

  Widget _buildCoverImage() {
    if (coverImage != null) {
      return coverImage!;
    }

    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Container(
        width: 232,
        height: 232,
        decoration: BoxDecoration(
          borderRadius: collectionType == CollectionType.artist
              ? BorderRadius.circular(116)
              : BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: collectionType == CollectionType.artist
              ? BorderRadius.circular(116)
              : BorderRadius.zero,
          child: Image.network(
            imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _defaultCoverImage,
          ),
        ),
      );
    }

    return _defaultCoverImage;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradientColors ?? _defaultGradientColors,
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Cover Image
          _buildCoverImage(),
          const SizedBox(width: 24),
          // Title and Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _typeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, size: 14, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      subtitle ?? '$title • $trackCount songs',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
