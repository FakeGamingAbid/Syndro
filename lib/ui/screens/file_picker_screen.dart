import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../../core/models/device.dart';
import '../../core/models/transfer.dart';
import '../../core/providers/device_provider.dart';
import '../../core/providers/transfer_provider.dart';
import 'transfer_progress_screen.dart';

class FilePickerScreen extends ConsumerStatefulWidget {
  final Device recipientDevice;

  const FilePickerScreen({
    super.key,
    required this.recipientDevice,
  });

  @override
  ConsumerState<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends ConsumerState<FilePickerScreen> {
  final List<TransferItem> _selectedFiles = [];
  bool _isLoading = false;

  Future<void> _pickFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fileService = ref.read(fileServiceProvider);
      final files = await fileService.pickFiles();

      setState(() {
        _selectedFiles.addAll(files);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _pickFolder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fileService = ref.read(fileServiceProvider);
      final folderPath = await fileService.pickFolder();

      if (folderPath != null) {
        final folderStructure = await fileService.scanFolder(folderPath);
        final files = fileService.getAllFilesInFolder(folderStructure);

        setState(() {
          _selectedFiles.addAll(files);
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${files.length} files from folder'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking folder: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _sendFiles() async {
    if (_selectedFiles.isEmpty) return;

    final currentDevice = ref.read(currentDeviceProvider);
    final transferService = ref.read(transferServiceProvider);

    // Generate transfer ID
    final transferId = const Uuid().v4();

    // Store files before navigating
    final filesToSend = List<TransferItem>.from(_selectedFiles);

    // Navigate to progress screen FIRST
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => TransferProgressScreen(
          transferId: transferId,
          remoteDevice: widget.recipientDevice,
          isSender: true,
          items: filesToSend,
        ),
      ),
    );

    // Then start the transfer
    try {
      await transferService.sendFiles(
        sender: currentDevice,
        receiver: widget.recipientDevice,
        items: filesToSend,
      );
    } catch (e) {
      debugPrint('Transfer error: $e');
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalSize =
        _selectedFiles.fold<int>(0, (sum, item) => sum + item.size);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Files'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Column(
          children: [
            // Recipient Info
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color: AppTheme.primaryColor,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sending to',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.recipientDevice.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pick Files Button
            if (_selectedFiles.isEmpty && !_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: AppTheme.textTertiary,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.insert_drive_file),
                            label: const Text('Select Files'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _pickFolder,
                            icon: const Icon(Icons.folder),
                            label: const Text('Select Folder'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Loading
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            // Selected Files List
            if (_selectedFiles.isNotEmpty && !_isLoading)
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_selectedFiles.length} file(s) selected',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          TextButton.icon(
                            onPressed: _pickFiles,
                            icon: const Icon(Icons.add),
                            label: const Text('Add More'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _selectedFiles.length,
                        itemBuilder: (context, index) {
                          final file = _selectedFiles[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                _getFileIcon(file.name),
                                color: AppTheme.primaryColor,
                              ),
                              title: Text(file.name),
                              subtitle: Text(file.sizeFormatted),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeFile(index),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Summary Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Total Size',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  _formatSize(totalSize),
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: _sendFiles,
                              icon: const Icon(Icons.send),
                              label: const Text('Send'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();

    const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'webp'];
    const videoExts = ['mp4', 'mov', 'avi', 'mkv'];
    const docExts = ['pdf', 'doc', 'docx', 'txt'];
    const archiveExts = ['zip', 'rar', '7z'];

    if (imageExts.contains(ext)) return Icons.image;
    if (videoExts.contains(ext)) return Icons.video_file;
    if (docExts.contains(ext)) return Icons.description;
    if (archiveExts.contains(ext)) return Icons.folder_zip;

    return Icons.insert_drive_file;
  }

  String _formatSize(int bytes) {
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
