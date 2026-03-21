import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home/home_screen.dart';
import '../features/search/search_screen.dart';
import '../features/browse/browse_screen.dart';
import '../features/providers/providers_screen.dart';
import '../features/settings/settings_screen.dart';

/// TV shell with top navigation bar.
/// Used for Android TV with D-pad navigation.
class TVShell extends ConsumerStatefulWidget {
  const TVShell({super.key});

  @override
  ConsumerState<TVShell> createState() => _TVShellState();
}

class _TVShellState extends ConsumerState<TVShell> {
  int _selectedIndex = 0;
  final FocusNode _focusNode = FocusNode();
  
  final List<String> _tabs = [
    'Home',
    'Search',
    'Browse',
    'Providers',
    'Settings',
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    SearchScreen(),
    BrowseScreen(),
    ProvidersScreen(),
    SettingsScreen(),
  ];

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Column(
        children: [
          // Top navigation bar
          _buildTopNavigationBar(),
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

  Widget _buildTopNavigationBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF2A3A50),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(icon: Icons.home_rounded, label: 'Home', index: 0),
          _buildNavItem(icon: Icons.search_rounded, label: 'Search', index: 1),
          _buildNavItem(icon: Icons.explore_rounded, label: 'Browse', index: 2),
          _buildNavItem(icon: Icons.extension_rounded, label: 'Providers', index: 3),
          _buildNavItem(icon: Icons.settings_rounded, label: 'Settings', index: 4),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;
    
    return Focus(
      focusNode: _focusNode,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected 
              ? const Color(0xFF4A6FA5).withOpacity(0.3) 
              : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected 
              ? Border.all(
                  color: const Color(0xFF4A6FA5),
                  width: 2,
                )
              : null,
            boxShadow: isSelected 
              ? [
                  BoxShadow(
                    color: const Color(0xFF4A6FA5).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected 
                  ? const Color(0xFFC8D8E8) 
                  : const Color(0xFF8B9BB0),
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                    ? const Color(0xFFC8D8E8) 
                    : const Color(0xFF8B9BB0),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
