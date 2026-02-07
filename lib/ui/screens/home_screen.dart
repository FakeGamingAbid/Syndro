import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/device_card.dart';
import '../../core/providers/device_provider.dart';
import '../../core/providers/transfer_provider.dart';
import '../../core/services/transfer_service.dart';
import 'file_picker_screen.dart';
import 'browser_share_screen.dart';
import 'browser_receive_screen.dart';
import 'home_screen_strings.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  bool _isRefreshing = false;
  bool _isShowingRequestSheet = false;

  ProviderSubscription<AsyncValue<List<PendingTransferRequest>>>?
      _pendingRequestsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForIncomingRequests();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingRequestsSubscription?.close();
    _pendingRequestsSubscription = null;
    debugPrint('🧹 HomeScreen disposed');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshDevices();
    }
  }

  void _listenForIncomingRequests() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _pendingRequestsSubscription =
          ref.listenManual<AsyncValue<List<PendingTransferRequest>>>(
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

  void _showTransferRequestSheet(PendingTransferRequest request) {
    if (_isShowingRequestSheet || !mounted) return;

    setState(() => _isShowingRequestSheet = true);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _TransferRequestSheetContent(
          request: request,
          onAccept: () async {
            Navigator.of(bottomSheetContext).pop();
            await Future.delayed(const Duration(milliseconds: 100));

            if (!mounted) return;

            try {
              final transferService = ref.read(transferServiceProvider);
              transferService.approveTransfer(request.requestId);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(HomeScreenStrings.transferAccepted),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            } catch (e) {
              debugPrint('Error accepting transfer: $e');
              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(HomeScreenStrings.failedToAccept(e.toString())),
                  backgroundColor: AppTheme.errorColor,
                ),
              );
            }
          },
          onReject: () async {
            Navigator.of(bottomSheetContext).pop();
            await Future.delayed(const Duration(milliseconds: 100));

            if (!mounted) return;

            try {
              final transferService = ref.read(transferServiceProvider);
              transferService.rejectTransfer(request.requestId);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(HomeScreenStrings.transferRejected),
                  backgroundColor: AppTheme.warningColor,
                ),
              );
            } catch (e) {
              debugPrint('Error rejecting transfer: $e');
            }
          },
        );
      },
    ).whenComplete(() {
      if (!mounted) return;
      setState(() => _isShowingRequestSheet = false);

      if (!mounted) return;

      try {
        final pendingRequests =
            ref.read(transferServiceProvider).pendingRequests;
        if (pendingRequests.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && !_isShowingRequestSheet) {
              _showTransferRequestSheet(pendingRequests.first);
            }
          });
        }
      } catch (e) {
        debugPrint('Error checking pending requests: $e');
      }
    });
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
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 8),
            Text(
              'Connect to the same WiFi network or create a Hotspot',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.warningColor,
                  ),
            ),
            const SizedBox(height: 24),
            // Share Media Option - Opens media picker directly
            _buildShareOption(
              icon: Icons.photo_library,
              title: 'Share Media',
              subtitle: 'Photos and videos from gallery',
              color: const Color(0xFFF472B6),
              onTap: () {
                Navigator.pop(context);
                _pickAndShareMedia();
              },
            ),
            const SizedBox(height: 12),
            // Share Files Option
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
              const Icon(
                Icons.chevron_right,
                color: AppTheme.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick media (photos/videos) and share them directly - NO SEPARATE SCREEN
  Future<void> _pickAndShareMedia() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.media, // Only photos and videos
    );

    if (result != null && result.files.isNotEmpty) {
      final files = result.files
          .where((f) => f.path != null)
          .map((f) => File(f.path!))
          .toList();

      if (files.isNotEmpty && mounted) {
        _openBrowserShareScreen(files, ShareMode.media);
      }
    }
  }

  /// Pick files and share them - uses ShareMode.files
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
        _openBrowserShareScreen(files, ShareMode.files);
      }
    }
  }

  void _openBrowserShareScreen(List<File> files, ShareMode shareMode) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 450,
                maxHeight: 650,
              ),
              child: BrowserShareScreen(
                files: files,
                shareMode: shareMode,
              ),
            ),
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BrowserShareScreen(
            files: files,
            shareMode: shareMode,
          ),
        ),
      );
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
            tooltip: 'Refresh',
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
                            child: const Icon(
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
                        const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(width: 8),
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

            // Browser Share Button
            Positioned(
              right: 20,
              bottom: _isMobile() ? 110 : 20,
              child: GestureDetector(
                onTap: _showShareModeDialog,
                child: Container(
                  height: 64,
                  width: 64,
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
                  child: const Icon(
                    Icons.language,
                    color: AppTheme.primaryColor,
                    size: 30,
                  ),
                ),
              ),
            ),

            // Send Files button
            if (selectedDevice != null)
              Positioned(
                right: 20,
                bottom: _isMobile() ? 190 : 20,
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
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.send,
                          color: AppTheme.primaryColor,
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Send Files',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
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
            Text(HomeScreenStrings.initializing),
          ],
        ),
      );
    }

    return devicesAsync.when(
      data: (devices) {
        if (devices.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshDevices,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenHeight = MediaQuery.of(context).size.height;
                final isSmallScreen = screenHeight < 600;
                final emptyStateHeight = isSmallScreen
                    ? (screenHeight * 0.6).clamp(300.0, 500.0)
                    : (screenHeight * 0.4).clamp(350.0, 600.0);

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: emptyStateHeight,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.devices,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            HomeScreenStrings.noDevicesFound,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              HomeScreenStrings.noDevicesTip,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _isRefreshing ? null : _refreshDevices,
                            icon: const Icon(Icons.refresh),
                            label: const Text(HomeScreenStrings.scanAgain),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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
            const Icon(
              Icons.devices,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              HomeScreenStrings.scanningForDevices,
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
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 16),
            Text(
              HomeScreenStrings.errorDiscoveringDevices,
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
              label: const Text(HomeScreenStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}

/// Separate StatelessWidget for bottom sheet content
class _TransferRequestSheetContent extends StatelessWidget {
  final PendingTransferRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _TransferRequestSheetContent({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.file_download_rounded,
              color: AppTheme.primaryColor,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Incoming Transfer',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'From: ${request.senderName}',
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${request.fileCount} file(s) • ${_formatSize(request.totalSize)}',
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('REJECT'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('ACCEPT'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
