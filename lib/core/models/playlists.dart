// c:\Users\jordan.convey\Documents\vscode\apollo\lib\core\models\playlist.dart

class Playlist {
  final String id; // Maps to 'ratingKey'
  final String title;
  final String? summary;
  final String? type; // 'audio', 'video', 'photo'
  final bool smart;
  final String? composite; // The image path
  final int duration;
  final int leafCount;

  Playlist({
    required this.id,
    required this.title,
    this.summary,
    this.type,
    required this.smart,
    this.composite,
    this.duration = 0,
    this.leafCount = 0,
  });

  // Factory to create a Playlist from Plex API JSON
  factory Playlist.fromPlexJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['ratingKey']?.toString() ?? '',
      title: json['title'] ?? 'Unknown Playlist',
      summary: json['summary'],
      type: json['playlistType'],
      smart: json['smart'] == true,
      composite: json['composite'],
      duration: json['duration'] ?? 0,
      leafCount: json['leafCount'] ?? 0,
    );
  }

  // Convert to Map for SQLite database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'summary': summary,
      'type': type,
      'smart': smart ? 1 : 0, // SQLite doesn't have boolean, use 0/1
      'composite': composite,
      'duration': duration,
      'leaf_count': leafCount,
    };
  }

  // Create from SQLite database Map
  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: map['id'] as String,
      title: map['title'] as String,
      summary: map['summary'] as String?,
      type: map['type'] as String?,
      smart: (map['smart'] as int) == 1,
      composite: map['composite'] as String?,
      duration: map['duration'] as int,
      leafCount: map['leaf_count'] as int,
    );
  }
}
