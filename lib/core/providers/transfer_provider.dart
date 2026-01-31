import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transfer.dart';
import '../services/transfer_service.dart';
import '../services/file_service.dart';

final fileServiceProvider = Provider<FileService>((ref) {
  return FileService();
});

final transferServiceProvider = Provider<TransferService>((ref) {
  final fileService = ref.watch(fileServiceProvider);
  final service = TransferService(fileService);
  ref.onDispose(() => service.dispose());
  return service;
});

final activeTransfersProvider = StreamProvider<Transfer>((ref) {
  final service = ref.watch(transferServiceProvider);
  return service.transferStream;
});

final selectedFilesProvider = StateProvider<List<TransferItem>>((ref) => []);

// Stream provider for pending transfer requests
// This allows the UI to reactively listen for incoming transfer requests
final pendingTransferRequestsProvider = StreamProvider<List<PendingTransferRequest>>((ref) {
  final service = ref.watch(transferServiceProvider);
  return service.pendingRequestsStream;
});
