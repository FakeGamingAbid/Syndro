import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../theme/app_theme.dart';
import '../../core/services/web_share/web_share_service.dart';

class BrowserShareScreen extends StatefulWidget {
  final List<File> files;

  const BrowserShareScreen({
    super.key,
    required this.files,
  });

  @override
  State<BrowserShareScreen> createState() => _BrowserShareScreenState();
}

class _BrowserShareScreenState extends State<BrowserShareScreen> {
  final WebShareService _webShareService = WebShareService();

  String? _shareUrl;
  bool _isLoading = true;
  String? _error;

  // Mutable list of files that can be modified
  late List<File> _files;

  // Supported image extensions for thumbnails
  static const List<String> _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp'
  ];

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.files); // Create mutable copy
    _startSharing();
  }

  @override
  void dispose() {
    _webShareService.stopSharing();
    super.dispose();
  }

  Future<void> _startSharing() async {
    if (_files.isEmpty) {
      setState(() {
        _error = 'No files to share';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = await _webShareService.startSharing(_files);
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
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _restartSharing() async {
    await _webShareService.stopSharing();
    await _startSharing();
  }

  /// Add more files to the share list
  Future<void> _addMoreFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      // Get list of new files
      final newFiles = <File>[];
      final existingPaths = _files.map((f) => f.path).toSet();

      for (final file in result.files) {
        if (file.path != null) {
          // Check if file already exists in list
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

      // Add new files to list
      setState(() {
        _files.addAll(newFiles);
      });

      // Restart sharing with updated file list
      await _restartSharing();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${newFiles.length} file${newFiles.length == 1 ? '' : 's'}'),
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
    }
  }

  void _removeFile(int index) async {
    if (_files.length <= 1) {
      // Show warning if trying to remove last file
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the last file. Stop sharing instead.'),
          backgroundColor: AppTheme.warningColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final removedFile = _files[index];
    final fileName = removedFile.path.split(Platform.pathSeparator).last;

    setState(() {
      _files.removeAt(index);
    });

    // Restart sharing with updated file list
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
              setState(() {
                _files.insert(index, removedFile);
              });
              await _restartSharing();
            },
          ),
        ),
      );
    }
  }

  void _copyLink() {
    if (_shareUrl != null) {
      Clipboard.setData(ClipboardData(text: _shareUrl!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard!'),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _stopSharing() async {
    await _webShareService.stopSharing();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Check if file is an image
  bool _isImage(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return _imageExtensions.contains(ext);
  }

  /// Get file type for icon
  String _getFileType(String filename) {
    final ext = filename.split('.').last.toLowerCase();

    const videoExts = ['mp4', 'mov', 'avi', 'mkv', 'webm', 'flv'];
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
    const apkExts = ['apk'];
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

  /// Get icon for file type
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

  /// Get icon color for file type
  Color _getFileIconColor(String fileType) {
    switch (fileType) {
      case 'image':
        return const Color(0xFFF472B6); // Pink
      case 'video':
        return const Color(0xFFFB923C); // Orange
      case 'audio':
        return const Color(0xFFA78BFA); // Purple
      case 'document':
        return const Color(0xFF60A5FA); // Blue
      case 'spreadsheet':
        return const Color(0xFF34D399); // Green
      case 'presentation':
        return const Color(0xFFFBBF24); // Yellow
      case 'archive':
        return const Color(0xFFF87171); // Red
      case 'code':
        return const Color(0xFF2DD4BF); // Teal
      case 'apk':
        return const Color(0xFFA3E635); // Lime
      case 'executable':
        return const Color(0xFF818CF8); // Indigo
      default:
        return const Color(0xFF94A3B8); // Gray
    }
  }

  /// Format file size
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

  /// Calculate total size of all files
  Future<int> _getTotalSize() async {
    int total = 0;
    for (final file in _files) {
      try {
        final stat = await file.stat();
        total += stat.size;
      } catch (_) {}
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share via Browser'),
        actions: [
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
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
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
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
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
                    data: _shareUrl!,
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

                const SizedBox(height: 20),

                // Instructions
                Text(
                  'Scan to download files',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),

                const SizedBox(height: 8),

                Text(
                  'No app needed on the other device',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                ),

                const SizedBox(height: 16),

                // URL Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _shareUrl!,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _copyLink,
                        child: const Icon(
                          Icons.copy,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Files Section Header
          Row(
            children: [
              const Icon(
                Icons.folder_open,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Sharing ${_files.length} file${_files.length == 1 ? '' : 's'}',
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

          // File List
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _files.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppTheme.cardColor,
              ),
              itemBuilder: (context, index) {
                final file = _files[index];
                final fileName = file.path.split(Platform.pathSeparator).last;
                final isImage = _isImage(file.path);
                final fileType = _getFileType(fileName);

                return FutureBuilder<FileStat>(
                  future: file.stat(),
                  builder: (context, snapshot) {
                    final fileSize = snapshot.hasData ? snapshot.data!.size : 0;

                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // Thumbnail for images, Icon for others
                          if (isImage)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                file,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildFileIcon(fileType),
                              ),
                            )
                          else
                            _buildFileIcon(fileType),

                          const SizedBox(width: 14),

                          // File info
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
                                    // File type badge
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
                                    // File size
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

                          // Remove button
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
                            tooltip: 'Remove file',
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

          // ✅ NEW: Add More Files Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addMoreFiles,
              icon: const Icon(Icons.add),
              label: const Text('Add More Files'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Expiration notice
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                'Link expires in 1 hour',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stop sharing button
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

  /// Build file icon widget
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
}
