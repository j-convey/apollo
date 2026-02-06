import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'profile_header.dart';
import 'top_artists_section.dart';
import 'profile_option_item.dart';
import 'package:apollo/core/services/storage_service.dart';

class ProfilePage extends StatefulWidget {
  final StorageService? storageService;
  const ProfilePage({super.key, this.storageService});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final StorageService _storageService;
  String? _profileImagePath;
  String _userName = 'Plex User';

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService ?? StorageService();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final path = await _storageService.getProfileImagePath();
    final name = await _storageService.getUsername();
    if (mounted) {
      setState(() {
        _profileImagePath = path;
        if (name != null) _userName = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProfileHeader(
              userName: _userName,
              profileImagePath: _profileImagePath,
              onEditPhoto: () => _handleImagePick(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  const TopArtistsSection(),
                  const SizedBox(height: 48),
                  _buildOptions(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handles the logic for picking a new profile picture.
  Future<void> _handleImagePick(BuildContext context) async {
    final result = await _pickImage();
    final path = result?.files.single.path;
    if (path != null) {
      await _storageService.saveProfileImagePath(path);
      if (mounted) {
        setState(() {
          _profileImagePath = path;
        });
      }
      _logSelectedImage(path);
    }
  }

  Future<FilePickerResult?> _pickImage() {
    return FilePicker.platform.pickFiles(type: FileType.image);
  }

  void _logSelectedImage(String path) {
    debugPrint('Selected image: $path');
  }

  Widget _buildOptions() {
    return Column(
      children: [
        const ProfileOptionItem(icon: Icons.history, title: 'Listening History'),
        const ProfileOptionItem(icon: Icons.favorite, title: 'Favorite Artists'),
        const ProfileOptionItem(icon: Icons.playlist_play, title: 'My Playlists'),
        ProfileOptionItem(
          icon: Icons.edit,
          title: 'Edit Profile',
          onTap: () {
            // TODO: Implement profile editing logic
          },
        ),
      ],
    );
  }
}