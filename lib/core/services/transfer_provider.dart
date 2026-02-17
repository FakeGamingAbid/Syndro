import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transfer.dart';
import '../services/transfer_service.dart';
import '../services/file_service.dart';

// ============================================
// FILE SERVICE PROVIDER
// ============================================

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

// ============================================
// TRANSFER SERVICE PROVIDER
// ============================================

// FIXED: Removed duplicate onDispose callbacks that caused race conditions
final transferServiceProvider = Provider<TransferService>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  final service = TransferService(fileService);

  // FIX: onDispose doesn't await - call dispose without await
  ref.onDispose(() {
    debugPrint('🧹 Starting TransferService disposal...');
    service.dispose().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('⚠️ TransferService disposal timed out');
      },
    ).catchError((e) {
      debugPrint('⚠️ ERROR disposing TransferService: $e');
    });
  });

  return service;
});

// ============================================
// ACTIVE TRANSFERS PROVIDER
// ============================================

final activeTransfersProvider = StreamProvider<Transfer>((ref) {
  final service = ref.watch(transferServiceProvider);
  return service.transferStream;
});

// ============================================
// SELECTED FILES PROVIDER
// ============================================

final selectedFilesProvider = StateProvider<List<TransferItem>>((ref) => []);

// ============================================
// PENDING TRANSFER REQUESTS PROVIDER
// ============================================

/// Stream provider for pending transfer requests
/// This allows the UI to reactively listen for incoming transfer requests
final pendingTransferRequestsProvider =
    StreamProvider<List<PendingTransferRequest>>((ref) {
  final service = ref.watch(transferServiceProvider);
  return service.pendingRequestsStream;
});

// ============================================
// ADDITIONAL PROVIDERS
// ============================================

/// Provider to get the list of active transfers as a list (snapshot)
final activeTransfersListProvider = Provider<List<Transfer>>((ref) {
  final service = ref.watch(transferServiceProvider);
  return service.activeTransfers;
});

/// Provider to check if encryption is ready
final isEncryptionReadyProvider = Provider<bool>((ref) {
  final service = ref.watch(transferServiceProvider);
  return service.isEncryptionReady;
});

/// Provider to get trusted devices list
final trustedDevicesProvider = Provider<List<TrustedDevice>>((ref) {
  final service = ref.watch(transferServiceProvider);
  return service.trustedDevices;
});

// ============================================
// TRANSFER STATE NOTIFIER (Alternative approach)
// ============================================

/// A more robust way to manage transfer state with proper lifecycle
class TransferStateNotifier extends StateNotifier<TransferState> {
  final TransferService _service;
  StreamSubscription<Transfer>? _transferSubscription;
  StreamSubscription<List<PendingTransferRequest>>? _pendingSubscription;

  TransferStateNotifier(this._service) : super(TransferState.initial()) {
    _init();
  }

  void _init() {
    // Listen to transfer stream
    _transferSubscription = _service.transferStream.listen(
      (transfer) {
        state = state.copyWith(
          currentTransfer: transfer,
          transfers: _updateTransfersList(state.transfers, transfer),
        );
      },
      onError: (e) {
        debugPrint('Transfer stream error: $e');
        state = state.copyWith(error: e.toString());
      },
    );

    // Listen to pending requests
    _pendingSubscription = _service.pendingRequestsStream.listen(
      (requests) {
        state = state.copyWith(pendingRequests: requests);
      },
      onError: (e) {
        debugPrint('Pending requests stream error: $e');
      },
    );
  }

  List<Transfer> _updateTransfersList(
      List<Transfer> existing, Transfer updated) {
    final index = existing.indexWhere((t) => t.id == updated.id);
    if (index >= 0) {
      final newList = List<Transfer>.from(existing);
      newList[index] = updated;
      return newList;
    } else {
      return [...existing, updated];
    }
  }

  Future<void> approveTransfer(String requestId,
      {bool trustSender = false}) async {
    try {
      await _service.approveTransfer(requestId, trustSender: trustSender);
    } catch (e) {
      debugPrint('Error approving transfer: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  void rejectTransfer(String requestId) {
    try {
      _service.rejectTransfer(requestId);
    } catch (e) {
      debugPrint('Error rejecting transfer: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  void cancelTransfer(String transferId) {
    try {
      _service.cancelTransfer(transferId);
    } catch (e) {
      debugPrint('Error cancelling transfer: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  @override
  void dispose() {
    // FIXED: Properly cancel subscriptions before disposing
    _transferSubscription?.cancel();
    _transferSubscription = null;
    _pendingSubscription?.cancel();
    _pendingSubscription = null;
    super.dispose();
  }
}

/// Transfer state model
class TransferState {
  final List<Transfer> transfers;
  final Transfer? currentTransfer;
  final List<PendingTransferRequest> pendingRequests;
  final String? error;
  final bool isLoading;

  TransferState({
    required this.transfers,
    this.currentTransfer,
    required this.pendingRequests,
    this.error,
    this.isLoading = false,
  });

  factory TransferState.initial() => TransferState(
        transfers: [],
        pendingRequests: [],
      );

  TransferState copyWith({
    List<Transfer>? transfers,
    Transfer? currentTransfer,
    List<PendingTransferRequest>? pendingRequests,
    String? error,
    bool? isLoading,
  }) {
    return TransferState(
      transfers: transfers ?? this.transfers,
      currentTransfer: currentTransfer ?? this.currentTransfer,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Optional: State notifier provider for more complex transfer management
final transferStateProvider =
    StateNotifierProvider<TransferStateNotifier, TransferState>((ref) {
  final service = ref.watch(transferServiceProvider);
  final notifier = TransferStateNotifier(service);

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});
