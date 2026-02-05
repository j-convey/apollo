import 'track.dart';
import 'artist.dart';

/// Model class representing a music album.
class Album {
  final int? id;
  final String ratingKey;
  final String title;
  final int? artistId;
  final String artistName;
  final String? artistRatingKey;
  final String? thumb;
  final String? art;
  final int? year;
  final String? genre;
  final String? studio;
  final String? summary;
  final int trackCount;
  final int totalDuration;
  final String serverId;
  final int? addedAt;

  /// Eagerly loaded relationships
  final List<Track>? tracks;
  final Artist? artist;

  const Album({
    this.id,
    required this.ratingKey,
    required this.title,
    this.artistId,
    this.artistName = 'Unknown Artist',
    this.artistRatingKey,
    this.thumb,
    this.art,
    this.year,
    this.genre,
    this.studio,
    this.summary,
    this.trackCount = 0,
    this.totalDuration = 0,
    required this.serverId,
    this.addedAt,
    this.tracks,
    this.artist,
  });

  /// Creates an Album from database row (includes view columns)
  factory Album.fromDb(Map<String, dynamic> map) {
    return Album(
      id: map['id'] as int?,
      ratingKey: map['rating_key'] as String? ?? '',
      title: map['title'] as String? ?? 'Unknown Album',
      artistId: map['artist_id'] as int?,
      artistName: (map['artist_name'] as String?) ??
          (map['artist_title'] as String?) ??
          'Unknown Artist',
      artistRatingKey: map['artist_rating_key'] as String?,
      thumb: map['thumb'] as String?,
      art: map['art'] as String?,
      year: map['year'] as int?,
      genre: map['genre'] as String?,
      studio: map['studio'] as String?,
      summary: map['summary'] as String?,
      trackCount: (map['track_count'] as int?) ??
          (map['computed_track_count'] as int?) ??
          0,
      totalDuration: (map['total_duration'] as int?) ?? 0,
      serverId: map['server_id'] as String? ?? '',
      addedAt: map['added_at'] as int?,
    );
  }

  /// Creates an Album from Plex API JSON response
  factory Album.fromPlexJson(Map<String, dynamic> json, String serverId) {
    return Album(
      ratingKey: json['ratingKey']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Album',
      artistName: json['parentTitle'] ?? json['grandparentTitle'] ?? 'Unknown Artist',
      artistRatingKey: json['parentRatingKey']?.toString() ?? json['grandparentRatingKey']?.toString(),
      thumb: json['thumb'],
      art: json['art'],
      year: json['year'],
      genre: json['Genre'] != null && (json['Genre'] as List).isNotEmpty
          ? json['Genre'][0]['tag']
          : null,
      studio: json['studio'],
      summary: json['summary'],
      trackCount: json['leafCount'] ?? 0,
      serverId: serverId,
      addedAt: json['addedAt'],
    );
  }

  /// Creates minimal Album from track's parent info
  factory Album.fromTrack(Map<String, dynamic> track) {
    return Album(
      ratingKey: track['parentRatingKey']?.toString() ?? '',
      title: track['parentTitle'] ?? 'Unknown Album',
      artistName: track['grandparentTitle'] ?? 'Unknown Artist',
      artistRatingKey: track['grandparentRatingKey']?.toString(),
      thumb: track['parentThumb'],
      year: track['year'],
      serverId: track['serverId'] ?? '',
    );
  }

  /// Convert to database map for insert/update
  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'rating_key': ratingKey,
      'title': title,
      'artist_id': artistId,
      'artist_name': artistName,
      'thumb': thumb ?? '',
      'art': art ?? '',
      'year': year ?? 0,
      'genre': genre ?? '',
      'studio': studio ?? '',
      'summary': summary ?? '',
      'track_count': trackCount,
      'server_id': serverId,
      'added_at': addedAt ?? DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Convert to Map for UI consumption
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ratingKey': ratingKey,
      'title': title,
      'artistId': artistId,
      'artistName': artistName,
      'artistRatingKey': artistRatingKey,
      'thumb': thumb,
      'art': art,
      'year': year,
      'genre': genre,
      'studio': studio,
      'summary': summary,
      'trackCount': trackCount,
      'totalDuration': totalDuration,
      'serverId': serverId,
      'addedAt': addedAt,
    };
  }

  /// Create copy with optional overrides
  Album copyWith({
    int? id,
    String? ratingKey,
    String? title,
    int? artistId,
    String? artistName,
    String? artistRatingKey,
    String? thumb,
    String? art,
    int? year,
    String? genre,
    String? studio,
    String? summary,
    int? trackCount,
    int? totalDuration,
    String? serverId,
    int? addedAt,
    List<Track>? tracks,
    Artist? artist,
  }) {
    return Album(
      id: id ?? this.id,
      ratingKey: ratingKey ?? this.ratingKey,
      title: title ?? this.title,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      artistRatingKey: artistRatingKey ?? this.artistRatingKey,
      thumb: thumb ?? this.thumb,
      art: art ?? this.art,
      year: year ?? this.year,
      genre: genre ?? this.genre,
      studio: studio ?? this.studio,
      summary: summary ?? this.summary,
      trackCount: trackCount ?? this.trackCount,
      totalDuration: totalDuration ?? this.totalDuration,
      serverId: serverId ?? this.serverId,
      addedAt: addedAt ?? this.addedAt,
      tracks: tracks ?? this.tracks,
      artist: artist ?? this.artist,
    );
  }

  @override
  String toString() => 'Album(id: $id, title: $title, artist: $artistName)';
}