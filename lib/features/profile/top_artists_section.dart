import 'package:flutter/material.dart';
import 'artist_card.dart';

class TopArtistsSection extends StatelessWidget {
  const TopArtistsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Top artists this month',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Only visible to you',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),
        _buildArtistList(),
      ],
    );
  }

  Widget _buildArtistList() {
    return SizedBox(
      height: 220,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _getDummyArtists(),
      ),
    );
  }

  List<Widget> _getDummyArtists() {
    return const [
      ArtistCard(name: 'Artist One', icon: Icons.music_note),
      ArtistCard(name: 'Artist Two', icon: Icons.album),
      ArtistCard(name: 'Artist Three', icon: Icons.person),
      ArtistCard(name: 'Artist Four', icon: Icons.mic),
      ArtistCard(name: 'Artist Five', icon: Icons.audiotrack),
    ];
  }
}