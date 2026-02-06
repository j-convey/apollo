import 'package:flutter/material.dart';
import 'package:apollo/core/services/plex/plex_services.dart';
import 'package:apollo/core/services/authentication_check_service.dart';
import 'login_welcome_dialog.dart';

/// Modal coordinator for first-time authentication.
/// Single Responsibility: Only orchestrates showing login dialog and handling auth flow.
class AuthenticationModal extends StatefulWidget {
  final AuthenticationCheckService authCheckService;
  final PlexAuthService authService;
  final VoidCallback onAuthenticationSuccess;
  final Widget child;

  const AuthenticationModal({
    super.key,
    required this.authCheckService,
    required this.authService,
    required this.onAuthenticationSuccess,
    required this.child,
  });

  @override
  State<AuthenticationModal> createState() => _AuthenticationModalState();
}

class _AuthenticationModalState extends State<AuthenticationModal> {
  @override
  void initState() {
    super.initState();
    _checkAndShowLoginDialog();
  }

  /// Check if user needs to authenticate and show dialog if needed.
  Future<void> _checkAndShowLoginDialog() async {
    try {
      final isFirstTime = await widget.authCheckService.isFirstTimeUser();
      if (isFirstTime && mounted) {
        _showLoginDialog();
      }
    } catch (e) {
      debugPrint('Error checking authentication status: $e');
    }
  }

  /// Show the login welcome dialog.
  void _showLoginDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => LoginWelcomeDialog(
        onLoginPressed: _handleLoginPressed,
        onDismissPressed: _handleDismissPressed,
      ),
    );
  }

  /// Handle login button press.
  Future<void> _handleLoginPressed() async {
    if (!mounted) return;
    Navigator.pop(context); // Close dialog

    // Show loading indicator
    _showLoadingDialog();

    try {
      final result = await widget.authService.signIn();
      if (result['success'] == true && mounted) {
        Navigator.pop(context); // Close loading dialog
        widget.onAuthenticationSuccess();
      } else if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog('Failed to sign in: ${result['error']}');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        _showErrorDialog('Error during authentication: $e');
      }
    }
  }

  /// Handle dismiss button press (Maybe Later).
  void _handleDismissPressed() {
    Navigator.pop(context);
  }

  /// Show loading dialog during authentication.
  void _showLoadingDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Signing in...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show error dialog if authentication fails.
  void _showErrorDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Authentication Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
