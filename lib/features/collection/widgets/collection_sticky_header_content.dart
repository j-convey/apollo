import 'package:flutter/material.dart';

/// The sticky header content for collection pages.
/// Contains only the column headers for sorting.
class CollectionStickyHeaderContent extends StatelessWidget {
  final String sortColumn;
  final bool sortAscending;
  final Function(String) onSort;

  const CollectionStickyHeaderContent({
    super.key,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF121212),
      child: _buildColumnHeaders(),
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
