# Additional Bugs Found - Deep Scan

## Critical New Bugs (7)

### Bug #31: Timer Leak in ShareServer
**File:** `lib/core/services/web_share/servers/share_server.dart`
**Issue:** Anonymous Timer.periodic created but never stored or cancelled
```dart
Timer.periodic(const Duration(minutes: 5), (_) => _cleanupStaleClients());
```
**Fix:** Store timer reference and cancel in dispose()

### Bug #32: Multiple Timer Leaks in TransferServiceImpl
**File:** `lib/core/services/transfer_service/transfer_service_impl.dart`
**Issue:** 
- `_sessionCleanupTimer` - may not be cancelled
- `_pendingRequestsCleanupTimer` - may not be cancelled
- `_notificationEventSubscription` - may not be cancelled
**Fix:** Add proper disposal with try-catch

### Bug #33: Unsafe Type Casts Without Validation
**Files:** Multiple files
**Issue:** Direct `as` casts that can throw ClassCastException
- `lib/ui/screens/history_screen.dart` - Multiple unsafe casts
- `lib/core/services/transfer_service/http_response_helper.dart` - `data['senderId'] as String`
- `lib/core/models/folder_structure.dart` - Nested map casts
**Fix:** Use safe casting with null coalescing

### Bug #34: int.parse Without Try-Catch
**Files:** 
- `lib/core/services/parallel/parallel_config.dart` - Parsing memory info
- `lib/core/services/transfer_service/transfer_service_impl.dart` - Parsing chunk index
**Issue:** Can throw FormatException
**Fix:** Use int.tryParse() instead

### Bug #35: StreamController.add Without isClosed Check
**Files:** Multiple files
**Issue:** Adding to potentially closed controllers
- `lib/core/services/transfer_service/transfer_service_impl.dart` - Multiple locations
- `lib/core/services/transfer_service/trusted_devices_handler.dart`
**Fix:** Check `!controller.isClosed` before adding

### Bug #36: Navigator Operations Without Mounted Check
**Files:** Multiple UI files
**Issue:** Navigator.of(context) called without checking if widget is still mounted
- `lib/ui/screens/transfer_progress_screen.dart` - Multiple pop() calls
- `lib/ui/screens/file_picker_screen.dart` - pushReplacement without mounted check
**Fix:** Always check `mounted` before Navigator operations

### Bug #37: setState in Async Callbacks Without Mounted Check
**Files:** Multiple UI files
**Issue:** setState called after async operations without checking mounted state
- All Future.delayed callbacks should check mounted
- All async callbacks in UI should verify widget is still mounted
**Fix:** Add `if (!mounted) return;` before setState

## High Priority Bugs (5)

### Bug #38: Stream Subscription Leaks in UI
**Files:**
- `lib/ui/screens/browser_share_screen.dart` - 2 subscriptions
- `lib/ui/screens/browser_receive_screen.dart` - 2 subscriptions
- `lib/ui/screens/file_picker_screen.dart` - 1 subscription
**Issue:** Subscriptions may not be cancelled in dispose
**Fix:** Add try-catch in dispose for all subscriptions

### Bug #39: Unsafe JSON Casting in History Screen
**File:** `lib/ui/screens/history_screen.dart`
**Issue:** Multiple unsafe casts from database results
```dart
transfer['id'] as String
transfer['status'] as String
transfer['file_count'] as int
```
**Fix:** Use safe casting with defaults

### Bug #40: Memory Leak in Connected Clients
**File:** `lib/core/services/web_share/servers/share_server.dart`
**Issue:** `_connectedClients` map grows unbounded if cleanup fails
**Fix:** Already has cleanup, but should add max size limit

### Bug #41: Race Condition in Parallel Transfer
**File:** `lib/core/services/parallel/parallel_transfer_service.dart`
**Issue:** Retry logic uses Future.delayed without checking if transfer was cancelled
**Fix:** Check cancellation status before retry

### Bug #42: Encryption Session Concurrent Access
**File:** `lib/core/services/transfer_service/transfer_service_impl.dart`
**Issue:** `_encryptionSessions` map accessed from multiple async contexts without synchronization
**Fix:** Use synchronized access or convert to immutable updates

## Medium Priority Bugs (3)

### Bug #43: Missing Error Handling in Stream Listeners
**Files:** Multiple
**Issue:** Stream.listen() calls without onError handlers
**Fix:** Add onError callbacks to all stream listeners

### Bug #44: Unsafe DateTime.parse
**Files:** Multiple models
**Issue:** DateTime.parse can throw FormatException
**Fix:** Already has safe parsing in Device model, apply to all

### Bug #45: File Path Validation Incomplete
**File:** `lib/core/services/file_service.dart`
**Issue:** Path validation doesn't check for null bytes in middle of string
**Fix:** Add comprehensive validation

## Code Quality Issues (5)

### Bug #46: Inconsistent Null Safety
**Issue:** Some methods use `!` operator, others use null coalescing
**Fix:** Standardize on null coalescing with defaults

### Bug #47: Magic Numbers
**Issue:** Hardcoded values throughout codebase
- Timeout values
- Retry counts
- Buffer sizes
**Fix:** Extract to named constants

### Bug #48: Missing Timeout on HTTP Requests
**Files:** Multiple
**Issue:** Some HTTP requests don't have timeouts
**Fix:** Add consistent timeout policy

### Bug #49: Incomplete Error Messages
**Issue:** Some exceptions don't include context
**Fix:** Add more descriptive error messages

### Bug #50: Missing Input Validation
**Issue:** Some public methods don't validate inputs
**Fix:** Add validation at API boundaries

## Summary by Severity

**Critical (7):** Bugs #31-37 - Resource leaks, crashes, memory issues
**High (5):** Bugs #38-42 - Data corruption, race conditions
**Medium (3):** Bugs #43-45 - Error handling gaps
**Low (5):** Bugs #46-50 - Code quality

## Most Critical Fixes Needed

1. **Timer Leaks** - Bugs #31, #32
2. **Unsafe Type Casts** - Bug #33
3. **Stream Subscription Leaks** - Bug #38
4. **Navigator Without Mounted** - Bug #36
5. **StreamController.add Without Check** - Bug #35

## Files Requiring Immediate Attention

1. `lib/core/services/web_share/servers/share_server.dart`
2. `lib/core/services/transfer_service/transfer_service_impl.dart`
3. `lib/ui/screens/history_screen.dart`
4. `lib/ui/screens/transfer_progress_screen.dart`
5. `lib/ui/screens/browser_share_screen.dart`
6. `lib/ui/screens/browser_receive_screen.dart`

## Recommended Testing

1. **Memory Leak Testing**
   - Run app for 24+ hours
   - Monitor timer count
   - Check stream subscription count
   - Verify controller cleanup

2. **Crash Testing**
   - Send malformed JSON
   - Test with invalid type data
   - Rapid navigation between screens
   - Cancel operations mid-flight

3. **Concurrency Testing**
   - Multiple simultaneous transfers
   - Rapid start/stop cycles
   - Network interruptions
   - Device discovery during transfers

4. **UI State Testing**
   - Navigate away during async operations
   - Dispose widgets during callbacks
   - Test all Future.delayed scenarios
   - Verify mounted checks

## Total Bugs Found

- **Original Scan:** 30 bugs
- **Deep Scan:** 20 additional bugs
- **Total:** 50 bugs identified

## Fix Priority

1. **Immediate (Critical):** 12 bugs
2. **High Priority:** 10 bugs  
3. **Medium Priority:** 13 bugs
4. **Low Priority (Code Quality):** 15 bugs
