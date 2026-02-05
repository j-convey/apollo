import 'album.dart';
import 'track.dart';

/// Model class representing a music artist.
class Artist {
  final int? id;
  final String ratingKey;
  final String name;
  final String? thumb;
  final String? art;
  final String? summary;
  final String? genre;
  final String? country;
  final String serverId;
  final int albumCount;
  final int trackCount;
  final int? addedAt;

  /// Eagerly loaded relationships
  final List<Album>? albums;
  final List<Track>? tracks;

  const Artist({
    this.id,
    required this.ratingKey,
    required this.name,
    this.thumb,
    this.art,
    this.summary,
    this.genre,
    this.country,
    this.serverId = '',
    this.albumCount = 0,
    this.trackCount = 0,
    this.addedAt,
    this.albums,
    this.tracks,
  });

  /// Creates an Artist from database row (includes view columns)
  factory Artist.fromDb(Map<String, dynamic> map) {
    return Artist(
      id: map['id'] as int?,
      ratingKey: map['rating_key'] as String? ?? '',
      name: map['title'] as String? ?? 'Unknown Artist',
      thumb: map['thumb'] as String?,
      art: map['art'] as String?,
      summary: map['summary'] as String?,
      genre: map['genre'] as String?,
      country: map['country'] as String?,
      serverId: map['server_id'] as String? ?? '',
      albumCount: (map['album_count'] as int?) ?? 0,
      trackCount: (map['track_count'] as int?) ?? 0,
      addedAt: map['added_at'] as int?,
    );
  }

  /// Creates an Artist from Plex API JSON response.
  factory Artist.fromPlexJson(Map<String, dynamic> json, {String serverId = ''}) {
    return Artist(
      ratingKey: json['ratingKey']?.toString() ?? '',
      name: json['title'] ?? 'Unknown Artist',
      thumb: json['thumb'],
      art: json['art'],
      summary: json['summary'],
      genre: json['Genre'] != null && (json['Genre'] as List).isNotEmpty
          ? json['Genre'][0]['tag']
          : null,
      country: json['Country'] != null && (json['Country'] as List).isNotEmpty
          ? json['Country'][0]['tag']
          : null,
      albumCount: json['childCount'] ?? 0,
      trackCount: json['leafCount'] ?? 0,
      serverId: serverId,
      addedAt: json['addedAt'],
    );
  }

  /// Creates a minimal Artist from track's grandparent info.
  factory Artist.fromTrack(Map<String, dynamic> track) {
    return Artist(
      ratingKey: track['grandparentRatingKey']?.toString() ?? '',
      name: track['grandparentTitle'] ?? 'Unknown Artist',
      thumb: track['grandparentThumb'],
      art: track['grandparentArt'],
      serverId: track['serverId'] ?? '',
    );
  }

  /// Convert to database map for insert/update
  Map<String, dynamic> toDb() {
    return {
      if (id != null) 'id': id,
      'rating_key': ratingKey,
      'title': name,
      'thumb': thumb ?? '',
      'art': art ?? '',
      'summary': summary ?? '',
      'genre': genre ?? '',
      'country': country ?? '',
      'server_id': serverId,
      'added_at': addedAt ?? DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ratingKey': ratingKey,
      'name': name,
      'title': name, // Alias for compatibility
      'thumb': thumb,
      'art': art,
      'summary': summary,
      'genre': genre,
      'country': country,
      'albumCount': albumCount,
      'trackCount': trackCount,
      'serverId': serverId,
      'addedAt': addedAt,
    };
  }

  Artist copyWith({
    int? id,
    String? ratingKey,
    String? name,
    String? thumb,
    String? art,
    String? summary,
    String? genre,
    String? country,
    String? serverId,
    int? albumCount,
    int? trackCount,
    int? addedAt,
    List<Album>? albums,
    List<Track>? tracks,
  }) {
    return Artist(
      id: id ?? this.id,
      ratingKey: ratingKey ?? this.ratingKey,
      name: name ?? this.name,
      thumb: thumb ?? this.thumb,
      art: art ?? this.art,
      summary: summary ?? this.summary,
      genre: genre ?? this.genre,
      country: country ?? this.country,
      serverId: serverId ?? this.serverId,
      albumCount: albumCount ?? this.albumCount,
      trackCount: trackCount ?? this.trackCount,
      addedAt: addedAt ?? this.addedAt,
      albums: albums ?? this.albums,
      tracks: tracks ?? this.tracks,
    );
  }

  @override
  String toString() => 'Artist(id: $id, name: $name, albums: $albumCount)';
}