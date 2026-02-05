/// Database module exports
/// 
/// Usage:
/// ```dart
/// import 'package:apollo/core/database/database.dart';
/// 
/// final db = DatabaseService();
/// 
/// // Type-safe access
/// final albums = await db.albums.getAll();
/// final albumWithTracks = await db.albums.getWithTracks('12345');
/// ```
library;

export 'database_service.dart';
export 'repositories/artist_repository.dart';
export 'repositories/album_repository.dart';
export 'repositories/track_repository.dart';
export 'repositories/playlist_repository.dart';
export 'schema/tables.dart';
export 'schema/views.dart';
export 'schema/indexes.dart';
export 'schema/migrations.dart';