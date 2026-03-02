import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/device.dart';
import '../../core/models/transfer.dart';
import '../../core/providers/device_provider.dart';
import '../../core/l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/device_card.dart';
import '../widgets/file_preview_widgets.dart';
import 'file_picker_screen.dart';

/// Screen for quick sending files received from right-click context menu
class QuickSendScreen extends ConsumerStatefulWidget {
  final List<TransferItem> files;
  final VoidCallback onComplete;

  const QuickSendScreen({
    super.key,
    required this.files,
    required this.onComplete,
  });

  @override
  ConsumerState<QuickSendScreen> createState() => _QuickSendScreenState();
}

class _QuickSendScreenState extends ConsumerState<QuickSendScreen> {
  AppLocalizations? _l10n;
  
  @override
  void initState() {
    super.initState();
    // FIXED (Bug #11): Add error handling for device discovery
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          ref.read(deviceDiscoveryProvider.notifier).startDiscovery();
        } catch (e) {
          debugPrint('⚠️ Error starting discovery: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error starting device discovery: $e'),
                backgroundColor: AppTheme.errorColor,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () {
                    ref.read(deviceDiscoveryProvider.notifier).startDiscovery();
                  },
                ),
              ),
            );
          }
        }
      }
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  int get _totalSize => widget.files.fold(0, (sum, item) => sum + item.size);

  void _selectDevice(Device device) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => FilePickerScreen(
          recipientDevice: device,
          preselectedFiles: widget.files,
        ),
      ),
    );
  }

  void _cancel() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    _l10n = AppLocalizations.of(context)!;
    final l10n = _l10n!;
    
    final discoveredDevices = ref.watch(deviceDiscoveryProvider);
    final isScanning = ref.watch(deviceDiscoveryProvider.notifier).isScanning;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // File summary
              _buildFileSummary(),
              // Device list
              Expanded(
                child: _buildDeviceList(discoveredDevices, isScanning),
              ),
              // Cancel button
              _buildCancelButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(24),
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
              Icons.send_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.logoGradient.createShader(bounds),
                  child: Text(
                    l10n.sendFiles,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a device to send your files',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSummary() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceColor.withOpacity(0.9),
            AppTheme.cardColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Show thumbnail for images/videos, icon for others
          _buildFileIcon(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.files.length == 1
                      ? widget.files.first.name
                      : '${widget.files.length} items selected',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.storage_rounded,
                      size: 14,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatBytes(_totalSize),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // File count badge
          if (widget.files.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppTheme.logoGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${widget.files.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileIcon() {
    // For single file, show thumbnail if it's an image/video
    if (widget.files.length == 1) {
      final file = widget.files.first;
      final fileName = file.name.toLowerCase();
      
      // Check if it's an image or video
      final isImage = fileName.endsWith('.jpg') || 
                      fileName.endsWith('.jpeg') || 
                      fileName.endsWith('.png') || 
                      fileName.endsWith('.gif') || 
                      fileName.endsWith('.webp') ||
                      fileName.endsWith('.heic') ||
                      fileName.endsWith('.heif');
      
      final isVideo = fileName.endsWith('.mp4') || 
                      fileName.endsWith('.mov') || 
                      fileName.endsWith('.avi') || 
                      fileName.endsWith('.mkv') ||
                      fileName.endsWith('.webm');
      
      if ((isImage || isVideo) && file.path.isNotEmpty) {
        // Show thumbnail
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: FilePreviewWidget(
            filePath: file.path,
            fileName: file.name,
            size: 56,
            borderRadius: BorderRadius.circular(14),
          ),
        );
      }
      
      // Show folder icon for directories
      if (file.isDirectory) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppTheme.logoGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.folder_rounded,
            color: Colors.white,
            size: 26,
          ),
        );
      }
    }
    
    // Default icon for multiple files or non-media files
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.logoGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        widget.files.length == 1
            ? Icons.insert_drive_file_rounded
            : Icons.folder_copy_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _buildDeviceList(List<Device> devices, bool isScanning) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Available Devices',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              if (isScanning)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: devices.isEmpty
                ? _buildEmptyState(isScanning)
                : ListView.separated(
                    itemCount: devices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return DeviceCard(
                        device: device,
                        onTap: () => _selectDevice(device),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isScanning) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isScanning ? Icons.radar_rounded : Icons.devices_other_rounded,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? 'Scanning for devices...' : 'No devices found',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Make sure other devices are on the same network',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textTertiary,
            ),
          ),
          if (!isScanning) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                ref.read(deviceDiscoveryProvider.notifier).startDiscovery();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Scan Again'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _cancel,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(
              color: AppTheme.borderColor.withOpacity(0.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
