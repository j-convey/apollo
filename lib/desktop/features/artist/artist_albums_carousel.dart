import 'package:flutter/material.dart';
import 'artist_album_card.dart';

/// A horizontal carousel displaying an artist's albums.
/// Follows Spotify-like design with section header and scrollable album cards.
class ArtistAlbumsCarousel extends StatelessWidget {
  /// List of album data maps from Plex API
  final List<Map<String, dynamic>> albums;

  /// The base server URL for building image URLs
  final String serverUrl;

  /// The Plex authentication token
  final String token;

  /// Callback when an album is tapped
  final void Function(Map<String, dynamic> album)? onAlbumTap;

  /// Optional section title (defaults to "Discography")
  final String title;

  const ArtistAlbumsCarousel({
    super.key,
    required this.albums,
    required this.serverUrl,
    required this.token,
    this.onAlbumTap,
    this.title = 'Discography',
  });

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (albums.length > 4)
                TextButton(
                  onPressed: () {
                    // TODO: Navigate to full discography view
                  },
                  child: Text(
                    'Show all',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Horizontal scrolling album list
        SizedBox(
          height: 230,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: albums.length,
            itemBuilder: (context, index) {
              final album = albums[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index < albums.length - 1 ? 16 : 0,
                ),
                child: ArtistAlbumCard(
                  album: album,
                  serverUrl: serverUrl,
                  token: token,
                  onTap: onAlbumTap != null ? () => onAlbumTap!(album) : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
