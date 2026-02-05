import '../../../core/services/storage_service.dart';

/// Service responsible for checking authentication status.
/// Single Responsibility: Only checks if user is authenticated.
class AuthenticationCheckService {
  final StorageService _storageService;

  AuthenticationCheckService(this._storageService);

  /// Check if user has valid authentication credentials.
  /// Returns true if token exists.
  Future<bool> isUserAuthenticated() async {
    final token = await _storageService.getPlexToken();
    return token != null && token.isNotEmpty;
  }

  /// Check if user has selected any libraries to sync.
  /// Returns true if at least one library is selected.
  Future<bool> hasSelectedLibraries() async {
    final selectedServers = await _storageService.getSelectedServers();
    return selectedServers.isNotEmpty;
  }

  /// Check if this is the first time opening the app.
  /// Returns true if no credentials and no libraries are set up.
  Future<bool> isFirstTimeUser() async {
    final isAuthenticated = await isUserAuthenticated();
    final hasLibraries = await hasSelectedLibraries();
    return !isAuthenticated || !hasLibraries;
  }
}
