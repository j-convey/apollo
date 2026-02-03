import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'core/widgets/apollo_app_bar.dart';
import 'core/widgets/player_bar.dart';
import 'core/services/audio_player_service.dart';
import 'core/services/storage_service.dart';
import 'features/home/home_page.dart';
import 'features/settings/settings_page.dart';
import 'features/profile/profile_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize media_kit for audio playback
  MediaKit.ensureInitialized();
  
  // Configure window
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    minimumSize: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  runApp(const ApolloApp());
}

class ApolloApp extends StatelessWidget {
  const ApolloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Apollo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Widget _currentPage;
  final AudioPlayerService _audioPlayerService = AudioPlayerService();
  final StorageService _storageService = StorageService();
  final List<Widget> _navigationHistory = [];
  int _currentHistoryIndex = -1;
  String? _currentToken;
  String? _currentServerUrl;

  @override
  void initState() {
    super.initState();
    _loadCredentials();
    _currentPage = HomePage(
      onNavigate: _navigateToPage,
      audioPlayerService: _audioPlayerService,
    );
    _navigationHistory.add(_currentPage);
    _currentHistoryIndex = 0;
  }

  Future<void> _loadCredentials() async {
    _currentToken = await _storageService.getPlexToken();
    // You can load server URL here if needed
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _audioPlayerService.dispose();
    super.dispose();
  }

  void _navigateToPage(Widget page) {
    setState(() {
      // Remove forward history when navigating to a new page
      if (_currentHistoryIndex < _navigationHistory.length - 1) {
        _navigationHistory.removeRange(_currentHistoryIndex + 1, _navigationHistory.length);
      }
      
      _navigationHistory.add(page);
      _currentHistoryIndex = _navigationHistory.length - 1;
      _currentPage = page;
    });
  }

  void _goBack() {
    if (_currentHistoryIndex > 0) {
      setState(() {
        _currentHistoryIndex--;
        _currentPage = _navigationHistory[_currentHistoryIndex];
      });
    }
  }

  void _goForward() {
    if (_currentHistoryIndex < _navigationHistory.length - 1) {
      setState(() {
        _currentHistoryIndex++;
        _currentPage = _navigationHistory[_currentHistoryIndex];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Column(
        children: [
          ApolloAppBar(
            audioPlayerService: _audioPlayerService,
            currentToken: _currentToken,
            currentServerUrl: _currentServerUrl,
            onBackPressed: _goBack,
            onForwardPressed: _goForward,
            canGoBack: _currentHistoryIndex > 0,
            canGoForward: _currentHistoryIndex < _navigationHistory.length - 1,
            onHomeTap: () {
              _navigateToPage(HomePage(
                onNavigate: _navigateToPage,
                audioPlayerService: _audioPlayerService,
              ));
            },
            onSearchTap: () {
              // TODO: Implement search
            },
            onNotificationsTap: () {
              // TODO: Implement notifications
            },
            onAccountTap: () {
              // TODO: Navigate to account page
            },
            onProfileTap: () {
              _navigateToPage(ProfilePage(storageService: _storageService));
            },
            onSupportTap: () {
              // TODO: Open support page
            },
            onPrivateSessionTap: () {
              // TODO: Toggle private session
            },
            onSettingsTap: () {
              _navigateToPage(const SettingsPage());
            },
            onLogoutTap: () {
              // TODO: Implement logout
            },
          ),
          Expanded(
            child: _currentPage,
          ),
          PlayerBar(playerService: _audioPlayerService),
        ],
      ),
    );
  }
}
