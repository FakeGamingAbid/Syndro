import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/provider_manager.dart';
import '../../core/platform/platform_detector.dart';

/// Providers screen - manage CS3 providers
class ProvidersScreen extends ConsumerStatefulWidget {
  const ProvidersScreen({super.key});

  @override
  ConsumerState<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize providers on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(providerManagerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final providerState = ref.watch(providerManagerProvider);
    final isDesktop = PlatformDetector.isDesktop;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF12121A),
              title: const Text(
                'Providers',
                style: TextStyle(
                  color: Color(0xFFE8EDF2),
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFFC8D8E8)),
                  onPressed: () {
                    ref.read(providerManagerProvider.notifier).checkForUpdates();
                  },
                ),
              ],
            ),
      body: _buildBody(providerState, isDesktop),
    );
  }

  Widget _buildBody(ProviderManagerState state, bool isDesktop) {
    if (state.state == ProviderState.loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4A6FA5),
        ),
      );
    }

    if (state.state == ProviderState.error) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFFFF6B6B),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading providers',
              style: TextStyle(
                color: const Color(0xFFE8EDF2),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'Unknown error',
              style: const TextStyle(
                color: Color(0xFF8B9BB0),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6FA5),
              ),
              onPressed: () {
                ref.read(providerManagerProvider.notifier).initialize();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_download_outlined,
              color: Color(0xFF8B9BB0),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'No providers installed',
              style: TextStyle(
                color: Color(0xFFE8EDF2),
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Providers will be downloaded automatically',
              style: TextStyle(
                color: Color(0xFF8B9BB0),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A6FA5),
              ),
              onPressed: () {
                ref.read(providerManagerProvider.notifier).initialize();
              },
              child: const Text('Check for Providers'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Desktop header
        if (isDesktop) _buildDesktopHeader(state),
        
        // Provider list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.providers.length,
            itemBuilder: (context, index) {
              return _buildProviderCard(state.providers[index], isDesktop);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(ProviderManagerState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF2A3A50),
          ),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Providers',
            style: TextStyle(
              color: Color(0xFFE8EDF2),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${state.providers.length} providers',
            style: const TextStyle(
              color: Color(0xFF8B9BB0),
            ),
          ),
          const SizedBox(width: 16),
          if (state.lastUpdate != null)
            Text(
              'Updated: ${_formatTime(state.lastUpdate!)}',
              style: const TextStyle(
                color: Color(0xFF8B9BB0),
              ),
            ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFC8D8E8)),
            onPressed: () {
              ref.read(providerManagerProvider.notifier).checkForUpdates();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(ProviderStatus provider, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: provider.isEnabled
              ? const Color(0xFF4A6FA5)
              : const Color(0xFF2A3A50),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            ref.read(providerManagerProvider.notifier).toggleProvider(
                  provider.internalName,
                  !provider.isEnabled,
                );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: provider.isLoaded
                        ? const Color(0xFF4ECDC4)
                        : provider.isEnabled
                            ? const Color(0xFFFF6B6B)
                            : const Color(0xFF4A5568),
                    boxShadow: provider.isLoaded
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4ECDC4).withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Provider info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.name,
                        style: const TextStyle(
                          color: Color(0xFFE8EDF2),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'v${provider.version}',
                            style: const TextStyle(
                              color: Color(0xFF8B9BB0),
                              fontSize: 12,
                            ),
                          ),
                          if (provider.hasUpdate) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4A6FA5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Update',
                                style: TextStyle(
                                  color: Color(0xFFE8EDF2),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Enable/Disable toggle
                Switch(
                  value: provider.isEnabled,
                  onChanged: (value) {
                    ref.read(providerManagerProvider.notifier).toggleProvider(
                          provider.internalName,
                          value,
                        );
                  },
                  activeThumbColor: const Color(0xFF4A6FA5),
                  activeTrackColor: const Color(0xFF4A6FA5).withOpacity(0.3),
                  inactiveThumbColor: const Color(0xFF4A5568),
                  inactiveTrackColor: const Color(0xFF2A3A50),
                ),
                
                // Delete button (desktop only)
                if (isDesktop) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Color(0xFFFF6B6B),
                    ),
                    onPressed: () {
                      _showDeleteDialog(provider);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(ProviderStatus provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A28),
        title: const Text(
          'Delete Provider',
          style: TextStyle(color: Color(0xFFE8EDF2)),
        ),
        content: Text(
          'Are you sure you want to delete "${provider.name}"?',
          style: const TextStyle(color: Color(0xFF8B9BB0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8B9BB0)),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(providerManagerProvider.notifier).deleteProvider(
                    provider.internalName,
                  );
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B6B)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
