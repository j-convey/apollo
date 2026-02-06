import 'package:flutter/material.dart';
import 'package:apollo/core/services/audio_player_service.dart';
import 'package:apollo/core/services/plex/plex_services.dart';
import 'package:apollo/core/database/database_service.dart';
import 'package:apollo/desktop/features/album/album_page.dart';
import 'package:apollo/desktop/features/artist/artist_page.dart';

/// A single track list item for collection pages.
/// Displays track info and handles play interactions.
class CollectionTrackListItem extends StatefulWidget {
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
  final void Function(Widget)? onNavigate;
  final VoidCallback? onHomeTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onProfileTap;

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
    this.onNavigate,
    this.onHomeTap,
    this.onSettingsTap,
    this.onProfileTap,
  });

  @override
  State<CollectionTrackListItem> createState() => _CollectionTrackListItemState();
}

class _CollectionTrackListItemState extends State<CollectionTrackListItem> {
  bool _isAlbumHovered = false;
  bool _isArtistHovered = false;
  final DatabaseService _dbService = DatabaseService();
  final PlexServerService _serverService = PlexServerService();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => widget.onHoverEnter(),
      onExit: (_) => widget.onHoverExit(),
      child: InkWell(
        onTap: () => _onTrackTapped(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          color: widget.isHovered ? Colors.grey[900] : Colors.transparent,
          child: Row(
            children: [
              // # or play button
              SizedBox(
                width: 40,
                child: widget.isHovered
                    ? const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 20,
                      )
                    : Text(
                        '${widget.index + 1}',
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
                            widget.track['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          _buildArtistLink(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Album
              Expanded(
                flex: 2,
                child: _buildAlbumLink(context),
              ),
              // Date added
              Expanded(
                flex: 1,
                child: Text(
                  widget.formatDate(widget.track['addedAt'] as int?),
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
                    if (widget.isHovered) ...[
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
                      widget.formatDuration(widget.track['duration'] as int),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    if (widget.isHovered) ...[
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
    debugPrint('TRACK_ITEM: ===== Track tapped: ${widget.track['title']} =====');
    if (widget.audioPlayerService != null && widget.currentToken != null) {
      // Get the correct server URL based on the track's serverId
      final trackServerId = widget.track['serverId'] as String?;
      final trackServerUrl = trackServerId != null && widget.serverUrls.containsKey(trackServerId)
          ? widget.serverUrls[trackServerId]!
          : widget.currentServerUrl;

      if (trackServerUrl == null) {
        debugPrint('TRACK_ITEM: ERROR - No server URL found for track (serverId: $trackServerId)');
        return;
      }

      debugPrint('TRACK_ITEM: Track serverId: $trackServerId');
      debugPrint('TRACK_ITEM: Using server URL: $trackServerUrl');
      debugPrint('TRACK_ITEM: Calling setPlayQueue with ${widget.tracks.length} tracks, index ${widget.index}');

      final startTime = DateTime.now();
      widget.audioPlayerService!.setPlayQueue(widget.tracks, widget.index);
      final endTime = DateTime.now();
      debugPrint('TRACK_ITEM: setPlayQueue took ${endTime.difference(startTime).inMilliseconds}ms');

      debugPrint('TRACK_ITEM: Calling playTrack');
      final playStartTime = DateTime.now();
      widget.audioPlayerService!.playTrack(
        widget.track,
        widget.currentToken!,
        trackServerUrl,
      );
      final playEndTime = DateTime.now();
      debugPrint('TRACK_ITEM: playTrack call returned in ${playEndTime.difference(playStartTime).inMilliseconds}ms');
    } else {
      debugPrint('TRACK_ITEM: Missing required data - service: ${widget.audioPlayerService != null}, token: ${widget.currentToken != null}');
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
      child: widget.track['thumb'] != null && widget.currentToken != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Builder(
                builder: (context) {
                  final serverId = widget.track['serverId'] as String?;
                  final serverUrl = serverId != null ? widget.serverUrls[serverId] : widget.currentServerUrl;

                  if (serverUrl == null) {
                    return const Icon(
                      Icons.music_note,
                      color: Colors.grey,
                      size: 20,
                    );
                  }

                  return Image.network(
                    '$serverUrl${widget.track['thumb']}?X-Plex-Token=${widget.currentToken}',
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

  Widget _buildAlbumLink(BuildContext context) {
    final albumId = widget.track['parentRatingKey'] as String?;
    final albumTitle = widget.track['album'] as String;
    
    if (albumId == null) {
      // No album link available
      return Text(
        albumTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
      );
    }
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isAlbumHovered = true),
      onExit: (_) => setState(() => _isAlbumHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _navigateToAlbum(context, albumId, albumTitle),
        child: Text(
          albumTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _isAlbumHovered ? Colors.white : Colors.grey[400],
            fontSize: 14,
            decoration: _isAlbumHovered ? TextDecoration.underline : null,
            decorationColor: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildArtistLink() {
    final artistName = widget.track['artist'] as String;
    final artistId = widget.track['grandparentRatingKey']?.toString();

    if (artistId == null) {
      return Text(
        artistName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 12,
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isArtistHovered = true),
      onExit: (_) => setState(() => _isArtistHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _navigateToArtist(artistId, artistName),
        child: Text(
          artistName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _isArtistHovered ? Colors.white : Colors.grey[400],
            fontSize: 12,
            decoration: _isArtistHovered ? TextDecoration.underline : null,
            decorationColor: Colors.white,
          ),
        ),
      ),
    );
  }

  void _navigateToArtist(String artistId, String artistName) async {
    final token = widget.currentToken;
    final trackServerId = widget.track['serverId'] as String?;

    String? serverUrl = widget.currentServerUrl;
    if (token != null && trackServerId != null) {
      try {
        serverUrl = await _serverService.getUrlForServer(token, trackServerId);
      } catch (e) {
        debugPrint('TRACK_ITEM: Error getting server URL: $e');
      }
    }
    serverUrl ??= widget.currentServerUrl;

    if (artistId.isNotEmpty && serverUrl != null && token != null && widget.onNavigate != null) {
      widget.onNavigate!(ArtistPage(
        artistId: artistId,
        artistName: artistName,
        serverUrl: serverUrl,
        token: token,
        audioPlayerService: widget.audioPlayerService,
        onNavigate: widget.onNavigate,
      ));
    }
  }

  void _navigateToAlbum(BuildContext context, String albumId, String albumTitle) {
    debugPrint('ALBUM_NAV: ===== Navigating to album =====');
    debugPrint('ALBUM_NAV: albumId: $albumId');
    debugPrint('ALBUM_NAV: albumTitle: $albumTitle');
    debugPrint('ALBUM_NAV: currentToken: ${widget.currentToken}');
    debugPrint('ALBUM_NAV: currentServerUrl: ${widget.currentServerUrl}');
    debugPrint('ALBUM_NAV: serverUrls count: ${widget.serverUrls.length}');
    debugPrint('ALBUM_NAV: Current track: ${widget.track['title']}');
    debugPrint('ALBUM_NAV: parent_rating_key in track: ${widget.track['parentRatingKey']}');
    
    // Get album art from track's parentThumb
    final albumThumb = widget.track['parentThumb'] as String?;
    final imageUrl = albumThumb != null && widget.currentServerUrl != null && widget.currentToken != null
        ? '${widget.currentServerUrl}$albumThumb?X-Plex-Token=${widget.currentToken}'
        : null;
    
    final albumPage = AlbumPage(
      title: albumTitle,
      subtitle: '$albumTitle • Album',
      audioPlayerService: widget.audioPlayerService,
      imageUrl: imageUrl,
      currentToken: widget.currentToken,
      serverUrls: widget.serverUrls,
      currentServerUrl: widget.currentServerUrl,
      onNavigate: widget.onNavigate,
      onHomeTap: widget.onHomeTap,
      onSettingsTap: widget.onSettingsTap,
      onProfileTap: widget.onProfileTap,
      onLoadTracks: () {
        debugPrint('ALBUM_NAV: onLoadTracks callback called with albumId: $albumId');
        return _dbService.getTracksForAlbum(albumId).then((tracks) {
          debugPrint('ALBUM_NAV: getTracksForAlbum returned ${tracks.length} tracks');
          if (tracks.isEmpty) {
            debugPrint('ALBUM_NAV: WARNING - No tracks found for album!');
          }
          return tracks;
        }).catchError((error) {
          debugPrint('ALBUM_NAV: ERROR fetching album tracks: $error');
          throw error;
        });
      },
    );

    // Use onNavigate callback if available (keeps MainScreen's app bar consistent)
    if (widget.onNavigate != null) {
      widget.onNavigate!(albumPage);
    } else {
      // Fallback to push if no navigation callback
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => albumPage),
      );
    }
  }
}
