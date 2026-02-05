import 'package:flutter/material.dart';

/// Dialog widget for first-time login experience.
/// Single Responsibility: Only displays the welcome UI and handles button taps.
class LoginWelcomeDialog extends StatelessWidget {
  final VoidCallback onLoginPressed;
  final VoidCallback? onDismissPressed;

  const LoginWelcomeDialog({
    super.key,
    required this.onLoginPressed,
    this.onDismissPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Logo / Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.deepPurple[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.music_note,
                  size: 48,
                  color: Colors.deepPurple[700],
                ),
              ),
              const SizedBox(height: 24),

              // Welcome Title
              Text(
                'Welcome to Apollo',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                'Apollo is your personal music streaming app powered by Plex. To get started, connect your Plex account and sync your music libraries.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Features List
              _buildFeature(context, Icons.library_music, 'Access all your music'),
              const SizedBox(height: 12),
              _buildFeature(context, Icons.cloud_sync, 'Sync your libraries'),
              const SizedBox(height: 12),
              _buildFeature(context, Icons.play_circle, 'Stream anywhere'),
              const SizedBox(height: 32),

              // Login Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onLoginPressed,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In with Plex'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Dismiss Button (optional)
              if (onDismissPressed != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onDismissPressed,
                    child: const Text('Maybe Later'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Colors.deepPurple,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
