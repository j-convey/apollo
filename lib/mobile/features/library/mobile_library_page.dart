import 'package:flutter/material.dart';
import '../../../core/database/database_service.dart';
import '../../../core/models/track.dart';

/// Library page for mobile showing all songs from the server.
class MobileLibraryPage extends StatefulWidget {
  const MobileLibraryPage({super.key});

  @override
  State<MobileLibraryPage> createState() => _MobileLibraryPageState();
}

class _MobileLibraryPageState extends State<MobileLibraryPage> {
  final DatabaseService _db = DatabaseService();
  late Future<List<Track>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  void _loadTracks() {
    _tracksFuture = _db.tracks.getAll();
  }

  Future<void> _refreshTracks() async {
    setState(() {
      _loadTracks();
    });
  }

  String _formatDuration(int ms) {
    final seconds = (ms / 1000).round();
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Your Library',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Playlists'),
                    selected: false,
                    onSelected: (_) {},
                    backgroundColor: const Color(0xFF282828),
                    labelStyle: const TextStyle(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Artists'),
                    selected: false,
                    onSelected: (_) {},
                    backgroundColor: const Color(0xFF282828),
                    labelStyle: const TextStyle(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  FilterChip(
                    label: const Text('Albums'),
                    selected: false,
                    onSelected: (_) {},
                    backgroundColor: const Color(0xFF282828),
                    labelStyle: const TextStyle(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshTracks,
                color: Colors.purple,
                child: FutureBuilder<List<Track>>(
                  future: _tracksFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.purple));
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'Your library is empty',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final tracks = snapshot.data!;
                    return ListView.builder(
                      itemCount: tracks.length,
                      itemBuilder: (context, index) {
                        final track = tracks[index];
                        return ListTile(
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFF282828),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: track.albumThumb != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      track.albumThumb!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.grey),
                                    ),
                                  )
                                : const Icon(Icons.music_note, color: Colors.grey),
                          ),
                          title: Text(
                            track.title,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${track.artistName} • ${track.albumName}',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            _formatDuration(track.duration),
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          onTap: () {
                            // TODO: Play track
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
