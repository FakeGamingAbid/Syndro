import 'dart:async';

/// A queue-based mutual exclusion lock for thread-safe async operations.
///
/// Wraps [_queue] to serialize access to critical sections. Supports:
/// - Generic return types via [synchronized<T>]
/// - Optional disposal via [dispose] to prevent use-after-cleanup
///
/// Usage:
/// ```dart
/// final lock = SynchronizedLock<int>();
/// final result = await lock.synchronized(() async {
///   // Critical section
///   return 42;
/// });
/// ```
class SynchronizedLock<T> {
  final _queue = <Completer<void>>[];
  bool _locked = false;
  bool _disposed = false;
  Completer<void>? _disposeCompleter;

  /// Execute [action] while holding the lock.
  ///
  /// Actions are queued and executed in FIFO order. Returns the result
  /// of [action]. Throws [StateError] if the lock has been disposed.
  Future<T> synchronized(FutureOr<T> Function() action) async {
    if (_disposed) {
      throw StateError('SynchronizedLock has been disposed');
    }

    final completer = Completer<void>();
    _queue.add(completer);

    if (_locked || _queue.length > 1) {
      await completer.future;
    }

    _locked = true;

    try {
      return await action();
    } finally {
      _locked = false;
      _queue.removeAt(0);

      if (_queue.isNotEmpty) {
        try {
          _queue.first.complete();
        } catch (e) {
          // Ignore notification errors (lock already disposed)
        }
      }
    }
  }

  /// Prevent any further use of this lock.
  ///
  /// Any pending or future [synchronized] calls will throw [StateError].
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _disposeCompleter?.complete();
  }
}
