import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../theme/app_theme.dart';

/// File type categories
enum FileType {
  image,
  video,
  audio,
  document,
  archive,
  code,
  pdf,
  unknown,
}

/// File preview widget that shows thumbnails for images/videos
class FilePreviewWidget extends StatefulWidget {
  final String filePath;
  final String fileName;
  final double size;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showPlayIcon;

  const FilePreviewWidget({
    super.key,
    required this.filePath,
    required this.fileName,
    this.size = 56.0,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showPlayIcon = true,
  });

  @override
  State<FilePreviewWidget> createState() => _FilePreviewWidgetState();
}

class _FilePreviewWidgetState extends State<FilePreviewWidget> {
  Uint8List? _videoThumbnail;
  bool _isLoadingThumbnail = false;
  bool _thumbnailError = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnailIfNeeded();
  }

  @override
  void didUpdateWidget(FilePreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _videoThumbnail = null;
      _thumbnailError = false;
      _loadThumbnailIfNeeded();
    }
  }

  Future<void> _loadThumbnailIfNeeded() async {
    final fileType = FileTypeHelper.getFileType(widget.fileName);

    if (fileType == FileType.video &&
        _videoThumbnail == null &&
        !_thumbnailError) {
      setState(() => _isLoadingThumbnail = true);

      try {
        final thumbnail = await VideoThumbnail.thumbnailData(
          video: widget.filePath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: (widget.size * 2).toInt(),
          quality: 75,
        );

        if (mounted) {
          setState(() {
            _videoThumbnail = thumbnail;
            _isLoadingThumbnail = false;
          });
        }
      } catch (e) {
        debugPrint('Error generating video thumbnail: $e');
        if (mounted) {
          setState(() {
            _thumbnailError = true;
            _isLoadingThumbnail = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileType = FileTypeHelper.getFileType(widget.fileName);
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(12);

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: FileTypeHelper.getBackgroundColor(fileType),
        borderRadius: borderRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildPreviewContent(fileType),
    );
  }

  Widget _buildPreviewContent(FileType fileType) {
    switch (fileType) {
      case FileType.image:
        return _buildImagePreview();
      case FileType.video:
        return _buildVideoPreview();
      default:
        return _buildIconPreview(fileType);
    }
  }

  Widget _buildImagePreview() {
    final file = File(widget.filePath);

    if (!file.existsSync()) {
      return _buildIconPreview(FileType.image);
    }

    return Image.file(
      file,
      width: widget.size,
      height: widget.size,
      fit: widget.fit,
      cacheWidth: (widget.size * 2).toInt(),
      cacheHeight: (widget.size * 2).toInt(),
      errorBuilder: (context, error, stackTrace) {
        return _buildIconPreview(FileType.image);
      },
    );
  }

  Widget _buildVideoPreview() {
    if (_isLoadingThumbnail) {
      return Center(
        child: SizedBox(
          width: widget.size * 0.4,
          height: widget.size * 0.4,
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_videoThumbnail != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            _videoThumbnail!,
            fit: widget.fit,
            errorBuilder: (context, error, stackTrace) {
              return _buildIconPreview(FileType.video);
            },
          ),
          if (widget.showPlayIcon)
            Center(
              child: Container(
                padding: EdgeInsets.all(widget.size * 0.1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: widget.size * 0.3,
                ),
              ),
            ),
        ],
      );
    }

    return _buildIconPreview(FileType.video);
  }

  Widget _buildIconPreview(FileType fileType) {
    return Center(
      child: Icon(
        FileTypeHelper.getIcon(fileType),
        color: FileTypeHelper.getIconColor(fileType),
        size: widget.size * 0.5,
      ),
    );
  }
}

/// Large file preview for detail view
class LargeFilePreview extends StatefulWidget {
  final String filePath;
  final String fileName;
  final double maxHeight;

  const LargeFilePreview({
    super.key,
    required this.filePath,
    required this.fileName,
    this.maxHeight = 300,
  });

  @override
  State<LargeFilePreview> createState() => _LargeFilePreviewState();
}

class _LargeFilePreviewState extends State<LargeFilePreview> {
  Uint8List? _videoThumbnail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadThumbnailIfVideo();
  }

  Future<void> _loadThumbnailIfVideo() async {
    final fileType = FileTypeHelper.getFileType(widget.fileName);
    if (fileType == FileType.video) {
      setState(() => _isLoading = true);
      try {
        final thumbnail = await VideoThumbnail.thumbnailData(
          video: widget.filePath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 512,
          quality: 85,
        );
        if (mounted) {
          setState(() {
            _videoThumbnail = thumbnail;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileType = FileTypeHelper.getFileType(widget.fileName);

    if (fileType == FileType.image) {
      final file = File(widget.filePath);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildLargeIconPreview(fileType);
              },
            ),
          ),
        );
      }
    }

    if (fileType == FileType.video) {
      if (_isLoading) {
        return Container(
          height: 150,
          decoration: BoxDecoration(
            color: FileTypeHelper.getBackgroundColor(fileType),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (_videoThumbnail != null) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.maxHeight),
                child: Image.memory(
                  _videoThumbnail!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    return _buildLargeIconPreview(fileType);
  }

  Widget _buildLargeIconPreview(FileType fileType) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: FileTypeHelper.getBackgroundColor(fileType),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FileTypeHelper.getIcon(fileType),
              color: FileTypeHelper.getIconColor(fileType),
              size: 64,
            ),
            const SizedBox(height: 8),
            Text(
              FileTypeHelper.getFileExtension(widget.fileName).toUpperCase(),
              style: TextStyle(
                color: FileTypeHelper.getIconColor(fileType),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// File preview card showing file info
class FilePreviewCard extends StatelessWidget {
  final String filePath;

  const FilePreviewCard({
    super.key,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = filePath.split('/').last.split('\\').last;
    final fileType = FileTypeHelper.getFileType(fileName);
    final fileSize = FileTypeHelper.getFileSize(filePath);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            FilePreviewWidget(
              filePath: filePath,
              fileName: fileName,
              size: 48,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FileTypeHelper.getBackgroundColor(fileType),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          FileTypeHelper.getFileExtension(fileName)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: FileTypeHelper.getIconColor(fileType),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        FileTypeHelper.formatFileSize(fileSize),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
}

/// Helper class for file type detection and styling
class FileTypeHelper {
  static const _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
    'heic',
    'heif'
  ];
  static const _videoExtensions = [
    'mp4',
    'mov',
    'avi',
    'mkv',
    'wmv',
    'flv',
    'webm',
    '3gp',
    'm4v'
  ];
  static const _audioExtensions = [
    'mp3',
    'wav',
    'aac',
    'flac',
    'ogg',
    'm4a',
    'wma'
  ];
  static const _documentExtensions = [
    'doc',
    'docx',
    'txt',
    'rtf',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'odt',
    'ods'
  ];
  static const _pdfExtensions = ['pdf'];
  static const _archiveExtensions = [
    'zip',
    'rar',
    '7z',
    'tar',
    'gz',
    'bz2',
    'xz'
  ];
  static const _codeExtensions = [
    'dart',
    'py',
    'js',
    'ts',
    'java',
    'kt',
    'swift',
    'html',
    'css',
    'json',
    'xml',
    'yaml',
    'yml',
    'c',
    'cpp',
    'h',
    'go',
    'rs',
    'rb',
    'php'
  ];

  static String getFileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  static FileType getFileType(String fileNameOrPath) {
    // Extract filename from path if needed
    final fileName = fileNameOrPath.split('/').last.split('\\').last;
    final ext = getFileExtension(fileName);

    if (_imageExtensions.contains(ext)) return FileType.image;
    if (_videoExtensions.contains(ext)) return FileType.video;
    if (_audioExtensions.contains(ext)) return FileType.audio;
    if (_pdfExtensions.contains(ext)) return FileType.pdf;
    if (_documentExtensions.contains(ext)) return FileType.document;
    if (_archiveExtensions.contains(ext)) return FileType.archive;
    if (_codeExtensions.contains(ext)) return FileType.code;

    return FileType.unknown;
  }

  static IconData getIcon(FileType type) {
    switch (type) {
      case FileType.image:
        return Icons.image_rounded;
      case FileType.video:
        return Icons.video_file_rounded;
      case FileType.audio:
        return Icons.audio_file_rounded;
      case FileType.document:
        return Icons.description_rounded;
      case FileType.pdf:
        return Icons.picture_as_pdf_rounded;
      case FileType.archive:
        return Icons.folder_zip_rounded;
      case FileType.code:
        return Icons.code_rounded;
      case FileType.unknown:
        return Icons.insert_drive_file_rounded;
    }
  }

  static IconData getIconForFile(String fileName) {
    return getIcon(getFileType(fileName));
  }

  static Color getIconColor(FileType type) {
    switch (type) {
      case FileType.image:
        return const Color(0xFF4CAF50); // Green
      case FileType.video:
        return const Color(0xFFE91E63); // Pink
      case FileType.audio:
        return const Color(0xFF9C27B0); // Purple
      case FileType.document:
        return const Color(0xFF2196F3); // Blue
      case FileType.pdf:
        return const Color(0xFFFF5722); // Deep Orange
      case FileType.archive:
        return const Color(0xFFFF9800); // Orange
      case FileType.code:
        return const Color(0xFF00BCD4); // Cyan
      case FileType.unknown:
        return AppTheme.textTertiary;
    }
  }

  /// Alias for getIconColor (for backward compatibility)
  static Color getColor(FileType type) {
    return getIconColor(type);
  }

  static Color getBackgroundColor(FileType type) {
    return getIconColor(type).withOpacity(0.15);
  }

  static bool supportsPreview(String fileName) {
    final type = getFileType(fileName);
    return type == FileType.image || type == FileType.video;
  }

  /// Get file size in bytes from path
  static int getFileSize(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        return file.lengthSync();
      }
    } catch (e) {
      debugPrint('Error getting file size: $e');
    }
    return 0;
  }

  /// Format file size to human readable string
  static String formatFileSize(int bytes) {
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
}
