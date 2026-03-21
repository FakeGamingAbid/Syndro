import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/providers/providers_screen.dart';
import '../features/settings/settings_screen.dart';

/// Mobile shell with bottom navigation bar.
/// Used for Android phone and tablet.
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key});

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    DownloadsScreen(),
    ProvidersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomSheet: _buildMiniPlayer(),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// Builds the bottom navigation bar with 5 tabs.
  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
        border: Border(
          top: BorderSide(
            color: Color(0xFF2A3A50),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
              _buildNavItem(icon: Icons.search_rounded, label: 'Search', index: 1),
              _buildNavItem(icon: Icons.download_rounded, label: 'Downloads', index: 2),
              _buildNavItem(icon: Icons.extension_rounded, label: 'Providers', index: 3),
              _buildNavItem(icon: Icons.settings_rounded, label: 'Settings', index: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
            ? const Color(0xFF4A6FA5).withOpacity(0.2) 
            : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected 
                ? const Color(0xFFC8D8E8) 
                : const Color(0xFF8B9BB0),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected 
                  ? const Color(0xFFC8D8E8) 
                  : const Color(0xFF8B9BB0),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the mini player placeholder at the bottom.
  Widget _buildMiniPlayer() {
    return Container(
      height: 64,
      margin: const EdgeInsets.only(bottom: 64), // Account for bottom nav
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A28),
        border: Border(
          top: BorderSide(
            color: Color(0xFF2A3A50),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // TODO: Navigate to full player
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Poster placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3A50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_circle_fill,
                    color: Color(0xFF8B9BB0),
                  ),
                ),
                const SizedBox(width: 12),
                // Title and progress
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No media playing',
                        style: TextStyle(
                          color: Color(0xFFE8EDF2),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: 0,
                        backgroundColor: Color(0xFF2A3A50),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A6FA5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Controls
                IconButton(
                  icon: const Icon(
                    Icons.pause_rounded,
                    color: Color(0xFF8B9BB0),
                  ),
                  onPressed: null, // Disabled when nothing playing
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
