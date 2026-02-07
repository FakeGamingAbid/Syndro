import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    SettingsScreen(),
  ];

  final List<NavigationRailDestination> _railDestinations = const [
    NavigationRailDestination(
      icon: Icon(Icons.devices_outlined),
      selectedIcon: Icon(Icons.devices),
      label: Text('Devices'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: Text('History'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('Settings'),
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Check if we should use desktop layout
  bool _isDesktop() {
    return Platform.isWindows || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop()) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  /// Desktop layout with NavigationRail (side navigation)
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Side Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            backgroundColor: AppTheme.surfaceColor,
            indicatorColor: AppTheme.primaryColor.withOpacity(0.2),
            selectedIconTheme: const IconThemeData(
              color: AppTheme.primaryColor,
            ),
            unselectedIconTheme: const IconThemeData(
              color: AppTheme.textTertiary,
            ),
            selectedLabelTextStyle: const TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: const TextStyle(
              color: AppTheme.textTertiary,
            ),
            extended: true,
            minExtendedWidth: 180,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.share,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Syndro',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            destinations: _railDestinations,
          ),
          // Vertical divider
          const VerticalDivider(
            thickness: 1,
            width: 1,
            color: AppTheme.cardColor,
          ),
          // Main content
          Expanded(
            child: _screens[_selectedIndex],
          ),
        ],
      ),
    );
  }

  /// Mobile layout with Floating Bottom Navigation Bar
  Widget _buildMobileLayout() {
    return Scaffold(
      body: Stack(
        children: [
          // Main content
          _screens[_selectedIndex],

          // Floating Navigation Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: AppTheme.cardColor,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.devices_outlined,
                      selectedIcon: Icons.devices,
                      label: 'Devices',
                    ),
                    const SizedBox(width: 8),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.history_outlined,
                      selectedIcon: Icons.history,
                      label: 'History',
                    ),
                    const SizedBox(width: 8),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.settings_outlined,
                      selectedIcon: Icons.settings,
                      label: 'Settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual navigation item for floating bar
  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => _onDestinationSelected(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? selectedIcon : icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textTertiary,
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
