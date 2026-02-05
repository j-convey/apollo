import 'track.dart';

/// Model class representing a playlist.
class Playlist {
  final String id;
  final String title;
  final String? summary;
  final String? type;
  final bool smart;
  final String? composite;
  final int duration;
  final int leafCount;
  final String serverId;

  /// Eagerly loaded tracks
  final List<Track>? tracks;

  const Playlist({
    required this.id,
    required this.title,
    this.summary,
    this.type,
    required this.smart,
    this.composite,
    this.duration = 0,
    this.leafCount = 0,
    this.serverId = '',
    this.tracks,
  });

  factory Playlist.fromDb(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as String,
      title: map['title'] as String,
      summary: map['summary'] as String?,
      type: map['type'] as String?,
      smart: (map['smart'] as int?) == 1,
      composite: map['composite'] as String?,
      duration: (map['duration'] as int?) ?? 0,
      leafCount: (map['leaf_count'] as int?) ?? 0,
      serverId: map['server_id'] as String? ?? '',
    );
  }

  factory Playlist.fromPlexJson(Map<String, dynamic> json, {String serverId = ''}) {
    return Playlist(
      id: json['ratingKey']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Playlist',
      summary: json['summary'],
      type: json['playlistType'],
      smart: json['smart'] == true,
      composite: json['composite'],
      duration: json['duration'] ?? 0,
      leafCount: json['leafCount'] ?? 0,
      serverId: serverId,
    );
  }

  Map<String, dynamic> toDb() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'type': type,
      'smart': smart ? 1 : 0,
      'composite': composite,
      'duration': duration,
      'leaf_count': leafCount,
      'server_id': serverId,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'type': type,
      'smart': smart,
      'composite': composite,
      'duration': duration,
      'leafCount': leafCount,
      'serverId': serverId,
    };
  }

  Playlist copyWith({
    String? id,
    String? title,
    String? summary,
    String? type,
    bool? smart,
    String? composite,
    int? duration,
    int? leafCount,
    String? serverId,
    List<Track>? tracks,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      type: type ?? this.type,
      smart: smart ?? this.smart,
      composite: composite ?? this.composite,
      duration: duration ?? this.duration,
      leafCount: leafCount ?? this.leafCount,
      serverId: serverId ?? this.serverId,
      tracks: tracks ?? this.tracks,
    );
  }

  @override
  String toString() => 'Playlist(id: $id, title: $title, tracks: $leafCount)';
}