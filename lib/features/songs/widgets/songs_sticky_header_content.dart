import 'package:flutter/material.dart';
import '../../../core/services/audio_player_service.dart';
import 'sticky_play_button.dart';

/// The sticky header content that stays visible when scrolling.
/// Contains the play button and column headers.
class SongsStickyHeaderContent extends StatelessWidget {
  final String sortColumn;
  final bool sortAscending;
  final Function(String) onSort;
  final List<Map<String, dynamic>> tracks;
  final AudioPlayerService? audioPlayerService;
  final String? currentToken;
  final Map<String, String> serverUrls;
  final String? currentServerUrl;
  final bool showPlayButton;

  const SongsStickyHeaderContent({
    super.key,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.tracks,
    required this.audioPlayerService,
    required this.currentToken,
    required this.serverUrls,
    required this.currentServerUrl,
    this.showPlayButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPlayButtonRow(),
          _buildColumnHeaders(),
        ],
      ),
    );
  }

  Widget _buildPlayButtonRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          AnimatedOpacity(
            opacity: showPlayButton ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: StickyPlayButton(
              tracks: tracks,
              audioPlayerService: audioPlayerService,
              currentToken: currentToken,
              serverUrls: serverUrls,
              currentServerUrl: currentServerUrl,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumnHeaders() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Row(
        children: [
          _buildNumberColumn(),
          _buildTitleColumn(),
          _buildAlbumColumn(),
          _buildDateAddedColumn(),
          _buildDurationColumn(),
        ],
      ),
    );
  }

  Widget _buildNumberColumn() {
    return const SizedBox(
      width: 40,
      child: Text(
        '#',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTitleColumn() {
    return Expanded(
      flex: 3,
      child: _buildSortableHeader('Title', 'title'),
    );
  }

  Widget _buildAlbumColumn() {
    return Expanded(
      flex: 2,
      child: _buildSortableHeader('Album', 'album'),
    );
  }

  Widget _buildDateAddedColumn() {
    return Expanded(
      flex: 1,
      child: _buildSortableHeader('Date added', 'addedAt'),
    );
  }

  Widget _buildDurationColumn() {
    return SizedBox(
      width: 110,
      child: InkWell(
        onTap: () => onSort('duration'),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (sortColumn == 'duration')
              Icon(
                sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: Colors.grey,
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.access_time,
              size: 16,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortableHeader(String label, String column) {
    return InkWell(
      onTap: () => onSort(column),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (sortColumn == column)
            Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 12,
              color: Colors.grey,
            ),
        ],
      ),
    );
  }
}
