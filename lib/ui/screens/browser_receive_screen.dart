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
  final List<ReceivedFile> _receivedFiles = [];
  StreamSubscription<ReceivedFile>? _subscription;

  @override
  void initState() {
    super.initState();
    _startReceiving();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _webShareService.dispose();
    super.dispose();
  }

  /// Request storage permissions on Android
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // Check Android version
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // For Android 11+ (API 30+), need MANAGE_EXTERNAL_STORAGE
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }

    // Try legacy storage permission for older Android versions
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
      // Request storage permission first
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        setState(() {
          _error = 'Storage permission denied. Please grant permission in settings.';
          _isLoading = false;
        });
        return;
      }

      // Get download directory
      final downloadDir = await _getDownloadDirectory();
      _downloadPath = downloadDir;

      final url = await _webShareService.startReceiving(downloadDir);

      if (url != null) {
        _subscription = _webShareService.receivedFilesStream.listen((file) {
          if (mounted) {
            setState(() {
              _receivedFiles.add(file);
            });
            
            // Show snackbar for each received file
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Received: ${file.name}'),
                backgroundColor: AppTheme.successColor,
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
      // Use public Downloads folder
      const publicDownload = '/storage/emulated/0/Download';
      final downloadDir = Directory(publicDownload);
      
      if (await downloadDir.exists()) {
        // Create Syndro subfolder
        const syndroFolder = '$publicDownload/Syndro';
        final syndroDir = Directory(syndroFolder);
        
        try {
          if (!await syndroDir.exists()) {
            await syndroDir.create(recursive: true);
          }
          return syndroFolder;
        } catch (e) {
          print('Error creating Syndro folder: $e');
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

  void _stopReceiving() async {
    await _webShareService.stopSharing();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _openSettings() async {
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
                style: TextStyle(color: AppTheme.textSecondary),
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
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Expanded(
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
                Icon(Icons.folder, color: AppTheme.textSecondary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Saving to: ${_downloadPath ?? 'Downloads'}',
                    style: TextStyle(
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: QrImageView(
              data: _receiveUrl!,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1a1a2e),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1a1a2e),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // URL Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _receiveUrl!,
                    style: TextStyle(
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

          // Received Files
          if (_receivedFiles.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Received ${_receivedFiles.length} file(s)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _receivedFiles.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppTheme.textTertiary.withOpacity(0.2),
                ),
                itemBuilder: (context, index) {
                  final file = _receivedFiles[index];
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: AppTheme.successColor,
                      ),
                    ),
                    title: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(file.sizeFormatted),
                    dense: true,
                  );
                },
              ),
            ),
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
                side: BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
