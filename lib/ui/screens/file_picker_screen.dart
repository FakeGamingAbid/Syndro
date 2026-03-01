import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animations/animations.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../theme/app_theme.dart';
import '../widgets/file_preview_widgets.dart';
import '../../core/models/device.dart';
import '../../core/models/transfer.dart';
import '../../core/providers/device_provider.dart';
import '../../core/providers/transfer_provider.dart';
import 'transfer_progress_screen.dart';
import 'multi_transfer_progress_screen.dart';

class FilePickerScreen extends ConsumerStatefulWidget {
  final Device? recipientDevice;
  final List<Device>? recipientDevices; // NEW: For multi-device transfer
  final List<TransferItem>? preselectedFiles; // NEW: For right-click send

  const FilePickerScreen({
    super.key,
    this.recipientDevice,
    this.recipientDevices,
    this.preselectedFiles,
  });

  /// Get all recipient devices
  List<Device> get allRecipients {
    if (recipientDevices != null && recipientDevices!.isNotEmpty) {
      return recipientDevices!;
    }
    if (recipientDevice != null) {
      return [recipientDevice!];
    }
    return [];
  }

  @override
  ConsumerState<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends ConsumerState<FilePickerScreen>
    with SingleTickerProviderStateMixin {
  final List<TransferItem> _selectedFiles = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isDragging = false; // NEW: For drag & drop

  // Animation controller for staggered list
  late AnimationController _animationController;

  // Track active subscription for cleanup
  StreamSubscription<Transfer>? _transferSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // NEW: Load preselected files if any (from right-click send)
    if (widget.preselectedFiles != null && widget.preselectedFiles!.isNotEmpty) {
      _selectedFiles.addAll(widget.preselectedFiles!);
      // Trigger animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animationController.forward(from: 0);
      });
    }
  }

  @override
  void dispose() {
    // FIXED (Bug #9 & #10): Wrap ALL cleanup in try-catch blocks
    try {
      // FIXED (Bug #10): Stop animation before disposing controller
      if (_animationController.isAnimating) {
        _animationController.stop();
      }
      _animationController.dispose();
    } catch (e) {
      debugPrint('Error disposing animation controller: $e');
    }
    
    try {
      _transferSubscription?.cancel();
      _transferSubscription = null;
    } catch (e) {
      debugPrint('Error cancelling transfer subscription: $e');
    }
    
    super.dispose();
  }

  // NEW: Handle dropped files from desktop
  Future<void> _handleDroppedFiles(DropDoneDetails details) async {
    if (_isSending) return;

    setState(() {
      _isLoading = true;
      _isDragging = false;
    });

    try {
      final items = <TransferItem>[];

      for (final xFile in details.files) {
        try {
          final path = xFile.path;
          final file = File(path);
          final directory = Directory(path);

          if (await file.exists()) {
            final stat = await file.stat();
            items.add(TransferItem(
              name: xFile.name,
              path: path,
              size: stat.size,
              isDirectory: false,
            ));
          } else if (await directory.exists()) {
            // Calculate folder size
            int folderSize = 0;
            await for (final entity in directory.list(recursive: true)) {
              if (entity is File) {
                folderSize += await entity.length();
              }
            }
            items.add(TransferItem(
              name: xFile.name,
              path: path,
              size: folderSize,
              isDirectory: true,
            ));
          }
        } catch (e) {
          debugPrint('Error processing dropped file: $e');
        }
      }

      if (mounted && items.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(items);
          _isLoading = false;
        });
        _animationController.forward(from: 0);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${items.length} file(s)'),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding dropped files: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Handle drag entered event
  void _onDragEntered(DropEventDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  // Handle drag exited event
  void _onDragExited(DropEventDetails details) {
    setState(() {
      _isDragging = false;
    });
  }

  Future<void> _pickFiles() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fileService = ref.read(fileServiceProvider);
      final files = await fileService.pickFiles();

      if (mounted) {
        setState(() {
          _selectedFiles.addAll(files);
          _isLoading = false;
        });

        // Trigger animation when files are added
        _animationController.forward(from: 0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking files: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // NEW: Pick only media (photos & videos) - similar to browser share
  Future<void> _pickMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final fileService = ref.read(fileServiceProvider);
      final files = await fileService.pickMedia();

      if (mounted) {
        setState(() {
          _selectedFiles.addAll(files);
          _isLoading = false;
        });

        // Trigger animation when files are added
        if (files.isNotEmpty) {
          _animationController.forward(from: 0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking media: $e'),
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

        if (mounted) {
          setState(() {
            _selectedFiles.addAll(files);
            _isLoading = false;
          });

          // Trigger animation when files are added
          _animationController.forward(from: 0);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${files.length} files from folder'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    if (_selectedFiles.isEmpty || _isSending) return;

    final recipients = widget.allRecipients;
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No recipients selected'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    final currentDevice = ref.read(currentDeviceProvider);
    final transferService = ref.read(transferServiceProvider);

    // Store files before sending
    final filesToSend = List<TransferItem>.from(_selectedFiles);
    
    // Calculate total size for better timeout estimation
    final totalSize = filesToSend.fold<int>(0, (sum, item) => sum + item.size);
    final isLargeFile = totalSize > 100 * 1024 * 1024; // > 100MB
    
    if (isLargeFile) {
      debugPrint('📦 Large file transfer (${(totalSize / (1024 * 1024)).toStringAsFixed(1)}MB) - extended timeouts enabled');
    }

    try {
      // Multi-device transfer: send to all recipients in parallel
      if (recipients.length > 1) {
        final transferIds = <String>[];
        final errors = <String, String>{};
        
        // Start all transfers in parallel
        final futures = <Future<Transfer?>>[];
        for (final recipient in recipients) {
          futures.add(_sendToSingleRecipient(
            transferService: transferService,
            sender: currentDevice,
            receiver: recipient,
            items: filesToSend,
          ));
        }
        
        // Wait for all transfers to start
        final results = await Future.wait(futures);
        
        for (int i = 0; i < results.length; i++) {
          final transfer = results[i];
          if (transfer != null) {
            transferIds.add(transfer.id);
          } else {
            errors[recipients[i].name] = 'Failed to start transfer';
          }
        }
        
        if (transferIds.isEmpty) {
          throw Exception('All transfers failed to start');
        }
        
        // Navigate to multi-transfer progress screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => MultiTransferProgressScreen(
                transferIds: transferIds,
                recipients: recipients,
                items: filesToSend,
                initialErrors: errors,
              ),
            ),
          );
        }
      } else {
        // Single device transfer (original behavior)
        final recipient = recipients.first;
        
        StreamSubscription<Transfer>? subscription;
        try {
          // Create a completer to wait for transfer creation
          final transferCompleter = Completer<Transfer>();

          subscription = transferService.transferStream.listen(
            (transfer) {
              if (transfer.receiverId == recipient.id &&
                  transfer.items.length == filesToSend.length &&
                  !transferCompleter.isCompleted) {
                transferCompleter.complete(transfer);
              }
            },
            onError: (error) {
              if (!transferCompleter.isCompleted) {
                transferCompleter.completeError(error);
              }
            },
          );

          // Start sending (this creates the transfer)
          final sendFuture = transferService.sendFiles(
            sender: currentDevice,
            receiver: recipient,
            items: filesToSend,
          );

          Transfer? transfer;
          
          // Use longer timeout for large files (hash calculation takes time)
          final creationTimeout = isLargeFile 
              ? const Duration(seconds: 30) 
              : const Duration(seconds: 10);
          
          try {
            // Wait for transfer to be created via stream (with timeout)
            transfer = await transferCompleter.future.timeout(
              creationTimeout,
              onTimeout: () {
                // Fallback: check active transfers directly
                final activeTransfers = transferService.activeTransfers;
                final matchingTransfer = activeTransfers.where(
                  (t) => t.receiverId == recipient.id,
                ).toList();
                
                if (matchingTransfer.isNotEmpty) {
                  return matchingTransfer.last;
                }
                throw TimeoutException('Transfer creation timed out');
              },
            );
          } catch (e) {
            // Retry logic - poll for transfer (more retries for large files)
            debugPrint('Stream timeout, using retry logic: $e');
            final maxRetries = isLargeFile ? 30 : 10;
            const retryDelay = Duration(milliseconds: 500);

            for (int i = 0; i < maxRetries; i++) {
              await Future.delayed(retryDelay);
              final activeTransfers = transferService.activeTransfers;
              final matchingTransfer = activeTransfers.where(
                (t) => t.receiverId == recipient.id,
              ).toList();
              
              if (matchingTransfer.isNotEmpty) {
                transfer = matchingTransfer.last;
                debugPrint('Found transfer on retry ${i + 1}');
                break;
              }
            }

            if (transfer == null) {
              throw Exception('Could not create transfer after $maxRetries retries');
            }
          } finally {
            // Always cancel subscription to prevent memory leaks
            await subscription.cancel();
            subscription = null;
          }

          // Navigate to progress screen with animation
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    TransferProgressScreen(
                  transferId: transfer!.id,
                  remoteDevice: recipient,
                  isSender: true,
                  items: filesToSend,
                ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeThroughTransition(
                    animation: animation,
                    secondaryAnimation: secondaryAnimation,
                    child: child,
                  );
                },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          }

          // Wait for send to complete (in background)
          await sendFuture;
        } finally {
          await subscription?.cancel();
        }
      }
    } catch (e) {
      debugPrint('Transfer error: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting transfer: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// Helper method to send to a single recipient and return the transfer
  Future<Transfer?> _sendToSingleRecipient({
    required dynamic transferService,
    required dynamic sender,
    required Device receiver,
    required List<TransferItem> items,
  }) async {
    try {
      // Start the transfer
      await transferService.sendFiles(
        sender: sender,
        receiver: receiver,
        items: items,
      );
      
      // Find the transfer from active transfers
      final activeTransfers = transferService.activeTransfers;
      final matchingTransfer = activeTransfers.where(
        (t) => t.receiverId == receiver.id,
      ).toList();
      
      if (matchingTransfer.isNotEmpty) {
        return matchingTransfer.last;
      }
      return null;
    } catch (e) {
      debugPrint('Error sending to ${receiver.name}: $e');
      return null;
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _clearAllFiles() {
    setState(() {
      _selectedFiles.clear();
    });
  }

  void _showFileDetails(TransferItem file) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FileDetailsSheet(file: file),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSize =
        _selectedFiles.fold<int>(0, (sum, item) => sum + item.size);
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    Widget body = Container(
      decoration: BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: Column(
        children: [
          // Recipient Info Card with animation
          _AnimatedCard(
            delay: const Duration(milliseconds: 100),
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.cardColor.withOpacity(0.9),
                    AppTheme.surfaceColor.withOpacity(0.7),
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
                  _AnimatedIcon(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Icon(
                        _getDeviceIcon(widget.recipientDevice!.platform),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sending to',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textTertiary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.recipientDevice!.name,
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
                              widget.recipientDevice!.ipAddress,
                              style:
                                  Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.successColor.withOpacity(0.2),
                          AppTheme.successColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.successColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.successColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.successColor,
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Online',
                          style: TextStyle(
                            color: AppTheme.successColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pick Files Button (Empty state) - WITH DRAG & DROP
          if (_selectedFiles.isEmpty && !_isLoading)
            Expanded(
              child: _AnimatedEmptyStateWithDrop(
                onPickFiles: _pickFiles,
                onPickMedia: _pickMedia,
                onPickFolder: _pickFolder,
                onFilesDropped: _handleDroppedFiles,
                isDragging: _isDragging,
                isDesktop: isDesktop,
              ),
            ),

          // Loading indicator
          if (_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading files...'),
                  ],
                ),
              ),
            ),

          // Selected Files List with previews
          if (_selectedFiles.isNotEmpty && !_isLoading)
            Expanded(
              child: Column(
                children: [
                  // Header with file count
                  _AnimatedCard(
                    delay: const Duration(milliseconds: 150),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${_selectedFiles.length} file(s)',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatSize(totalSize),
                                  style: const TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _isSending ? null : _pickFiles,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add More'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // File list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _selectedFiles.length,
                      itemBuilder: (context, index) {
                        final file = _selectedFiles[index];
                        return _AnimatedListItem(
                          index: index,
                          child: _FileListTile(
                            file: file,
                            onRemove:
                                _isSending ? null : () => _removeFile(index),
                            onTap: () => _showFileDetails(file),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom action bar
                  _AnimatedCard(
                    delay: const Duration(milliseconds: 200),
                    slideUp: true,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: AppTheme.cardColor,
                        borderRadius: BorderRadius.vertical(
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
                            _AnimatedSendButton(
                              isSending: _isSending,
                              onPressed: _sendFiles,
                              fileCount: _selectedFiles.length,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    // Wrap with DropTarget for desktop platforms
    if (isDesktop) {
      body = DropTarget(
        onDragDone: _handleDroppedFiles,
        onDragEntered: _onDragEntered,
        onDragExited: _onDragExited,
        child: Stack(
          children: [
            body,
            // Drag overlay for when files are being dragged over the list area
            if (_isDragging && _selectedFiles.isNotEmpty)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.primaryColor,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            size: 48,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Drop to add more files',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Files'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: 'Clear all',
              onPressed: _isSending ? null : _clearAllFiles,
            ),
        ],
      ),
      body: body,
    );
  }

  IconData _getDeviceIcon(DevicePlatform platform) {
    switch (platform) {
      case DevicePlatform.android:
        return Icons.phone_android;
      case DevicePlatform.windows:
        return Icons.desktop_windows;
      case DevicePlatform.linux:
        return Icons.computer;
      default:
        return Icons.devices;
    }
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

// ============================================
// ANIMATION WIDGETS
// ============================================

/// Animated card that fades and slides in
class _AnimatedCard extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final bool slideUp;

  const _AnimatedCard({
    required this.child,
    this.delay = Duration.zero,
    this.slideUp = false,
  });

  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.slideUp ? 0.2 : -0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Animated icon with scale effect
class _AnimatedIcon extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _AnimatedIcon({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<_AnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// Animated list item with stagger effect
class _AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedListItem({
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<_AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Stagger based on index (max 10 items stagger)
    final delay = Duration(milliseconds: 50 * (widget.index.clamp(0, 10)));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

/// NEW: Animated empty state widget WITH DRAG & DROP
class _AnimatedEmptyStateWithDrop extends StatefulWidget {
  final VoidCallback onPickFiles;
  final VoidCallback onPickMedia;
  final VoidCallback onPickFolder;
  final Function(DropDoneDetails) onFilesDropped;
  final bool isDragging;
  final bool isDesktop;

  const _AnimatedEmptyStateWithDrop({
    required this.onPickFiles,
    required this.onPickMedia,
    required this.onPickFolder,
    required this.onFilesDropped,
    required this.isDragging,
    required this.isDesktop,
  });

  @override
  State<_AnimatedEmptyStateWithDrop> createState() =>
      _AnimatedEmptyStateWithDropState();
}

class _AnimatedEmptyStateWithDropState extends State<_AnimatedEmptyStateWithDrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: widget.isDragging
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : AppTheme.surfaceColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.isDragging
                    ? AppTheme.primaryColor
                    : AppTheme.borderColor.withOpacity(0.3),
                width: widget.isDragging ? 3 : 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated folder icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: widget.isDragging ? 1.2 : value,
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: widget.isDragging
                              ? AppTheme.primaryColor.withOpacity(0.2)
                              : AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.isDragging
                              ? Icons.file_download_rounded
                              : Icons.folder_open_rounded,
                          size: 64,
                          color: widget.isDragging
                              ? AppTheme.primaryColor
                              : AppTheme.textTertiary,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isDragging ? 'Drop files here!' : 'No files selected',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: widget.isDragging
                            ? AppTheme.primaryColor
                            : AppTheme.textTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.isDesktop
                        ? 'Drag & drop files here, or use the buttons below'
                        : 'Select files or folders to send',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                // Animated buttons
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 360;

                    final fileButton = _AnimatedButton(
                      delay: const Duration(milliseconds: 300),
                      onPressed: widget.onPickFiles,
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Select Files',
                    );

                    final folderButton = _AnimatedButton(
                      delay: const Duration(milliseconds: 400),
                      onPressed: widget.onPickFolder,
                      icon: Icons.folder_rounded,
                      label: 'Select Folder',
                      isPrimary: false,
                    );

                    // NEW: Media button for photos & videos
                    final mediaButton = _AnimatedButton(
                      delay: const Duration(milliseconds: 500),
                      onPressed: widget.onPickMedia,
                      icon: Icons.photo_library_rounded,
                      label: 'Select Media',
                      isPrimary: false,
                    );

                    if (isNarrow) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: double.infinity, child: fileButton),
                            const SizedBox(height: 12),
                            SizedBox(width: double.infinity, child: mediaButton),
                            const SizedBox(height: 12),
                            SizedBox(
                                width: double.infinity, child: folderButton),
                          ],
                        ),
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        fileButton,
                        const SizedBox(width: 12),
                        mediaButton,
                        const SizedBox(width: 12),
                        folderButton,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Animated button widget
class _AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Duration delay;
  final bool isPrimary;

  const _AnimatedButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.delay = Duration.zero,
    this.isPrimary = true,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.isPrimary
            ? ElevatedButton.icon(
                onPressed: widget.onPressed,
                icon: Icon(widget.icon),
                label: Text(widget.label),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: widget.onPressed,
                icon: Icon(widget.icon),
                label: Text(widget.label),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Animated send button with loading state
class _AnimatedSendButton extends StatelessWidget {
  final bool isSending;
  final VoidCallback onPressed;
  final int fileCount;

  const _AnimatedSendButton({
    required this.isSending,
    required this.onPressed,
    required this.fileCount,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: ElevatedButton.icon(
        onPressed: isSending ? null : onPressed,
        icon: isSending
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded),
        label: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            isSending ? 'Sending...' : 'Send $fileCount file(s)',
            key: ValueKey(isSending),
          ),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 16,
          ),
          backgroundColor:
              isSending ? AppTheme.primaryColor.withOpacity(0.7) : null,
        ),
      ),
    );
  }
}

// ============================================
// FILE LIST TILE
// ============================================

/// File list tile with preview
class _FileListTile extends StatelessWidget {
  final TransferItem file;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const _FileListTile({
    required this.file,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fileType = FileTypeHelper.getFileType(file.name);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.cardColor.withOpacity(0.9),
            AppTheme.surfaceColor.withOpacity(0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: AppTheme.primaryColor.withOpacity(0.1),
          highlightColor: AppTheme.primaryColor.withOpacity(0.05),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // File preview
                Hero(
                  tag: 'file_preview_${file.path}',
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          FileTypeHelper.getIconColor(fileType).withOpacity(0.2),
                          FileTypeHelper.getIconColor(fileType).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: FileTypeHelper.getIconColor(fileType).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: FilePreviewWidget(
                      filePath: file.path,
                      fileName: file.name,
                      size: 44,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // File info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // File type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  FileTypeHelper.getBackgroundColor(fileType),
                                  FileTypeHelper.getBackgroundColor(fileType).withOpacity(0.7),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              FileTypeHelper.getFileExtension(file.name)
                                  .toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: FileTypeHelper.getIconColor(fileType),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // File size
                          Row(
                            children: [
                              const Icon(
                                Icons.storage_rounded,
                                size: 12,
                                color: AppTheme.textTertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                file.sizeFormatted,
                                style:
                                    Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textTertiary,
                                        ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Remove button
                if (onRemove != null)
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: onRemove,
                      color: AppTheme.textTertiary,
                      tooltip: 'Remove file',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// FILE DETAILS SHEET
// ============================================

/// File details bottom sheet
class _FileDetailsSheet extends StatelessWidget {
  final TransferItem file;

  const _FileDetailsSheet({required this.file});

  @override
  Widget build(BuildContext context) {
    final fileType = FileTypeHelper.getFileType(file.name);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

          // Large preview with Hero
          Hero(
            tag: 'file_preview_${file.path}',
            child: LargeFilePreview(
              filePath: file.path,
              fileName: file.name,
              maxHeight: 200,
            ),
          ),
          const SizedBox(height: 24),

          // File name
          Text(
            file.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),

          // File info chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _InfoChip(
                icon: Icons.storage_rounded,
                label: file.sizeFormatted,
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon: FileTypeHelper.getIcon(fileType),
                label: FileTypeHelper.getFileExtension(file.name).toUpperCase(),
                color: FileTypeHelper.getIconColor(fileType),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Path info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: AppTheme.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Location',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textTertiary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  file.path,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Info chip widget
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
