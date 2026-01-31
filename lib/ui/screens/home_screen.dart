import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/device_card.dart';
import '../widgets/transfer_request_sheet.dart';
import '../../core/providers/device_provider.dart';
import '../../core/providers/transfer_provider.dart';
import '../../core/services/transfer_service.dart';
import 'file_picker_screen.dart';
import 'browser_share_screen.dart';
import 'browser_receive_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  bool _isRefreshing = false;
  bool _isShowingRequestSheet = false;
  
  // Store subscription for cleanup
  ProviderSubscription<AsyncValue<List<PendingTransferRequest>>>? _pendingRequestsSubscription;

  @override
  void initState() {
    super.initState();
    // Register lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    // Start listening for incoming transfer requests
    _listenForIncomingRequests();
  }

  @override
  void dispose() {
    // Unregister lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel subscription
    _pendingRequestsSubscription?.close();
    _pendingRequestsSubscription = null;
    
    debugPrint('🧹 HomeScreen disposed');
    super.dispose();
  }

  /// Handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    if (state == AppLifecycleState.resumed) {
      // Refresh devices when app resumes
      _refreshDevices();
    }
  }

  // Listen for incoming transfer requests and show approval dialog
  void _listenForIncomingRequests() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      _pendingRequestsSubscription = ref.listenManual<AsyncValue<List<PendingTransferRequest>>>(
        pendingTransferRequestsProvider,
        (previous, next) {
          if (!mounted) return;
          
          next.whenData((requests) {
            if (requests.isNotEmpty && !_isShowingRequestSheet && mounted) {
              _showTransferRequestSheet(requests.first);
            }
          });
        },
      );
    });
  }

  // Show the transfer request approval bottom sheet
  void _showTransferRequestSheet(PendingTransferRequest request) {
    if (_isShowingRequestSheet || !mounted) return;

    setState(() => _isShowingRequestSheet = true);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => TransferRequestSheet(
        request: request,
        onDismiss: () {
          Navigator.of(context).pop();
          if (!mounted) return;
          
          setState(() => _isShowingRequestSheet = false);

          // Check if there are more pending requests
          final pendingRequests =
              ref.read(transferServiceProvider).pendingRequests;
          if (pendingRequests.isNotEmpty) {
            // Show next request after a short delay
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && !_isShowingRequestSheet) {
                _showTransferRequestSheet(pendingRequests.first);
              }
            });
          }
        },
      ),
    );
  }

  Future<void> _refreshDevices() async {
    if (_isRefreshing || !mounted) return;

    setState(() => _isRefreshing = true);

    try {
      final service = ref.read(deviceDiscoveryServiceProvider);
      await service.refreshDevices();
    } catch (e) {
      debugPrint('Refresh error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  bool _isMobile() {
    return Platform.isAndroid;
  }

  void _showShareModeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              'Browser Share',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Share files without installing an app',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
            ),
            const SizedBox(height: 24),

            // Send Files Option
            _buildShareOption(
              icon: Icons.upload_file,
              title: 'Send Files',
              subtitle: 'Share files via browser link',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(context);
                _pickAndShareFiles();
              },
            ),
            const SizedBox(height: 12),

            // Receive Files Option
            _buildShareOption(
              icon: Icons.download,
              title: 'Receive Files',
              subtitle: 'Get files from any device',
              color: AppTheme.secondaryColor,
              onTap: () {
                Navigator.pop(context);
                _openReceiveScreen();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndShareFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();

      if (files.isNotEmpty && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => BrowserShareScreen(files: files),
          ),
        );
      }
    }
  }

  void _openReceiveScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BrowserReceiveScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDevice = ref.watch(currentDeviceProvider);
    final discoveredDevicesAsync = ref.watch(discoveredDevicesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final isInitialized = ref.watch(isDeviceServiceInitializedProvider);

    // Increased bottom padding for bigger nav bar
    final bottomPadding = _isMobile() ? 120.0 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Syndro'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshDevices,
            tooltip: 'Refresh devices',
          ),
          const SizedBox(width: 8),
          const Icon(Icons.wifi, color: AppTheme.successColor),
          const SizedBox(width: 16),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Current Device Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    color: AppTheme.cardColor.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.devices,
                              color: AppTheme.primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'This Device',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentDevice.name,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'IP Address: ${currentDevice.ipAddress}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Section Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        'Nearby Devices',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(width: 8),
                      _buildDeviceCountBadge(discoveredDevicesAsync),
                      const Spacer(),
                      if (_isRefreshing)
                        Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Scanning...',
                              style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Discovered Devices List
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: _buildDeviceList(
                      discoveredDevicesAsync,
                      isInitialized,
                      selectedDevice,
                    ),
                  ),
                ),
              ],
            ),

            // QR Button - BIGGER SIZE
              Positioned(
                right: 20,
                bottom: _isMobile() ? 110 : 20,  // Adjusted position for bigger nav bar
                child: GestureDetector(
                  onTap: _showShareModeDialog,
                  child: Container(
                    height: 64,   // Increased from 52
                    width: 64,    // Increased from 52
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
                    child: Icon(
                      Icons.qr_code,
                      color: AppTheme.primaryColor,
                      size: 30,  // Increased from 24
                    ),
                  ),
                ),
              ),

            // Send Files button (when device selected) - BIGGER SIZE
            if (selectedDevice != null)
              Positioned(
                right: 20,
                bottom: _isMobile() ? 190 : 20,  // Adjusted position
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => FilePickerScreen(
                          recipientDevice: selectedDevice,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 56,  // Increased from 52
                    padding: const EdgeInsets.symmetric(horizontal: 24),  // Increased padding
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(28),
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
                        Icon(
                          Icons.send,
                          color: AppTheme.primaryColor,
                          size: 24,  // Increased from 20
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Send Files',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,  // Increased from 14
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCountBadge(AsyncValue<List<dynamic>> devicesAsync) {
    return devicesAsync.when(
      data: (devices) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          '${devices.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.textTertiary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceList(
    AsyncValue<List<dynamic>> devicesAsync,
    bool isInitialized,
    dynamic selectedDevice,
  ) {
    if (!isInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing...'),
          ],
        ),
      );
    }

    return devicesAsync.when(
      data: (devices) {
        if (devices.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshDevices,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.devices,
                        size: 64,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Make sure other devices have Syndro open and are on the same WiFi network',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _isRefreshing ? null : _refreshDevices,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Scan Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _refreshDevices,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final device = devices[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DeviceCard(
                  device: device,
                  isSelected: selectedDevice?.id == device.id,
                  onTap: () {
                    ref.read(selectedDeviceProvider.notifier).state = device;
                  },
                ),
              );
            },
          ),
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Scanning for devices...',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Error discovering devices',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error.toString(),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refreshDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
