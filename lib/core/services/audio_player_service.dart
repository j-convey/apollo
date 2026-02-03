import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

class AudioPlayerService extends ChangeNotifier {
  late final Player _player;
  late final StreamSubscription<bool> _playingSubscription;
  late final StreamSubscription<Duration> _durationSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<bool> _completedSubscription;

  Map<String, dynamic>? _currentTrack;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _currentToken;
  String? _currentServerUrl;
  Map<String, String> _serverUrls = {}; // Map of serverId to serverUrl

  AudioPlayerService() {
    _player = Player();
    
    // Listen to player state changes
    _playingSubscription = _player.stream.playing.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    // Listen to duration changes
    _durationSubscription = _player.stream.duration.listen((duration) {
      _duration = duration;
      notifyListeners();
    });

    // Listen to position changes - throttle updates to reduce UI rebuilds
    Duration lastNotifiedPosition = Duration.zero;
    _positionSubscription = _player.stream.position.listen((position) {
      _position = position;
      // Only notify if position changed by at least 1 second to reduce rebuilds
      if ((position.inSeconds - lastNotifiedPosition.inSeconds).abs() >= 1) {
        lastNotifiedPosition = position;
        notifyListeners();
      }
    });

    // Listen to completion
    _completedSubscription = _player.stream.completed.listen((completed) {
      if (completed) {
        _isPlaying = false;
        _position = Duration.zero;
        next();
        notifyListeners();
      }
    });
  }

  List<Map<String, dynamic>> _playQueue = [];
  int _currentIndex = -1;

  // Getters
  Map<String, dynamic>? get currentTrack => _currentTrack;
  bool get isPlaying => _isPlaying;
  Duration get duration => _duration;
  Duration get position => _position;
  String? get currentToken => _currentToken;
  String? get currentServerUrl => _currentServerUrl;
  int get currentIndex => _currentIndex;
  int get queueLength => _playQueue.length;

  // Set server URLs map
  void setServerUrls(Map<String, String> urls) {
    _serverUrls = urls;
    debugPrint('PLAYER: Server URLs updated: ${_serverUrls.keys.join(", ")}');
  }

  // Setter for the play queue (without auto-playing)
  void setPlayQueue(List<Map<String, dynamic>> queue, int startIndex) {
    _playQueue = queue; // Reference the list directly to avoid copying large lists
    _currentIndex = startIndex;
    debugPrint('PLAYER: Queue set with ${_playQueue.length} tracks, starting at index $startIndex');
  }

  // Play a track
  Future<void> playTrack(
      Map<String, dynamic> track, String token, String serverUrl) async {
    try {
      debugPrint('PLAYER: ===== playTrack() called =====');
      debugPrint('PLAYER: Track title: ${track['title']}');
      
      _currentTrack = track;
      _currentToken = token;
      _currentServerUrl = serverUrl;

      // Construct the audio URL
      final media = track['Media'] as List<dynamic>?;
      String audioUrl;
      
      if (media != null && media.isNotEmpty) {
        final parts = media[0]['Part'] as List<dynamic>?;
        
        if (parts != null && parts.isNotEmpty) {
          final partKey = parts[0]['key'] as String;
          audioUrl = '$serverUrl$partKey?X-Plex-Token=$token';
          debugPrint('PLAYER: Audio URL: $audioUrl');
        } else {
          throw Exception('No media parts found in track data');
        }
      } else {
        throw Exception('No media information found in track data');
      }

      // Update UI immediately so player bar shows up
      notifyListeners();

      // Stop any current playback
      await _player.stop();

      // Open and play the new track
      debugPrint('PLAYER: Opening media...');
      await _player.open(
        Media(
          audioUrl,
          httpHeaders: {
            'X-Plex-Token': token,
          },
        ),
      );
      debugPrint('PLAYER: Playback started!');
      
    } catch (e, stackTrace) {
      debugPrint('PLAYER: ===== ERROR playing track =====');
      debugPrint('PLAYER: Error: $e');
      debugPrint('PLAYER: Stack trace: $stackTrace');
    }
  }

  // Go to the next track in the queue
  Future<void> next() async {
    debugPrint('PLAYER: next() called, currentIndex: $_currentIndex, queueLength: ${_playQueue.length}');
    
    if (_playQueue.isEmpty) {
      debugPrint('PLAYER: Queue is empty, cannot go to next track');
      return;
    }
    
    if (_currentToken == null) {
      debugPrint('PLAYER: Missing token');
      return;
    }
    
    if (_currentIndex < _playQueue.length - 1) {
      _currentIndex++;
      debugPrint('PLAYER: Moving to next track at index $_currentIndex');
      
      final nextTrack = _playQueue[_currentIndex];
      final trackServerId = nextTrack['serverId'] as String?;
      final serverUrl = trackServerId != null && _serverUrls.containsKey(trackServerId)
          ? _serverUrls[trackServerId]!
          : _currentServerUrl;
      
      if (serverUrl == null) {
        debugPrint('PLAYER: ERROR - No server URL for next track');
        return;
      }
      
      await playTrack(nextTrack, _currentToken!, serverUrl);
    } else {
      // Reached the end of the queue
      debugPrint('PLAYER: Reached end of queue, stopping playback');
      await stop();
    }
  }

  // Go to the previous track in the queue
  Future<void> previous() async {
    debugPrint('PLAYER: previous() called, currentIndex: $_currentIndex, queueLength: ${_playQueue.length}');
    
    if (_playQueue.isEmpty) {
      debugPrint('PLAYER: Queue is empty, cannot go to previous track');
      return;
    }
    
    if (_currentToken == null) {
      debugPrint('PLAYER: Missing token');
      return;
    }
    
    // If more than 3 seconds into the track, restart it instead of going to previous
    if (_position.inSeconds > 3) {
      debugPrint('PLAYER: Restarting current track');
      await seek(Duration.zero);
      return;
    }
    
    if (_currentIndex > 0) {
      _currentIndex--;
      debugPrint('PLAYER: Moving to previous track at index $_currentIndex');
      
      final prevTrack = _playQueue[_currentIndex];
      final trackServerId = prevTrack['serverId'] as String?;
      final serverUrl = trackServerId != null && _serverUrls.containsKey(trackServerId)
          ? _serverUrls[trackServerId]!
          : _currentServerUrl;
      
      if (serverUrl == null) {
        debugPrint('PLAYER: ERROR - No server URL for previous track');
        return;
      }
      
      await playTrack(prevTrack, _currentToken!, serverUrl);
    } else {
      // At the beginning of the queue, restart current track
      debugPrint('PLAYER: At beginning of queue, restarting current track');
      await seek(Duration.zero);
    }
  }

  // Toggle play/pause
  Future<void> togglePlayPause() async {
    await _player.playOrPause();
  }

  // Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // Stop playback
  Future<void> stop() async {
    await _player.stop();
    _currentTrack = null;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  // Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume * 100); // media_kit uses 0-100
  }

  @override
  void dispose() {
    _playingSubscription.cancel();
    _durationSubscription.cancel();
    _positionSubscription.cancel();
    _completedSubscription.cancel();
    _player.dispose();
    super.dispose();
  }
}
