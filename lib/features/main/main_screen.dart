import 'package:flutter/material.dart';
import '../../core/widgets/apollo_app_bar.dart';
import '../../core/widgets/player_bar.dart';
import '../../core/services/audio_player_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/plex/plex_services.dart';
import '../authentication/domain/authentication_check_service.dart';
import '../authentication/presentation/authentication_modal.dart';
import '../home/home_page.dart';
import '../settings/settings_page.dart';
import '../profile/profile_page.dart';

class MainScreen extends StatefulWidget {
  final AudioPlayerService? audioPlayerService;
  final StorageService? storageService;

  const MainScreen({
    super.key,
    this.audioPlayerService,
    this.storageService,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late Widget _currentPage;
  late final AudioPlayerService _audioPlayerService;
  late final StorageService _storageService;
  late final AuthenticationCheckService _authCheckService;
  final List<Widget> _navigationHistory = [];
  int _currentHistoryIndex = -1;
  String? _currentToken;
  String? _currentServerUrl;

  @override
  void initState() {
    super.initState();
    _audioPlayerService = widget.audioPlayerService ?? AudioPlayerService();
    _storageService = widget.storageService ?? StorageService();
    _authCheckService = AuthenticationCheckService(_storageService);
    _loadCredentials();
    _currentPage = HomePage(
      onNavigate: _navigateToPage,
      audioPlayerService: _audioPlayerService,
      storageService: _storageService,
      token: _currentToken,
      serverUrl: _currentServerUrl,
      onHomeTap: _onHomeTap,
      onSettingsTap: _onSettingsTap,
      onProfileTap: _onProfileTap,
    );
    _navigationHistory.add(_currentPage);
    _currentHistoryIndex = 0;
  }

  void _onHomeTap() {
    _navigateToPage(HomePage(
      onNavigate: _navigateToPage,
      audioPlayerService: _audioPlayerService,
      storageService: _storageService,
      token: _currentToken,
      serverUrl: _currentServerUrl,
      onHomeTap: _onHomeTap,
      onSettingsTap: _onSettingsTap,
      onProfileTap: _onProfileTap,
    ));
  }

  void _onSettingsTap() {
    _navigateToPage(SettingsPage(onNavigate: _navigateToPage));
  }

  void _onProfileTap() {
    _navigateToPage(ProfilePage(storageService: _storageService));
  }

  Future<void> _loadCredentials() async {
    _currentToken = await _storageService.getPlexToken();
    _currentServerUrl = await _storageService.getServerUrl();
    if (mounted) {
      setState(() {
        _currentPage = HomePage(
          onNavigate: _navigateToPage,
          audioPlayerService: _audioPlayerService,
          storageService: _storageService,
          token: _currentToken,
          serverUrl: _currentServerUrl,
          onHomeTap: _onHomeTap,
          onSettingsTap: _onSettingsTap,
          onProfileTap: _onProfileTap,
        );
        _navigationHistory[_currentHistoryIndex] = _currentPage;
      });
    }
  }

  /// Callback when authentication succeeds via modal.
  /// Reloads credentials and updates the UI.
  Future<void> _onAuthenticationSuccess() async {
    await _loadCredentials();
  }

  @override
  void dispose() {
    if (widget.audioPlayerService == null) {
      _audioPlayerService.dispose();
    }
    super.dispose();
  }

  void _navigateToPage(Widget page) {
    setState(() {
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
    return AuthenticationModal(
      authCheckService: _authCheckService,
      authService: PlexAuthService(),
      onAuthenticationSuccess: _onAuthenticationSuccess,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Column(
          children: [
            ApolloAppBar(
              audioPlayerService: _audioPlayerService,
              currentToken: _currentToken,
              currentServerUrl: _currentServerUrl,
              onNavigate: _navigateToPage,
              onBackPressed: _goBack,
              onForwardPressed: _goForward,
              canGoBack: _currentHistoryIndex > 0,
              canGoForward: _currentHistoryIndex < _navigationHistory.length - 1,
              onHomeTap: _onHomeTap,
              onSettingsTap: _onSettingsTap,
              onProfileTap: _onProfileTap,
            ),
            Expanded(child: _currentPage),
            PlayerBar(
              playerService: _audioPlayerService,
              onNavigate: _navigateToPage,
            ),
          ],
        ),
      ),
    );
  }
}