import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../../core/services/web_share/web_share_service.dart';
import '../../core/l10n/app_localizations.dart';

/// Enum to define the share mode
enum ShareMode {
  files, // General files - "Add More Files"
  media, // Photos & Videos - "Add More Photos & Videos"
}

class BrowserShareScreen extends StatefulWidget {
  final List<File> files;
  final ShareMode shareMode;

  const BrowserShareScreen({
    super.key,
    required this.files,
    this.shareMode = ShareMode.files,
  });

  @override
  State<BrowserShareScreen> createState() => _BrowserShareScreenState();
}

class _BrowserShareScreenState extends State<BrowserShareScreen> {
  final WebShareService _webShareService = WebShareService();

  String? _shareUrl;
  bool _isLoading = true;
  String? _error;
  bool _isOperationInProgress = false;

  late List<File> _files;
  int _activeConnections = 0;
  
  AppLocalizations? _l10n;

  StreamSubscription<int>? _connectionCountSubscription;
  StreamSubscription<ConnectionEvent>? _connectionEventSubscription;
  StreamSubscription<PendingConfirmation>? _confirmationRequestSubscription;

  // NEW: Store connected clients with their info
  final List<Map<String, String>> _connectedClients = [];

  static const List<String> _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif'
  ];

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.files);
    _startSharing();
    _setupConnectionListeners();
  }

  @override
  void dispose() {
    // FIXED (Bug #24): Wrap stream cancellations in try-catch
    try {
      _connectionCountSubscription?.cancel();
      _connectionCountSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling connection count subscription: $e');
    }
    
    try {
      _connectionEventSubscription?.cancel();
      _connectionEventSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling connection event subscription: $e');
    }
    
    try {
      _confirmationRequestSubscription?.cancel();
      _confirmationRequestSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling confirmation request subscription: $e');
    }
    
    try {
      _webShareService.stopSharing();
    } catch (e) {
      debugPrint('Error stopping web share service: $e');
    }
    
    // Clear FilePicker cache to free storage
    // Fire-and-forget is acceptable for cache cleanup - if it fails, it's not critical
    // Using then/catchError instead of ignore() for proper error handling
    _clearFilePickerCache().then((_) {
      debugPrint('✅ FilePicker cache cleanup completed');
    }).catchError((e) {
      debugPrint('⚠️ FilePicker cache cleanup failed (non-critical): $e');
    });
    super.dispose();
  }

  /// Clear FilePicker cache completely
  Future<void> _clearFilePickerCache() async {
    // Method 1: Use FilePicker's built-in clear
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (e) {
      debugPrint('FilePicker.clearTemporaryFiles failed: $e');
    }

    // Method 2: Manually delete cache directory (more reliable on Android)
    try {
      final cacheDir = await getTemporaryDirectory();
      final filePickerDir = Directory('${cacheDir.path}/file_picker');

      if (await filePickerDir.exists()) {
        await filePickerDir.delete(recursive: true);
        debugPrint('✅ FilePicker cache cleared: ${filePickerDir.path}');
      }

      // Method 3: Also clear any file_picker related folders
      final cacheContents = cacheDir.listSync();
      for (final entity in cacheContents) {
        if (entity is Directory && entity.path.contains('file_picker')) {
          try {
            await entity.delete(recursive: true);
            debugPrint('✅ Cleared: ${entity.path}');
          } catch (e) {
            debugPrint('Failed to clear ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error in manual cache cleanup: $e');
    }
  }

  void _setupConnectionListeners() {
    _connectionCountSubscription =
        _webShareService.activeConnectionCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _activeConnections = count;
        });
      }
    });

    _connectionEventSubscription =
        _webShareService.connectionEventStream.listen((event) {
      if (!mounted) return;

      // NEW: Track connected clients with IP and userAgent
      if (event.type == ConnectionEventType.connected) {
        setState(() {
          // Check if client already exists
          final exists = _connectedClients.any((c) => c['ip'] == event.ipAddress);
          if (!exists) {
            _connectedClients.add({
              'ip': event.ipAddress,
              'userAgent': event.userAgent ?? 'Unknown',
            });
          }
        });
      }

      switch (event.type) {
        case ConnectionEventType.connected:
          _showConnectionSnackBar(
            '📱 ${event.ipAddress} connected',
            AppTheme.primaryColor,
          );
          break;
        case ConnectionEventType.downloadStarted:
          _showConnectionSnackBar(
            '⬇️ ${event.ipAddress} downloading ${event.fileName ?? "file"}',
            Colors.blue,
          );
          break;
        case ConnectionEventType.downloadCompleted:
          _showConnectionSnackBar(
            '✅ ${event.ipAddress} downloaded ${event.fileName ?? "file"}',
            AppTheme.successColor,
          );
          break;
      }
    });

    // Listen for connection confirmation requests
    _confirmationRequestSubscription =
        _webShareService.confirmationRequestStream.listen((confirmation) {
      if (!mounted) return;
      _showConnectionConfirmationDialog(confirmation);
    });
  }

  /// Show dialog to approve or deny a connection request
  void _showConnectionConfirmationDialog(PendingConfirmation confirmation) {
    final os = _parseOS(confirmation.userAgent);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _accentColor.withOpacity(0.3),
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.person_add, color: _accentColor),
            const SizedBox(width: 8),
            const Text('Connection Request', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Someone wants to download your files:',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.devices, 'Device', os),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.language, 'IP Address', confirmation.ipAddress),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _webShareService.denyConnection(confirmation.ipAddress);
              _showConnectionSnackBar(
                '❌ Connection denied for ${confirmation.ipAddress}',
                Colors.red,
              );
            },
            child: const Text('Deny', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _webShareService.confirmConnection(confirmation.ipAddress);
              _showConnectionSnackBar(
                '✅ Connection approved for ${confirmation.ipAddress}',
                AppTheme.successColor,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _accentColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textTertiary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: AppTheme.textTertiary)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _showConnectionSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  // NEW: Show viewers dialog with IP and OS
  void _showViewersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _accentColor.withOpacity(0.3),
          ),
        ),
        title: Row(
          children: [
            Icon(Icons.people, color: _accentColor),
            const SizedBox(width: 8),
            Text(
              'Connected Viewers ($_activeConnections)',
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
        content: _connectedClients.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No viewers connected yet.\nShare the QR code or link to get started!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textTertiary),
                ),
              )
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _connectedClients.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final client = _connectedClients[index];
                    final os = _parseOS(client['userAgent']!);
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getOSIcon(client['userAgent']!),
                          color: _accentColor,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        client['ip']!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        os,
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: _accentColor),
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Get OS icon based on user agent
  IconData _getOSIcon(String userAgent) {
    final ua = userAgent.toLowerCase();
    if (ua.contains('android')) return Icons.android;
    if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ios')) {
      return Icons.phone_iphone;
    }
    if (ua.contains('windows')) return Icons.desktop_windows;
    if (ua.contains('mac') || ua.contains('macintosh')) return Icons.laptop_mac;
    if (ua.contains('linux')) return Icons.computer;
    if (ua.contains('chrome')) return Icons.language;
    if (ua.contains('firefox')) return Icons.language;
    if (ua.contains('safari')) return Icons.language;
    return Icons.device_unknown;
  }

  // NEW: Parse OS name from user agent
  String _parseOS(String userAgent) {
    final ua = userAgent.toLowerCase();
    if (ua.contains('android')) {
      // Try to extract Android version
      final match = RegExp(r'android\s*([\d.]+)').firstMatch(ua);
      if (match != null) {
        return 'Android ${match.group(1)}';
      }
      return 'Android';
    }
    if (ua.contains('iphone')) return 'iPhone';
    if (ua.contains('ipad')) return 'iPad';
    if (ua.contains('windows nt 10')) return 'Windows 10/11';
    if (ua.contains('windows')) return 'Windows';
    if (ua.contains('macintosh') || ua.contains('mac os')) return 'macOS';
    if (ua.contains('linux')) return 'Linux';
    if (ua.contains('cros')) return 'Chrome OS';
    
    // Browser fallback
    if (ua.contains('chrome')) return 'Chrome Browser';
    if (ua.contains('firefox')) return 'Firefox Browser';
    if (ua.contains('safari')) return 'Safari Browser';
    if (ua.contains('edge')) return 'Edge Browser';
    
    return 'Unknown Device';
  }

  Future<void> _startSharing() async {
    if (_files.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'No files to share';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = await _webShareService.startSharing(_files);

      if (!mounted) return;
      if (url != null) {
        setState(() {
          _shareUrl = url;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to start sharing server';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _restartSharing() async {
    // Clear connected clients on restart
    _connectedClients.clear();
    await _webShareService.stopSharing();
    await _startSharing();
  }

  Future<void> _addMoreFiles() async {
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      final FilePickerResult? result;

      if (widget.shareMode == ShareMode.media) {
        result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.media,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          allowMultiple: true,
          type: FileType.any,
        );
      }

      if (result == null || result.files.isEmpty) {
        return;
      }

      final newFiles = <File>[];
      final existingPaths = _files.map((f) => f.path).toSet();

      for (final file in result.files) {
        if (file.path != null) {
          if (!existingPaths.contains(file.path)) {
            newFiles.add(File(file.path!));
          }
        }
      }

      if (newFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected files are already in the list'),
              backgroundColor: AppTheme.warningColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      setState(() {
        _files.addAll(newFiles);
      });

      await _restartSharing();

      if (mounted) {
        final label =
            widget.shareMode == ShareMode.media ? 'media' : 'file';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Added ${newFiles.length} $label${newFiles.length == 1 ? '' : 's'}'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding files: $e'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _isOperationInProgress = false;
    }
  }

  Future<void> _removeFile(int index) async {
    if (_isOperationInProgress) return;
    _isOperationInProgress = true;

    try {
      if (_files.length <= 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Cannot remove the last file. Stop sharing instead.'),
            backgroundColor: AppTheme.warningColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final removedFile = _files[index];
      final fileName = removedFile.path.split(Platform.pathSeparator).last;

      if (!mounted) return;
      setState(() {
        _files.removeAt(index);
      });

      await _restartSharing();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "$fileName"'),
            backgroundColor: AppTheme.successColor,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              textColor: Colors.white,
              onPressed: () async {
                if (_isOperationInProgress || !mounted) return;
                _isOperationInProgress = true;
                try {
                  setState(() {
                    _files.insert(index, removedFile);
                  });
                  await _restartSharing();
                } finally {
                  _isOperationInProgress = false;
                }
              },
            ),
          ),
        );
      }
    } finally {
      _isOperationInProgress = false;
    }
  }

  void _copyLink() {
    if (_shareUrl != null) {
      Clipboard.setData(ClipboardData(text: _shareUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_l10n?.linkCopied ?? 'Link copied to clipboard'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopSharing() async {
    await _webShareService.stopSharing();
    // Clear FilePicker cache to free storage
    await _clearFilePickerCache();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  bool _isImage(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _imageExtensions.contains(ext);
  }

  bool _isVideo(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', '3gp', 'm4v'];
    return videoExts.contains(ext);
  }

  String _getFileType(String filename) {
    final ext = filename.split('.').last.toLowerCase();

    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', '3gp', 'm4v'];
    const audioExts = ['mp3', 'wav', 'flac', 'aac', 'ogg', 'm4a'];
    const docExts = ['pdf', 'doc', 'docx', 'txt', 'rtf', 'odt'];
    const spreadsheetExts = ['xls', 'xlsx', 'csv', 'ods'];
    const presentationExts = ['ppt', 'pptx', 'odp'];
    const archiveExts = ['zip', 'rar', '7z', 'tar', 'gz'];
    const codeExts = [
      'dart',
      'js',
      'py',
      'java',
      'cpp',
      'html',
      'css',
      'json',
      'xml'
    ];
    const apkExts = ['apk', 'apks', 'apkm', 'xapk'];
    const exeExts = ['exe', 'msi'];

    if (_imageExtensions.contains(ext)) return 'image';
    if (videoExts.contains(ext)) return 'video';
    if (audioExts.contains(ext)) return 'audio';
    if (docExts.contains(ext)) return 'document';
    if (spreadsheetExts.contains(ext)) return 'spreadsheet';
    if (presentationExts.contains(ext)) return 'presentation';
    if (archiveExts.contains(ext)) return 'archive';
    if (codeExts.contains(ext)) return 'code';
    if (apkExts.contains(ext)) return 'apk';
    if (exeExts.contains(ext)) return 'executable';

    return 'file';
  }

  IconData _getFileIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'audio':
        return Icons.audio_file;
      case 'document':
        return Icons.description;
      case 'spreadsheet':
        return Icons.table_chart;
      case 'presentation':
        return Icons.slideshow;
      case 'archive':
        return Icons.folder_zip;
      case 'code':
        return Icons.code;
      case 'apk':
        return Icons.android;
      case 'executable':
        return Icons.terminal;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String fileType) {
    switch (fileType) {
      case 'image':
        return const Color(0xFFF472B6);
      case 'video':
        return const Color(0xFFFB923C);
      case 'audio':
        return const Color(0xFFA78BFA);
      case 'document':
        return const Color(0xFF60A5FA);
      case 'spreadsheet':
        return const Color(0xFF34D399);
      case 'presentation':
        return const Color(0xFFFBBF24);
      case 'archive':
        return const Color(0xFFF87171);
      case 'code':
        return const Color(0xFF2DD4BF);
      case 'apk':
        return const Color(0xFFA3E635);
      case 'executable':
        return const Color(0xFF818CF8);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  Future<int> _getTotalSize() async {
    int total = 0;
    int errorCount = 0;
    for (final file in _files) {
      try {
        final stat = await file.stat();
        total += stat.size;
      } catch (e) { 
        errorCount++;
        debugPrint("Error getting file size: $e");
      }
    }
    if (errorCount > 0 && errorCount == _files.length) {
      debugPrint('Warning: Could not get size for any files');
    }
    return total;
  }

  String get _addMoreButtonText {
    if (widget.shareMode == ShareMode.media) {
      return 'Add More Photos & Videos';
    } else {
      return 'Add More Files';
    }
  }

  IconData get _addMoreButtonIcon {
    if (widget.shareMode == ShareMode.media) {
      return Icons.add_photo_alternate;
    } else {
      return Icons.add;
    }
  }

  Color get _accentColor {
    if (widget.shareMode == ShareMode.media) {
      return const Color(0xFFF472B6);
    } else {
      return AppTheme.primaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    _l10n = AppLocalizations.of(context)!;
    final l10n = _l10n!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.shareMode == ShareMode.media
            ? l10n.shareInBrowser
            : l10n.shareViaWeb),
        actions: [
          // NEW: Clickable viewer count badge
          if (!_isLoading && _shareUrl != null)
            GestureDetector(
              onTap: _showViewersDialog,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _activeConnections > 0
                        ? AppTheme.successColor.withOpacity(0.2)
                        : AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _activeConnections > 0
                          ? AppTheme.successColor
                          : AppTheme.textTertiary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: _activeConnections > 0
                            ? AppTheme.successColor
                            : AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_activeConnections',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _activeConnections > 0
                              ? AppTheme.successColor
                              : AppTheme.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 14,
                        color: _activeConnections > 0
                            ? AppTheme.successColor
                            : AppTheme.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!_isLoading && _shareUrl != null)
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
            Text('Starting share server...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startSharing,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // QR Code Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
                color: _accentColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_activeConnections > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.successColor.withOpacity(0.2),
                          AppTheme.successColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.successColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.successColor,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$_activeConnections ${_activeConnections == 1 ? 'person' : 'people'} connected',
                          style: const TextStyle(
                            color: AppTheme.successColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
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
                      color: _accentColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: QrImageView(
                    data: _shareUrl!,
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
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _accentColor,
                      _accentColor.withOpacity(0.7),
                    ],
                  ).createShader(bounds),
                  child: Text(
                    widget.shareMode == ShareMode.media
                        ? 'Scan to download media'
                        : 'Scan to download files',
                    style: const TextStyle(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      color: _accentColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.link,
                          size: 18,
                          color: _accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _shareUrl!,
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
                            color: _accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.copy,
                            size: 18,
                            color: _accentColor,
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

          Row(
            children: [
              Icon(
                widget.shareMode == ShareMode.media
                    ? Icons.photo_library
                    : Icons.folder_open,
                color: _accentColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Sharing ${_files.length} ${widget.shareMode == ShareMode.media ? (_files.length == 1 ? 'item' : 'items') : (_files.length == 1 ? 'file' : 'files')}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              FutureBuilder<int>(
                future: _getTotalSize(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      _formatFileSize(snapshot.data!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _files.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                color: AppTheme.cardColor,
              ),
              itemBuilder: (context, index) {
                final file = _files[index];
                final fileName = file.path.split(Platform.pathSeparator).last;
                final isImage = _isImage(file.path);
                final isVideo = _isVideo(file.path);
                final fileType = _getFileType(fileName);

                return FutureBuilder<FileStat>(
                  future: file.stat(),
                  builder: (context, snapshot) {
                    final fileSize =
                        snapshot.hasData ? snapshot.data!.size : 0;

                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Thumbnail
                          if (isImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                file,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                cacheWidth: 112,
                                errorBuilder: (_, __, ___) =>
                                    _buildFileIcon(fileType),
                              ),
                            )
                          else if (isVideo)
                            _buildVideoThumbnail()
                          else
                            _buildFileIcon(fileType),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fileName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getFileIconColor(fileType)
                                            .withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        fileType.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: _getFileIconColor(fileType),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatFileSize(fileSize),
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

                          IconButton(
                            onPressed: () => _removeFile(index),
                            icon: const Icon(Icons.close),
                            iconSize: 20,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  AppTheme.errorColor.withOpacity(0.1),
                              foregroundColor: AppTheme.errorColor,
                              padding: const EdgeInsets.all(8),
                              minimumSize: const Size(36, 36),
                            ),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Add More Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addMoreFiles,
              icon: Icon(_addMoreButtonIcon),
              label: Text(_addMoreButtonText),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentColor,
                side: BorderSide(color: _accentColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: AppTheme.textTertiary,
              ),
              SizedBox(width: 6),
              Text(
                'Link active while this screen is open',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _stopSharing,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop Sharing'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: const BorderSide(color: AppTheme.errorColor),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(String fileType) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _getFileIconColor(fileType).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        _getFileIcon(fileType),
        color: _getFileIconColor(fileType),
        size: 28,
      ),
    );
  }

  Widget _buildVideoThumbnail() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFFFB923C).withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.video_file,
            color: Color(0xFFFB923C),
            size: 28,
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Icon(
              Icons.play_circle_filled,
              color: Color(0xFFFB923C),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
