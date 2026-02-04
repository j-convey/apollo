import 'package:flutter/material.dart';

/// Custom scrollbar positioned on the right side of the songs list.
/// Provides visual feedback for scroll position with styling for dark theme.
class SongsScrollbar extends StatelessWidget {
  final ScrollController scrollController;
  final Widget child;

  const SongsScrollbar({
    super.key,
    required this.scrollController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(8.0),
        thumbColor: WidgetStateProperty.all(Colors.white.withOpacity(0.3)),
        trackColor: WidgetStateProperty.all(Colors.white.withOpacity(0.1)),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(4),
      ),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: false,
        trackVisibility: false,
        child: child,
      ),
    );
  }
}
