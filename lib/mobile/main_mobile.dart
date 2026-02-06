import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'shell/mobile_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media_kit for audio playback
  MediaKit.ensureInitialized();

  runApp(const ApolloMobileApp());
}

class ApolloMobileApp extends StatelessWidget {
  const ApolloMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apollo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const MobileShell(),
    );
  }
}
