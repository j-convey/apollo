import 'package:flutter/material.dart';
import 'server/server_settings_page.dart';

class SettingsPage extends StatelessWidget {
  final void Function(Widget) onNavigate;

  const SettingsPage({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF303030),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.dns, color: Colors.white),
            title: const Text('Server', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Configure Plex server connection',
                style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white),
            onTap: () {
              onNavigate(const ServerSettingsPage());
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.white),
            title: const Text('About', style: TextStyle(color: Colors.white)),
            subtitle:
                const Text('App information', style: TextStyle(color: Colors.grey)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white),
            onTap: () {
              // TODO: Implement About page
            },
          ),
        ],
      ),
    );
  }
}
