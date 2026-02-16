import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../../core/services/web_share/web_share_service.dart';

class BrowserReceiveScreen extends StatefulWidget {
  const BrowserReceiveScreen({super.key});

  @override
  State<BrowserReceiveScreen> createState() => _BrowserReceiveScreenState();
}

class _BrowserReceiveScreenState extends State<BrowserReceiveScreen> {
  final WebShareService _webShareService = WebShareService();
  String? _receiveUrl;
  bool _isLoading = true;
  String? _error;
  String? _downloadPath;
  List<ReceivedFile> _pendingFiles = [];
  StreamSubscription<List<ReceivedFile>>? _filesSubscription;
  StreamSubscription<ReceivedFile>? _fileEventSubscription;
  bool _isSaving = false;
  bool _isSavingAll = false;

  @override
  void initState() {
    super.initState();
    _startReceiving();
  }

  @override
  void dispose() {
    // FIXED (Bug #24): Wrap stream cancellations in try-catch
    try {
      _filesSubscription?.cancel();
      _filesSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling files subscription: $e');
    }
    
    try {
      _fileEventSubscription?.cancel();
      _fileEventSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling file event subscription: $e');
    }
    
    try {
      _webShareService.dispose();
    } catch (e) {
      debugPrint('Error disposing web share service: $e');
    }
    
    super.dispose();
  }

  /// Request storage permissions on Android
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    if (await Permission.storage.request().isGranted) {
      return true;
    }

    return false;
  }

  Future<void> _startReceiving() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        setState(() {
          _error =
              'Storage permission denied. Please grant permission in settings.';
          _isLoading = false;
        });
        return;
      }

      final downloadDir = await _getDownloadDirectory();
      _downloadPath = downloadDir;

      final url = await _webShareService.startReceiving(downloadDir);

      if (url != null) {
        _filesSubscription =
            _webShareService.pendingFilesStream.listen((files) {
          if (mounted) {
            setState(() {
              _pendingFiles = files;
            });
          }
        });

        _fileEventSubscription =
            _webShareService.receivedFilesStream.listen((file) {
          if (mounted && file.status == FileReceiveStatus.pending) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Received: ${file.name}'),
                backgroundColor: AppTheme.primaryColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });

        setState(() {
          _receiveUrl = url;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to start receive server';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<String> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      const publicDownload = '/storage/emulated/0/Download';
      final downloadDir = Directory(publicDownload);

      if (await downloadDir.exists()) {
        const syndroFolder = '$publicDownload/Syndro';
        final syndroDir = Directory(syndroFolder);

        try {
          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
          }
          return syndroFolder;
        } catch (e) {
          debugPrint('Error creating Syndro folder: $e');
          return publicDownload;
        }
      }
      return publicDownload;
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        return '$userProfile\\Downloads';
      }
      return 'C:\\Users\\Public\\Downloads';
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        return '$home/Downloads';
      }
      return '/tmp';
    }

    return '/storage/emulated/0/Download';
  }

  void _copyLink() {
    if (_receiveUrl != null) {
      Clipboard.setData(ClipboardData(text: _receiveUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Get list of image files for gallery
  List<ReceivedFile> get _imageFiles {
    return _pendingFiles
        .where((f) =>
            f.isImage &&
            (f.status == FileReceiveStatus.pending ||
                f.status == FileReceiveStatus.saved))
        .toList();
  }

  /// Open image gallery preview
  void _openImageGallery(ReceivedFile file) {
    final images = _imageFiles;
    final initialIndex = images.indexOf(file);

    if (initialIndex == -1) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return ImageGalleryPreview(
            images: images,
            initialIndex: initialIndex,
            onSave: (f) async {
              await _saveFile(f);
            },
            onDiscard: (f) async {
              await _discardFile(f);
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Save a single file
  Future<void> _saveFile(ReceivedFile file) async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final success = await _webShareService.saveFile(file);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Saved: ${file.name}'
                  : '❌ Failed to save: ${file.name}',
            ),
            backgroundColor:
                success ? AppTheme.successColor : AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// Save all pending files
  Future<void> _saveAllFiles() async {
    if (_isSavingAll) return;

    final unsavedFiles = _pendingFiles
        .where((f) => f.status == FileReceiveStatus.pending)
        .toList();

    if (unsavedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files to save'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSavingAll = true);

    try {
      final result = await _webShareService.saveAllFiles();

      if (mounted) {
        String message;
        Color color;

        if (result.allSuccessful) {
          message = '✅ Saved ${result.successCount} file(s)';
          color = AppTheme.successColor;
        } else if (result.allFailed) {
          message = '❌ Failed to save all files';
          color = AppTheme.errorColor;
        } else {
          message =
              '⚠️ Saved ${result.successCount}, failed ${result.failCount}';
          color = AppTheme.warningColor;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: color,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingAll = false);
      }
    }
  }

  /// Discard a single file
  Future<void> _discardFile(ReceivedFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Discard File?'),
        content: Text('Are you sure you want to discard "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _webShareService.discardFile(file);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '🗑️ Discarded: ${file.name}'
                  : '❌ Failed to discard: ${file.name}',
            ),
            backgroundColor:
                success ? AppTheme.textSecondary : AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Discard all pending files
  Future<void> _discardAllFiles() async {
    final unsavedFiles = _pendingFiles
        .where((f) => f.status == FileReceiveStatus.pending)
        .toList();

    if (unsavedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files to discard'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('Discard All Files?'),
        content: Text(
            'Are you sure you want to discard ${unsavedFiles.length} file(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Discard All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _webShareService.discardAllFiles();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ All files discarded'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _stopReceiving() async {
    final unsavedFiles = _pendingFiles
        .where((f) => f.status == FileReceiveStatus.pending)
        .toList();

    if (unsavedFiles.isNotEmpty) {
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('Unsaved Files'),
          content: Text(
              'You have ${unsavedFiles.length} unsaved file(s). What would you like to do?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'discard'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              child: const Text('Discard & Exit'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Save All & Exit'),
            ),
          ],
        ),
      );

      if (action == 'cancel') return;

      if (action == 'save') {
        await _webShareService.saveAllFiles();
      } else if (action == 'discard') {
        await _webShareService.discardAllFiles();
      }
    }

    await _webShareService.stopSharing();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Files'),
        actions: [
          if (!_isLoading && _receiveUrl != null)
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy Link',
              onPressed: _copyLink,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Starting receive server...'),
          ],
        ),
      );
    }

    if (_error != null) {
      final isPermissionError = _error!.contains('permission');

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPermissionError ? Icons.folder_off : Icons.error_outline,
                size: 64,
                color: AppTheme.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                isPermissionError ? 'Storage Permission Required' : 'Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              if (isPermissionError) ...[
                ElevatedButton.icon(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: _startReceiving,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: <Widget>[
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Open the link on any device to send files to this device',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Download location info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.textTertiary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saving to: ${_downloadPath ?? 'Downloads'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // QR Code
          Container(
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
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: QrImageView(
                    data: _receiveUrl!,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Color(0xFF7B5EF2),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Color(0xFF1a1a2e),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ShaderMask(
                  shaderCallback: (bounds) => AppTheme.logoGradient.createShader(bounds),
                  child: const Text(
                    'Scan to send files',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'No app needed on the other device',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.cardColor.withOpacity(0.9),
                        AppTheme.surfaceColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.link,
                          size: 18,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _receiveUrl!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _copyLink,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.copy,
                            size: 18,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // URL Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _receiveUrl!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: _copyLink,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Pending Files Section
          if (_pendingFiles.isNotEmpty) ...[
            _buildPendingFilesSection(),
            const SizedBox(height: 32),
          ],

          // Stop receiving button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _stopReceiving,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Receiving'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingFilesSection() {
    final pendingCount = _pendingFiles
        .where((f) => f.status == FileReceiveStatus.pending)
        .length;
    final savedCount =
        _pendingFiles.where((f) => f.status == FileReceiveStatus.saved).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with counts
        Row(
          children: [
            Icon(
              pendingCount > 0 ? Icons.hourglass_empty : Icons.check_circle,
              color: pendingCount > 0
                  ? AppTheme.primaryColor
                  : AppTheme.successColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Received ${_pendingFiles.length} file(s)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$pendingCount pending',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.warningColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (savedCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$savedCount saved',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.successColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // Action buttons (Save All / Discard All)
        if (pendingCount > 0) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isSavingAll ? null : _saveAllFiles,
                  icon: _isSavingAll
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(_isSavingAll ? 'Saving...' : 'Save All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _discardAllFiles,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Discard All'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Files list
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingFiles.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: AppTheme.textTertiary.withOpacity(0.2),
            ),
            itemBuilder: (context, index) {
              final file = _pendingFiles[index];
              return _buildFileItem(file);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileItem(ReceivedFile file) {
    final isPending = file.status == FileReceiveStatus.pending;
    final isSaved = file.status == FileReceiveStatus.saved;
    final isDiscarded = file.status == FileReceiveStatus.discarded;
    final isSaving = file.status == FileReceiveStatus.saving;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Thumbnail with tap to preview
          _buildFileThumbnail(file),

          const SizedBox(width: 12),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isDiscarded
                        ? AppTheme.textTertiary
                        : AppTheme.textPrimary,
                    decoration:
                        isDiscarded ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      file.sizeFormatted,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(file),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          if (isPending) ...[
            IconButton(
              onPressed: _isSaving ? null : () => _saveFile(file),
              icon: const Icon(Icons.save_alt),
              color: AppTheme.successColor,
              tooltip: 'Save',
            ),
            IconButton(
              onPressed: () => _discardFile(file),
              icon: const Icon(Icons.close),
              color: AppTheme.errorColor,
              tooltip: 'Discard',
            ),
          ] else if (isSaving) ...[
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ] else if (isSaved) ...[
            const Icon(Icons.check_circle, color: AppTheme.successColor),
          ] else if (isDiscarded) ...[
            const Icon(Icons.delete, color: AppTheme.textTertiary),
          ],
        ],
      ),
    );
  }

  Widget _buildFileThumbnail(ReceivedFile file) {
    final isImage = file.isImage;
    final isVideo = file.isVideo;
    final fileType = file.fileType;
    final isPending = file.status == FileReceiveStatus.pending;
    final isSaved = file.status == FileReceiveStatus.saved;

    final canPreview = isImage && (isPending || isSaved);

    Widget thumbnail;

    if (isImage) {
      final imagePath = file.finalPath ?? file.tempPath;
      final imageFile = File(imagePath);

      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<bool>(
          future: imageFile.exists(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF472B6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            if (snapshot.data == true) {
              return Stack(
                children: [
                  Image.file(
                    imageFile,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    cacheWidth: 96,
                    errorBuilder: (_, __, ___) => _buildFileIcon(fileType),
                  ),
                  if (canPreview)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.zoom_in,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              );
            }

            return _buildFileIcon(fileType);
          },
        ),
      );
    } else if (isVideo) {
      thumbnail = Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFFB923C).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.video_file,
              color: Color(0xFFFB923C),
              size: 24,
            ),
            Positioned(
              right: 2,
              bottom: 2,
              child: Icon(
                Icons.play_circle_filled,
                size: 14,
                color: Color(0xFFFB923C),
              ),
            ),
          ],
        ),
      );
    } else {
      thumbnail = _buildFileIcon(fileType);
    }

    if (canPreview) {
      return GestureDetector(
        onTap: () => _openImageGallery(file),
        child: thumbnail,
      );
    }

    return thumbnail;
  }

  Widget _buildFileIcon(String fileType) {
    IconData icon;
    Color color;

    switch (fileType) {
      case 'image':
        icon = Icons.image;
        color = const Color(0xFFF472B6);
        break;
      case 'video':
        icon = Icons.video_file;
        color = const Color(0xFFFB923C);
        break;
      case 'audio':
        icon = Icons.audio_file;
        color = const Color(0xFFA78BFA);
        break;
      case 'document':
        icon = Icons.description;
        color = const Color(0xFF60A5FA);
        break;
      case 'spreadsheet':
        icon = Icons.table_chart;
        color = const Color(0xFF34D399);
        break;
      case 'presentation':
        icon = Icons.slideshow;
        color = const Color(0xFFFBBF24);
        break;
      case 'archive':
        icon = Icons.folder_zip;
        color = const Color(0xFFF87171);
        break;
      case 'code':
        icon = Icons.code;
        color = const Color(0xFF2DD4BF);
        break;
      case 'apk':
        icon = Icons.android;
        color = const Color(0xFFA3E635);
        break;
      case 'executable':
        icon = Icons.terminal;
        color = const Color(0xFF818CF8);
        break;
      default:
        icon = Icons.insert_drive_file;
        color = const Color(0xFF94A3B8);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildStatusBadge(ReceivedFile file) {
    String text;
    Color color;

    switch (file.status) {
      case FileReceiveStatus.pending:
        text = 'PENDING';
        color = AppTheme.warningColor;
        break;
      case FileReceiveStatus.saving:
        text = 'SAVING';
        color = AppTheme.primaryColor;
        break;
      case FileReceiveStatus.saved:
        text = 'SAVED';
        color = AppTheme.successColor;
        break;
      case FileReceiveStatus.discarded:
        text = 'DISCARDED';
        color = AppTheme.textTertiary;
        break;
      case FileReceiveStatus.error:
        text = 'ERROR';
        color = AppTheme.errorColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================
// IMAGE GALLERY PREVIEW WITH SWIPE NAVIGATION
// ============================================================

class ImageGalleryPreview extends StatefulWidget {
  final List<ReceivedFile> images;
  final int initialIndex;
  final Future<void> Function(ReceivedFile) onSave;
  final Future<void> Function(ReceivedFile) onDiscard;

  const ImageGalleryPreview({
    super.key,
    required this.images,
    required this.initialIndex,
    required this.onSave,
    required this.onDiscard,
  });

  @override
  State<ImageGalleryPreview> createState() => _ImageGalleryPreviewState();
}

class _ImageGalleryPreviewState extends State<ImageGalleryPreview> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    // FIXED (Bug #25): Wrap PageController disposal in try-catch
    try {
      _pageController.dispose();
    } catch (e) {
      debugPrint('Error disposing page controller: $e');
    }
    super.dispose();
  }

  ReceivedFile get _currentFile => widget.images[_currentIndex];

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNext() {
    if (_currentIndex < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPending = _currentFile.status == FileReceiveStatus.pending;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image PageView with swipe
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final file = widget.images[index];
              final imagePath = file.finalPath ?? file.tempPath;
              final imageFile = File(imagePath);

              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.file(
                    imageFile,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image,
                              size: 64, color: Colors.white54),
                          SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  // File info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentFile.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${_currentIndex + 1} of ${widget.images.length} • ${_currentFile.sizeFormatted}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Navigation arrows (for desktop/tablet)
          if (widget.images.length > 1) ...[
            // Left arrow
            if (_currentIndex > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: _goToPrevious,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            // Right arrow
            if (_currentIndex < widget.images.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: IconButton(
                    onPressed: _goToNext,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
          ],

          // Page indicator dots
          if (widget.images.length > 1)
            Positioned(
              bottom: isPending ? 100 : 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => Container(
                    width: index == _currentIndex ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == _currentIndex
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

          // Bottom action buttons (only for pending files)
          if (isPending)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  left: 24,
                  right: 24,
                  top: 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    // Discard button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await widget.onDiscard(_currentFile);
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Discard'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Save button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await widget.onSave(_currentFile);
                          // FIXED (Bug #26): Explicit state refresh with mounted check
                          if (mounted) {
                            setState(() {
                              // Refresh to show updated save status
                            });
                          }
                        },
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.successColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
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
