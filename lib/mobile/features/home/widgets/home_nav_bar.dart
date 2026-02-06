import 'package:flutter/material.dart';

/// Top navigation bar for the home page with profile picture and filter chips.
class HomeNavBar extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  
  const HomeNavBar({
    super.key,
    this.onOpenDrawer,
  });

  @override
  State<HomeNavBar> createState() => _HomeNavBarState();
}

class _HomeNavBarState extends State<HomeNavBar> {
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Profile picture
          GestureDetector(
            onTap: () {
              widget.onOpenDrawer?.call();
            },
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF282828),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedFilter == 'All',
                    onTap: () {
                      setState(() => _selectedFilter = 'All');
                      // TODO: Filter to show all content
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Library',
                    isSelected: _selectedFilter == 'Library',
                    onTap: () {
                      setState(() => _selectedFilter = 'Library');
                      // TODO: Filter to show library content
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Playlists',
                    isSelected: _selectedFilter == 'Playlists',
                    onTap: () {
                      setState(() => _selectedFilter = 'Playlists');
                      // TODO: Filter to show playlists
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Artists',
                    isSelected: _selectedFilter == 'Artists',
                    onTap: () {
                      setState(() => _selectedFilter = 'Artists');
                      // TODO: Filter to show artists
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF282828),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
