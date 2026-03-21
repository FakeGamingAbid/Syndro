import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/browse/browse_screen.dart';
import '../features/downloads/downloads_screen.dart';
import '../features/providers/providers_screen.dart';
import '../features/settings/settings_screen.dart';

/// Desktop shell with left sidebar navigation.
/// Used for Windows, Linux, and macOS.
class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({super.key});

  @override
  ConsumerState<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<DesktopShell> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  
  final List<String> _sidebarItems = [
    'Home',
    'Search',
    'Browse',
    'Downloads',
    'Providers',
    'Settings',
  ];

  final List<IconData> _sidebarIcons = [
    Icons.home_rounded,
    Icons.search_rounded,
    Icons.explore_rounded,
    Icons.download_rounded,
    Icons.extension_rounded,
    Icons.settings_rounded,
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    BrowseScreen(),
    DownloadsScreen(),
    ProvidersScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Row(
        children: [
          // Collapsible sidebar
          _buildSidebar(),
          // Main content
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: _isSidebarExpanded ? 240 : 72,
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
        border: Border(
          right: BorderSide(
            color: Color(0xFF2A3A50),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header with logo
          _buildSidebarHeader(),
          const SizedBox(height: 16),
          // Navigation items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _sidebarItems.length,
              itemBuilder: (context, index) => _buildNavItem(index),
            ),
          ),
          // Collapse toggle
          _buildCollapseToggle(),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Moon icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFC8D8E8),
                  Color(0xFF8BA7C0),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.nightlight_round,
              color: Color(0xFF0A0A0F),
              size: 24,
            ),
          ),
          if (_isSidebarExpanded) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Moonplex',
                style: TextStyle(
                  color: Color(0xFFE8EDF2),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFF4A6FA5).withOpacity(0.1),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarExpanded ? 16 : 12,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected 
                ? const Color(0xFF4A6FA5).withOpacity(0.2) 
                : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected 
                ? Border.all(
                    color: const Color(0xFF4A6FA5).withOpacity(0.5),
                    width: 1,
                  )
                : null,
            ),
            child: Row(
              mainAxisAlignment: _isSidebarExpanded 
                ? MainAxisAlignment.start 
                : MainAxisAlignment.center,
              children: [
                Icon(
                  _sidebarIcons[index],
                  color: isSelected 
                    ? const Color(0xFFC8D8E8) 
                    : const Color(0xFF8B9BB0),
                  size: 24,
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _sidebarItems[index],
                      style: TextStyle(
                        color: isSelected 
                          ? const Color(0xFFC8D8E8) 
                          : const Color(0xFF8B9BB0),
                        fontSize: 14,
                        fontWeight: isSelected 
                          ? FontWeight.w600 
                          : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A28),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: _isSidebarExpanded 
                ? MainAxisAlignment.end 
                : MainAxisAlignment.center,
              children: [
                Icon(
                  _isSidebarExpanded 
                    ? Icons.chevron_left_rounded 
                    : Icons.chevron_right_rounded,
                  color: const Color(0xFF8B9BB0),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
