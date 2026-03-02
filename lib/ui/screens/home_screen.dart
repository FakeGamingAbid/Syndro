import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../theme/app_theme.dart';
import '../widgets/device_card.dart';
import '../../core/models/device.dart';
import '../../core/providers/device_provider.dart';
import '../../core/providers/transfer_provider.dart';
import '../../core/services/transfer_service.dart';
import '../../core/l10n/app_localizations.dart';
import 'file_picker_screen.dart';
import 'browser_share_screen.dart';
import 'browser_receive_screen.dart';

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
  
  // FIX (Bug #6): Store timer reference for cancellation on dispose
  Timer? _pendingRequestTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForIncomingRequests();
  }

  // FIX (Bug #3): Ensure all subscriptions are properly cancelled
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // FIX (Bug #6): Cancel pending request timer
    _pendingRequestTimer?.cancel();
    _pendingRequestTimer = null;
    
    // Cancel subscription with try-catch
    try {
      _pendingRequestsSubscription?.close();
      _pendingRequestsSubscription = null;
    } catch (e) {
      debugPrint('Error closing pending requests subscription: $e');
    }
    
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
    // Create subscription directly in initState to avoid race condition
    // with addPostFrameCallback and fast dispose scenarios
    try {
      _pendingRequestsSubscription =
          ref.listenManual<AsyncValue<List<PendingTransferRequest>>>(
        pendingTransferRequestsProvider,
        (previous, next) {
          // Check mounted state synchronously before any async operations
          if (!mounted || _isShowingRequestSheet) return;
          
          next.whenData((requests) {
            // Check again inside whenData callback
            if (requests.isNotEmpty && mounted && !_isShowingRequestSheet) {
              _showTransferRequestSheet(requests.first);
            }
          });
        },
      );
    } catch (e) {
      debugPrint('⚠️ Error creating pending requests subscription: $e');
    }
  }

  void _showTransferRequestSheet(PendingTransferRequest request) {
    if (_isShowingRequestSheet || !mounted) return;
    setState(() => _isShowingRequestSheet = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder: (bottomSheetContext) {
          return _TransferRequestSheetContent(
            request: request,
            onAccept: () async {
              if (!mounted) return;
              Navigator.of(bottomSheetContext).pop();
              if (!mounted) return;
              await Future.delayed(const Duration(milliseconds: 100));
              if (!mounted) return;

              try {
                final transferService = ref.read(transferServiceProvider);
                await transferService.approveTransfer(request.requestId);

                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.transferAccepted),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              } catch (e) {
                debugPrint('Error accepting transfer: $e');
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text('${l10n.failedToAccept}: ${e.toString()}'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
              }
            },
            onReject: () async {
              if (!mounted) return;
              Navigator.of(bottomSheetContext).pop();
              if (!mounted) return;
              await Future.delayed(const Duration(milliseconds: 100));
              if (!mounted) return;

              try {
                final transferService = ref.read(transferServiceProvider);
                transferService.rejectTransfer(request.requestId);

                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.transferRejected),
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

        try {
          if (!mounted) return;
          final pendingRequests =
              ref.read(transferServiceProvider).pendingRequests;
          if (pendingRequests.isNotEmpty) {
            // FIX (Bug #6): Store timer reference for cancellation on dispose
            _pendingRequestTimer?.cancel();
            _pendingRequestTimer = Timer(const Duration(milliseconds: 300), () {
              if (mounted && !_isShowingRequestSheet) {
                _showTransferRequestSheet(pendingRequests.first);
              }
            });
          }
        } catch (e) {
          debugPrint('Error checking pending requests: $e');
        }
      });
    } catch (e) {
      debugPrint('⚠️ Error showing transfer request sheet: $e');
      // FIXED (Bug #4): Reset flag if sheet fails to show
      if (mounted) {
        setState(() => _isShowingRequestSheet = false);
      }
    }
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

  // FIX (Bug #13): Ensure loading dialog is always dismissed
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 24,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: AppTheme.primaryColor,
                ),
                SizedBox(height: 20),
                Text(
                  'Preparing files...',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This may take a moment for large files',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // FIX (Bug #13 & #14): Safe dialog dismissal helper
  void _dismissLoadingDialog() {
    if (mounted && context.mounted) {
      try {
        // Use root navigator to ensure we dismiss the right dialog
        Navigator.of(context, rootNavigator: true).pop();
      } catch (e) {
        debugPrint('Error dismissing dialog: $e');
      }
    }
  }

  void _showShareModeDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
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
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Share files without installing an app',
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to the same WiFi network or create a Hotspot',
              style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                    color: AppTheme.warningColor,
                  ),
            ),
            const SizedBox(height: 24),
            _buildShareOption(
              context: sheetContext,
              icon: Icons.photo_library,
              title: 'Share Media',
              subtitle: 'Photos and videos from gallery',
              color: const Color(0xFFF472B6),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndShareMedia();
              },
            ),
            const SizedBox(height: 12),
            _buildShareOption(
              context: sheetContext,
              icon: Icons.upload_file,
              title: 'Send Files',
              subtitle: 'Share files via browser link',
              color: AppTheme.primaryColor,
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndShareFiles();
              },
            ),
            const SizedBox(height: 12),
            _buildShareOption(
              context: sheetContext,
              icon: Icons.download,
              title: 'Receive Files',
              subtitle: 'Get files from any device',
              color: AppTheme.secondaryColor,
              onTap: () {
                Navigator.pop(sheetContext);
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
    required BuildContext context,
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

  // ============================================
  // FIXED: _pickAndShareMedia with loading dialog
  // ============================================
  Future<void> _pickAndShareMedia() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.media,
    );

    if (result != null && result.files.isNotEmpty && mounted) {
      // Calculate total size for large file warning
      int totalSize = 0;
      for (final file in result.files) {
        totalSize += file.size;
      }
      
      // Show warning for large files (> 2GB)
      const int largeFileThreshold = 2 * 1024 * 1024 * 1024;
      if (totalSize > largeFileThreshold) {
        final shouldProceed = await _showLargeFileWarningDialog(totalSize);
        if (!shouldProceed) return;
      }

      _showLoadingDialog();

      try {
        await Future.delayed(const Duration(milliseconds: 100));

        final files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();

        _dismissLoadingDialog();

        if (files.isNotEmpty && mounted) {
          _openBrowserShareScreen(files, ShareMode.media);
        }
      } catch (e) {
        debugPrint('Error processing media files: $e');
        _dismissLoadingDialog();
        
        // FIX (Bug #18): Show error feedback to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing files: $e'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _pickAndShareMedia,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _pickAndShareFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty && mounted) {
      // Calculate total size for large file warning
      int totalSize = 0;
      for (final file in result.files) {
        totalSize += file.size;
      }
      
      // Show warning for large files (> 2GB)
      const int largeFileThreshold = 2 * 1024 * 1024 * 1024;
      if (totalSize > largeFileThreshold) {
        final shouldProceed = await _showLargeFileWarningDialog(totalSize);
        if (!shouldProceed) return;
      }

      _showLoadingDialog();

      try {
        await Future.delayed(const Duration(milliseconds: 100));

        final files = result.files
            .where((f) => f.path != null)
            .map((f) => File(f.path!))
            .toList();

        _dismissLoadingDialog();

        if (files.isNotEmpty && mounted) {
          _openBrowserShareScreen(files, ShareMode.files);
        }
      } catch (e) {
        debugPrint('Error processing files: $e');
        _dismissLoadingDialog();
        
        // FIX (Bug #18): Show error feedback to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing files: $e'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _pickAndShareFiles,
              ),
            ),
          );
        }
      }
    }
  }
  
  /// Show warning dialog for large file transfers
  /// Returns true if user wants to proceed, false otherwise
  Future<bool> _showLargeFileWarningDialog(int totalSize) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppTheme.warningColor.withOpacity(0.3),
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
            const SizedBox(width: 12),
            const Text('Large File Warning'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to share ${_formatBytes(totalSize)}.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text(
              'Large files may take longer to prepare and could cause '
              'browser performance issues during download.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Tip: For better performance with large files, '
                      'use direct device-to-device transfer instead.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue with Browser Share'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
  
  /// Format bytes to human readable string
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void _openBrowserShareScreen(List<File> files, ShareMode shareMode) {
    if (!mounted) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      showDialog(
        context: context,
        builder: (dialogContext) => Dialog(
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
          builder: (routeContext) => BrowserShareScreen(
            files: files,
            shareMode: shareMode,
          ),
        ),
      );
    }
  }

  void _openReceiveScreen() {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => const BrowserReceiveScreen(),
      ),
    );
  }

  Widget _buildCurrentDeviceCard(BuildContext context, dynamic currentDevice) {
    // Get custom nickname if available
    final customNickname = ref.watch(currentDeviceNicknameProvider);
    final displayName = customNickname ?? currentDevice.name;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardColor.withOpacity(0.8),
            AppTheme.surfaceColor.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppTheme.logoGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.devices,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'This Device',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppTheme.successColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Online',
                              style: TextStyle(
                                color: AppTheme.successColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.wifi_rounded,
                        size: 14,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentDevice.ipAddress,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentDevice = ref.watch(currentDeviceProvider);
    final discoveredDevicesAsync = ref.watch(discoveredDevicesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final isInitialized = ref.watch(isDeviceServiceInitializedProvider);

    final bottomPadding = _isMobile() ? 120.0 : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.logoGradient,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.share,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Syndro'),
          ],
        ),
        actions: const [],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildCurrentDeviceCard(context, currentDevice),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: AppTheme.logoGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 12),
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

            // Browser Share FAB
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

            // Send Files FAB (when device selected)
            if (selectedDevice != null)
              Positioned(
                right: 20,
                bottom: _isMobile() ? 190 : 80, // Raised from 20 to 80 for desktop
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (routeContext) => FilePickerScreen(
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
            
            // Multi-select Send FAB (when multiple devices selected)
            if (ref.watch(selectedDevicesProvider).isNotEmpty)
              Positioned(
                right: 20,
                bottom: _isMobile() ? 190 : 80,
                child: GestureDetector(
                  onTap: () {
                    final selectedDevices = ref.read(selectedDevicesProvider);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (routeContext) => FilePickerScreen(
                          recipientDevices: selectedDevices.toList(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: AppTheme.logoGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.send,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Send to ${ref.watch(selectedDevicesProvider).length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            
            // Multi-select cancel button
            if (ref.watch(selectedDevicesProvider).isNotEmpty)
              Positioned(
                left: 20,
                bottom: _isMobile() ? 190 : 80,
                child: GestureDetector(
                  onTap: () {
                    ref.read(selectedDevicesProvider.notifier).state = {};
                  },
                  child: Container(
                    height: 56,
                    width: 56,
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
                        color: AppTheme.errorColor.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppTheme.errorColor,
                      size: 24,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(l10n.initializing),
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
                              l10n.noDevicesFound,
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
                                l10n.noDevicesTip,
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
                            label: Text(l10n.scanAgain),
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
              final selectedDevices = ref.watch(selectedDevicesProvider);
              final isMultiSelectMode = selectedDevices.isNotEmpty;
              final isSelected = selectedDevices.any((d) => d.id == device.id) || 
                                 (!isMultiSelectMode && selectedDevice?.id == device.id);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DeviceCard(
                  device: device,
                  isSelected: isSelected,
                  onTap: () {
                    if (isMultiSelectMode) {
                      // Multi-select mode: toggle device in selection
                      final currentSelection = Set<Device>.from(selectedDevices);
                      if (currentSelection.any((d) => d.id == device.id)) {
                        currentSelection.removeWhere((d) => d.id == device.id);
                      } else {
                        currentSelection.add(device);
                      }
                      ref.read(selectedDevicesProvider.notifier).state = currentSelection;
                      // Clear single selection when in multi-select mode
                      ref.read(selectedDeviceProvider.notifier).state = null;
                    } else {
                      // Single-select mode
                      ref.read(selectedDeviceProvider.notifier).state = device;
                    }
                  },
                  onLongPress: () {
                    // Enter multi-select mode on long press
                    if (!isMultiSelectMode) {
                      ref.read(selectedDevicesProvider.notifier).state = {device};
                      ref.read(selectedDeviceProvider.notifier).state = null;
                    }
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
              l10n.scanningForDevices,
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
              l10n.errorDiscoveringDevices,
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
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

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
