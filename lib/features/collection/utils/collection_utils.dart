import 'package:intl/intl.dart';

/// Utility functions for collection pages
class CollectionUtils {
  /// Format milliseconds duration to mm:ss format
  static String formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format Unix timestamp to readable date
  static String formatDate(int? addedAt) {
    if (addedAt == null) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(addedAt * 1000);
    return DateFormat('MMM d, y').format(date);
  }

  /// Sort tracks by given column
  static void sortTracks(
    List<Map<String, dynamic>> tracks,
    String column,
    bool ascending,
  ) {
    tracks.sort((a, b) {
      dynamic aValue = a[column];
      dynamic bValue = b[column];

      if (aValue == null && bValue == null) return 0;
      if (aValue == null) return 1;
      if (bValue == null) return -1;

      int comparison;
      if (aValue is String && bValue is String) {
        comparison = aValue.toLowerCase().compareTo(bValue.toLowerCase());
      } else if (aValue is int && bValue is int) {
        comparison = aValue.compareTo(bValue);
      } else {
        comparison = aValue.toString().compareTo(bValue.toString());
      }

      return ascending ? comparison : -comparison;
    });
  }
}
