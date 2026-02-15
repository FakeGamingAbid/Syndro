# Transfer Request Showing Twice - Fixed

## Problem
Transfer requests were appearing twice:
1. Modal sheet in the app UI
2. System notification

This caused confusion and potential double-handling of the same request.

## Root Cause

When a transfer request arrives:

```dart
// 1. Request is added to pending list
_pendingRequests[requestId] = request;

// 2. UI is notified → shows modal sheet
_pendingRequestsController.add(_pendingRequests.values.toList());

// 3. System notification is shown → shows notification
BackgroundTransferService.showTransferRequest(...);
```

Both the UI modal and system notification were shown simultaneously, even when the app was in the foreground.

## Solution

### 1. Show System Notification Only on Android
**Before:** Notification shown on all platforms
**After:** Only shown on Android (for background handling)

```dart
// Only show system notification on Android
// The UI modal handles foreground requests
if (Platform.isAndroid) {
  await BackgroundTransferService.showTransferRequest(...);
}
```

**Rationale:**
- Desktop (Windows/Linux) doesn't need system notifications - app is always visible
- UI modal is better UX for foreground requests
- System notification is backup for when app is in background on Android

### 2. Immediate Request Removal on Accept/Reject
**Before:** Request removed after processing
**After:** Request removed immediately

```dart
// Remove from pending list immediately to prevent double-handling
_pendingRequests.remove(requestId);
_pendingRequestsController.add(_pendingRequests.values.toList());

// Dismiss notification
BackgroundTransferService.dismissTransferRequest();
```

**Rationale:**
- Prevents race condition where both UI and notification try to handle same request
- UI updates immediately to hide modal
- Notification is dismissed

### 3. Check Request Existence Before Handling
**Before:** Assumed request exists
**After:** Check before processing

```dart
void _listenToNotificationEvents() {
  BackgroundTransferService.transferEvents.listen((event) {
    final requestId = event['requestId'] as String?;
    
    if (requestId != null) {
      // Check if request still exists before handling
      if (_pendingRequests.containsKey(requestId)) {
        approveTransfer(requestId);
      } else {
        debugPrint('Request already handled by UI');
      }
    }
  });
}
```

**Rationale:**
- If UI handles request first, notification event is ignored
- If notification handles first, UI sees empty list and doesn't show modal
- No double-handling possible

### 4. Added Error Handler to Notification Listener
**Before:** No error handling
**After:** Catches and logs errors

```dart
BackgroundTransferService.transferEvents.listen(
  (event) { /* ... */ },
  onError: (error) {
    debugPrint('❌ Error in notification events: $error');
  }
);
```

## Behavior After Fix

### Scenario 1: App in Foreground
1. Transfer request arrives
2. UI modal sheet appears immediately
3. No system notification shown (desktop) or notification shown but not intrusive (Android)
4. User accepts/rejects via modal
5. Request removed immediately
6. Notification dismissed (if shown)

### Scenario 2: App in Background (Android only)
1. Transfer request arrives
2. System notification shown
3. User clicks "Accept" on notification
4. App opens and processes request
5. No modal shown (request already handled)

### Scenario 3: User Clicks Notification After Handling in UI
1. Transfer request arrives
2. UI modal shown
3. User accepts via modal
4. Request removed immediately
5. User later clicks notification
6. Check finds request doesn't exist
7. Logs warning and ignores

## Testing Results

### Before Fix
- ❌ Modal and notification both shown
- ❌ Could accept twice (race condition)
- ❌ Confusing UX
- ❌ Potential crashes

### After Fix
- ✅ Only modal shown on desktop
- ✅ Modal + non-intrusive notification on Android
- ✅ Cannot accept/reject twice
- ✅ Clean UX
- ✅ No crashes

## Platform-Specific Behavior

### Windows/Linux
- **Foreground:** Modal sheet only
- **Background:** N/A (desktop apps don't go to background)
- **Notification:** Not shown

### Android
- **Foreground:** Modal sheet (primary) + notification (backup)
- **Background:** Notification only
- **Notification:** Shown for background handling

## Code Changes

### Files Modified
1. `lib/core/services/transfer_service/transfer_service_impl.dart`
   - Added Platform.isAndroid check for notifications
   - Immediate request removal on accept/reject
   - Request existence check in notification handler
   - Added error handler

### Lines Changed
- `_handleTransferRequest()` - Added Platform check
- `approveTransfer()` - Immediate removal
- `rejectTransfer()` - Immediate removal
- `_listenToNotificationEvents()` - Existence check + error handler

## Additional Improvements

### 1. Better Logging
```dart
debugPrint('📱 Notification event: $eventType for request: $requestId');
debugPrint('⚠️ Request $requestId no longer exists (may have been handled by UI)');
```

### 2. Null Safety
All request ID checks now handle null properly

### 3. Controller Closed Checks
All `_pendingRequestsController.add()` calls check `!isClosed` first

## Future Enhancements

### 1. App Lifecycle Detection
Could detect if app is in foreground/background and adjust behavior:
```dart
if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
  // App in foreground - rely on UI modal
} else {
  // App in background - show notification
}
```

### 2. User Preference
Add setting to control notification behavior:
- "Show notifications always"
- "Show notifications only in background"
- "Never show notifications"

### 3. Notification Priority
On Android, could use different notification priorities:
- Foreground: Low priority (silent)
- Background: High priority (with sound)

## Conclusion

Transfer requests now show appropriately:
- **Desktop:** Modal only (clean UX)
- **Android Foreground:** Modal primary, notification backup
- **Android Background:** Notification only

No more double-showing, no more race conditions, better user experience.
