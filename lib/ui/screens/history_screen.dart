import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../../core/database/database_helper.dart';
import '../../core/models/transfer.dart';

// Filter enum for transfer types
enum TransferFilter { all, sent, received, failed }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  List<Map<String, dynamic>> _transfers = [];
  bool _isLoading = true;
  Map<String, int> _statistics = {};
  
  // Search and filter state
  String _searchQuery = '';
  TransferFilter _currentFilter = TransferFilter.all;
  bool _isMultiSelectMode = false;
  final Set<String> _selectedTransfers = {};
  final TextEditingController _searchController = TextEditingController();
  
  // Deleted transfer for undo
  Map<String, dynamic>? _lastDeletedTransfer;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    // FIXED (Bug #23): Add mounted check before setState
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final db = DatabaseHelper.instance;
      List<Map<String, dynamic>> transfers;
      
      // Apply search and filter
      if (_searchQuery.isNotEmpty) {
        if (_currentFilter == TransferFilter.all) {
          transfers = await db.searchTransfers(_searchQuery);
        } else {
          // Map filter to status
          final status = _getStatusFromFilter(_currentFilter);
          if (status != null) {
            transfers = await db.getTransfersByStatusAndSearch(status, _searchQuery);
          } else {
            transfers = await db.getTransferHistory(limit: 100);
          }
        }
      } else {
        if (_currentFilter == TransferFilter.all) {
          transfers = await db.getTransferHistory(limit: 100);
        } else {
          final status = _getStatusFromFilter(_currentFilter);
          if (status != null) {
            transfers = await db.getTransfersByStatus(status);
          } else {
            transfers = await db.getTransferHistory(limit: 100);
          }
        }
      }
      
      final stats = await db.getStatistics();

      // FIXED (Bug #23): Add mounted check before setState
      if (mounted) {
        setState(() {
          _transfers = transfers;
          _statistics = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      // FIXED (Bug #23): Add mounted check before setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading history: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Helper to get TransferStatus from filter
  TransferStatus? _getStatusFromFilter(TransferFilter filter) {
    switch (filter) {
      case TransferFilter.sent:
        return TransferStatus.completed;
      case TransferFilter.failed:
        return TransferStatus.failed;
      case TransferFilter.received:
        // Received is also completed but from a different device
        return null; // Will need to handle differently
      case TransferFilter.all:
        return null;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadHistory();
  }

  void _onFilterChanged(TransferFilter filter) {
    setState(() {
      _currentFilter = filter;
    });
    _loadHistory();
  }

  Future<void> _deleteTransfer(String transferId) async {
    try {
      await DatabaseHelper.instance.deleteTransfer(transferId);
      await _loadHistory();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer removed from history'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting transfer: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _clearAllHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text(
          'This will permanently delete all transfer records. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.clearHistory();
        await _loadHistory();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('History cleared'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing history: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  String _formatTimestamp(int milliseconds) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return 'Today ${_formatTime(dateTime)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${_formatTime(dateTime)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatBytes(int bytes) {
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.successColor;
      case 'failed':
      case 'cancelled':
        return AppTheme.errorColor;
      default:
        return AppTheme.textTertiary;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.sync;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                Icons.history,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(_isMultiSelectMode 
                ? '${_selectedTransfers.length} selected' 
                : 'Transfer History'),
          ],
        ),
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () {
                setState(() {
                  if (_selectedTransfers.length == _transfers.length) {
                    _selectedTransfers.clear();
                  } else {
                    _selectedTransfers.addAll(
                      _transfers.map((t) => t['id'] as String),
                    );
                  }
                });
              },
              tooltip: 'Select All',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: AppTheme.errorColor),
              onPressed: _selectedTransfers.isEmpty ? null : _deleteSelectedTransfers,
              tooltip: 'Delete Selected',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedTransfers.clear();
                });
              },
              tooltip: 'Cancel',
            ),
          ] else ...[
            if (_transfers.isNotEmpty)
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_sweep,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                ),
                onPressed: _clearAllHistory,
                tooltip: 'Clear All',
              ),
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _transfers.isEmpty ? null : () {
                setState(() {
                  _isMultiSelectMode = true;
                });
              },
              tooltip: 'Multi-select',
            ),
          ],
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by filename or device name...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _buildFilterChip('All', TransferFilter.all),
                        const SizedBox(width: 8),
                        _buildFilterChip('Sent', TransferFilter.sent),
                        const SizedBox(width: 8),
                        _buildFilterChip('Received', TransferFilter.received),
                        const SizedBox(width: 8),
                        _buildFilterChip('Failed', TransferFilter.failed),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatistics(),
                  Expanded(
                    child: _transfers.isEmpty
                        ? _buildEmptyState()
                        : _buildHistoryList(),
                  ),
                ],
      ),
    );
  }

  // Build filter chip widget
  Widget _buildFilterChip(String label, TransferFilter filter) {
    final isSelected = _currentFilter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(filter),
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      checkmarkColor: AppTheme.primaryColor,
    );
  }

  // Delete selected transfers
  Future<void> _deleteSelectedTransfers() async {
    if (_selectedTransfers.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected?'),
        content: Text(
          'This will permanently delete ${_selectedTransfers.length} transfer record(s). '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DatabaseHelper.instance.deleteTransfers(_selectedTransfers.toList());
        
        if (mounted) {
          setState(() {
            _isMultiSelectMode = false;
            _selectedTransfers.clear();
          });
          await _loadHistory();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted ${_selectedTransfers.length} transfer(s)'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting transfers: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.history,
            size: 64,
            color: AppTheme.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No transfer history',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textTertiary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your completed transfers will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textTertiary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    if (_statistics.isEmpty) return const SizedBox.shrink();

    return Container(
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total',
            _statistics['totalTransfers']?.toString() ?? '0',
            Icons.swap_horiz,
          ),
          _buildStatItem(
            'Completed',
            _statistics['completedTransfers']?.toString() ?? '0',
            Icons.check_circle,
            color: AppTheme.successColor,
          ),
          _buildStatItem(
            'Data',
            _formatBytes(_statistics['totalBytes'] ?? 0),
            Icons.data_usage,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon,
      {Color? color}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (color ?? AppTheme.primaryColor).withOpacity(0.2),
                (color ?? AppTheme.primaryColor).withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (color ?? AppTheme.primaryColor).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: color ?? AppTheme.primaryColor,
            size: 26,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textTertiary,
              ),
        ),
      ],
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _transfers.length,
      itemBuilder: (context, index) {
        final transfer = _transfers[index];

        // FIX (Bug #33, #39): Safe type casting with defaults
        final transferId = transfer['id'] as String? ?? '';
        final status = transfer['status'] as String? ?? 'unknown';
        final receiverName = transfer['receiver_name'] as String? ?? 'Unknown Device';
        final fileCount = transfer['file_count'] as int? ?? 0;
        final totalBytes = transfer['total_bytes'] as int? ?? 0;
        final createdAt = transfer['created_at'] as int? ?? 0;

        return Dismissible(
          key: Key(transferId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppTheme.errorColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => _deleteTransfer(transferId),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                color: _getStatusColor(status)
                    .withOpacity(0.2),
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
                borderRadius: BorderRadius.circular(16),
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _getStatusColor(status)
                                  .withOpacity(0.2),
                              _getStatusColor(status)
                                  .withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _getStatusColor(status)
                                .withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              receiverName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getFileTypeIcon(fileCount),
                                        size: 12,
                                        color: AppTheme.textTertiary,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$fileCount file(s)',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: AppTheme.textTertiary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatBytes(totalBytes),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 12,
                                  color: AppTheme.textTertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTimestamp(createdAt),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.textTertiary,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceColor.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getFileTypeIcon(int fileCount) {
    if (fileCount > 1) return Icons.folder;
    return Icons.insert_drive_file_rounded;
  }
}
