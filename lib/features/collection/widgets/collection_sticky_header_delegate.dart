import 'package:flutter/material.dart';
import 'collection_sticky_header_content.dart';

/// Delegate that controls the sticky header behavior for collection pages.
/// Keeps the column headers visible while scrolling.
class CollectionStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final String sortColumn;
  final bool sortAscending;
  final Function(String) onSort;
  final double topPadding;

  CollectionStickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    this.topPadding = 0.0,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(
      child: Column(
        children: [
          if (topPadding > 0) SizedBox(height: topPadding),
          Expanded(
            child: CollectionStickyHeaderContent(
              sortColumn: sortColumn,
              sortAscending: sortAscending,
              onSort: onSort,
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(CollectionStickyHeaderDelegate oldDelegate) {
    return maxHeight != oldDelegate.maxHeight ||
        minHeight != oldDelegate.minHeight ||
        sortColumn != oldDelegate.sortColumn ||
        sortAscending != oldDelegate.sortAscending ||
        topPadding != oldDelegate.topPadding;
  }
}
