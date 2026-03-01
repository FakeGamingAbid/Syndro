# Implementation Plan: Pause/Resume & Parallel Transfer Stats

## Feature 1: Pause & Resume Transfer from Notification

### Step 1.1: Add `paused` Status to TransferStatus Enum
- **File**: `lib/core/models/transfer.dart`
- Add `paused` to `TransferStatus` enum
- Add display name "Paused"
- Update `isActive` to include paused state

### Step 1.2: Add Pause/Resume Methods to TransferService
- Add `pauseTransfer(String transferId)` and `resumeTransfer(String transferId)` methods

### Step 1.3: Add Notification Actions
- Use local_notifier action buttons for Pause/Resume

## Feature 2: Parallel Transfer Stats Overlay
- Create stats model for chunk count and bytes per connection
- Add real-time stats overlay widget to transfer progress screen

## Implementation Order
1. Add `paused` status to enum
2. Add pause/resume service methods
3. Add notification action buttons
4. Create parallel stats model and overlay
5. Integrate into UI

## Key Files to Modify
- `lib/core/models/transfer.dart`
- `lib/core/services/transfer_service/transfer_service_impl.dart`
- `lib/core/services/parallel/parallel_transfer_service.dart`
- `lib/core/services/desktop_notification_service.dart`
- `lib/ui/screens/transfer_progress_screen.dart`
