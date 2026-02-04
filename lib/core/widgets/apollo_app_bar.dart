import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'app_bar/navigation_buttons.dart';
import 'app_bar/app_bar_search_bar.dart';
import 'app_bar/app_bar_actions.dart';
import 'app_bar/window_controls.dart';
import '../services/audio_player_service.dart';

class ApolloAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onHomeTap;
  final VoidCallback? onBackPressed;
  final VoidCallback? onForwardPressed;
  final VoidCallback? onSearchTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onAccountTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onSupportTap;
  final VoidCallback? onPrivateSessionTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;
  final bool canGoBack;
  final bool canGoForward;
  final AudioPlayerService? audioPlayerService;
  final String? currentToken;
  final String? currentServerUrl;
  final void Function(Widget)? onNavigate;
  
  const ApolloAppBar({
    super.key,
    this.onHomeTap,
    this.onBackPressed,
    this.onForwardPressed,
    this.onSearchTap,
    this.onNotificationsTap,
    this.onAccountTap,
    this.onProfileTap,
    this.onSupportTap,
    this.onPrivateSessionTap,
    this.onSettingsTap,
    this.onLogoutTap,
    this.canGoBack = true,
    this.canGoForward = false,
    this.audioPlayerService,
    this.currentToken,
    this.currentServerUrl,
    this.onNavigate,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        height: preferredSize.height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.black,
        ),
        child: Stack(
          children: [
            // Left side controls
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  // Navigation arrows
                  NavigationButtons(
                    onBackPressed: onBackPressed,
                    onForwardPressed: onForwardPressed,
                    canGoBack: canGoBack,
                    canGoForward: canGoForward,
                  ),
                ],
              ),
            ),
            
            // Center: Search bar with home button adjacent to its left
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.home, size: 24),
                      color: Colors.white,
                      onPressed: onHomeTap,
                      tooltip: 'Home',
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 455),
                    child: AppBarSearchBar(
                      audioPlayerService: audioPlayerService,
                      currentToken: currentToken,
                      currentServerUrl: currentServerUrl,
                      onNavigate: onNavigate,
                    ),
                  ),
                ],
              ),
            ),
            
            // Right side controls
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Row(
                children: [
                  // Action buttons
                  AppBarActions(
                    onNotificationsTap: onNotificationsTap,
                    onAccountTap: onAccountTap,
                    onProfileTap: onProfileTap,
                    onSupportTap: onSupportTap,
                    onPrivateSessionTap: onPrivateSessionTap,
                    onSettingsTap: onSettingsTap,
                    onLogoutTap: onLogoutTap,
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Window controls
                  const WindowControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
