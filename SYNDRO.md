# Syndro - Cross-Platform File Sharing App

A secure, fast, and easy-to-use file sharing application for Android, Windows, and Linux.

---

## Table of Contents

- [Features](#-features)
- [Technology Stack](#-technology-stack)
- [Usage Guide](#-usage-guide)
- [Technical Details](#-technical-details)
- [Project Structure](#-project-structure)
- [Platform-Specific Features](#-platform-specific-features)
- [Security Implementation](#-security-implementation)
- [Transfer Protocol](#-transfer-protocol)
- [License](#-license)

---

## Features

### Core File Sharing

| Feature | Description |
|---------|-------------|
| **Cross-Platform Transfer** | Share files between Android, Windows, and Linux devices |
| **Peer-to-Peer (P2P)** | Direct device-to-device transfer over local network (no internet required) |
| **Multiple Files** | Send multiple files and folders at once |
| **Large File Support** | Transfer files of any size (GBs supported) |
| **Folder Transfer** | Send entire folders with directory structure preserved |
| **Resume Transfers** | Interrupted transfers can be resumed from where they left off using checkpoints |
| **Parallel Transfer** | Multi-connection transfers for large files (>10MB) with automatic speed optimization |

### Security & Privacy

| Feature | Description |
|---------|-------------|
| **End-to-End Encryption** | All transfers encrypted with AES-256-GCM |
| **X25519 Key Exchange** | Same encryption used by Signal and WhatsApp |
| **Trusted Devices** | Mark devices as trusted for auto-accept |
| **Transfer Approval** | Accept/reject incoming transfers manually |
| **No Cloud Storage** | Files never leave your local network |
| **Nonce Tracking** | Prevents replay attacks with unique nonces per chunk |
| **Secure Key Storage** | Keys stored in Flutter Secure Storage |

### Android-Specific Features

| Feature | Description |
|---------|-------------|
| **Android Share Sheet Integration** | Share files directly from gallery, file manager, or any app |
| **Two Share Modes** | "App to App" for device transfer, "Browser Share" for web sharing |
| **Content URI Support** | Handles content:// URIs from other apps correctly |
| **Media Thumbnails** | Shows image/video thumbnails when sharing from gallery |
| **Background Transfer** | Continue transfers while app is in background via Foreground Service |
| **Notification Progress** | Real-time progress in notification bar |
| **Notification Actions** | Accept/Reject transfers from notification |
| **Media Permissions** | Proper handling of Android 13+ media permissions (READ_MEDIA_IMAGES, etc.) |

### Desktop-Specific Features (Windows & Linux)

| Feature | Description |
|---------|-------------|
| **Right-Click Context Menu** | Send files directly from Windows Explorer / Linux file manager (Nautilus/Dolphin) |
| **System Tray** | App runs in system tray for quick access |
| **Desktop Notifications** | Rich notifications with file thumbnails using local_notifier |
| **Drag & Drop** | Drag files onto app window to select via desktop_drop |
| **Window Management** | Minimize to tray, close behavior options via window_manager |
| **Launch at Startup** | Option to start automatically on system boot |
| **Command-Line Arguments** | Right-click send passes files as command-line arguments |

### Browser Share Mode

| Feature | Description |
|---------|-------------|
| **QR Code Sharing** | Generate QR code for instant browser access |
| **No App Required** | Receivers can download via any web browser |
| **Multiple Viewers** | Share with multiple people simultaneously (up to 500 connections) |
| **Connection Tracking** | See connected viewers (IP, device type, user agent) |
| **Expiration Timer** | Auto-stop sharing after configurable time (default 1 hour) |
| **Drop Zone** | Drag & drop files directly onto web page |
| **Encrypted Downloads** | Browser can download encrypted files with JavaScript decryption |
| **Parallel Downloads** | Multi-connection downloads in browser for large files |

### Browser Receive Mode

| Feature | Description |
|---------|-------------|
| **Receive from Browser** | Accept files uploaded from any web browser |
| **QR Code Access** | Scan QR to open upload page |
| **Drag & Drop Upload** | Drag files onto web page to upload |
| **Progress Tracking** | Real-time upload progress in browser |
| **Multiple Files** | Upload multiple files at once |
| **Pending Files** | Files held in temp location until user saves or discards |

### User Interface

| Feature | Description |
|---------|-------------|
| **Device Discovery** | Automatic discovery of nearby devices via UDP broadcast |
| **Device Nicknames** | Custom names for easy device identification |
| **Transfer History** | View past transfers with details stored in SQLite |
| **Dark Theme** | Modern dark UI theme with Material Design |
| **Animations** | Smooth transitions, shimmer loading, pulse animations |
| **File Previews** | Thumbnail previews for images and videos |
| **Full-Screen Image Viewer** | View images in full screen with zoom (photo_view) |
| **Onboarding** | First-time user tutorial for permissions and features |
| **Quick Send Screen** | Direct file selection when launched with file arguments |

---

## Technology Stack

### Framework & Language

| Technology | Purpose |
|------------|---------|
| **Flutter/Dart** | Cross-platform UI framework (SDK ^3.2.0) |
| **Kotlin** | Android native code (notifications, share intent, foreground service) |
| **C++** | Linux native code |

### Networking

| Technology | Purpose |
|------------|---------|
| **HTTP Server** | Built-in HTTP server for file transfers (ports 8765-8770) |
| **UDP Broadcast** | Device discovery on local network (port 8771) |
| **HTTP Client** | File sending with http package |
| **WebSocket** | Real-time browser communication |

### Security

| Technology | Purpose |
|------------|---------|
| **X25519** | Key exchange algorithm (cryptography package) |
| **AES-256-GCM** | Symmetric encryption with authenticated encryption |
| **SHA-256** | File integrity verification (crypto package) |
| **Flutter Secure Storage** | Secure key storage with platform encryption |

### Data Storage

| Technology | Purpose |
|------------|---------|
| **SQLite (sqflite)** | Local database for transfer history |
| **sqflite_common_ffi** | SQLite FFI support for desktop platforms |
| **SharedPreferences** | App settings storage |
| **File System** | Temporary file storage, checkpoint files |

### State Management

| Technology | Purpose |
|------------|---------|
| **Riverpod** | State management (flutter_riverpod ^2.4.9) |
| **StreamController** | Event streaming for progress updates |

### Platform Integration

| Technology | Purpose |
|------------|---------|
| **MethodChannel** | Flutter Native communication |
| **EventChannel** | Native Flutter event streams |
| **Platform Channels** | Platform-specific functionality |

### UI Components

| Technology | Purpose |
|------------|---------|
| **Material Design** | UI components |
| **QR Flutter** | QR code generation (qr_flutter ^4.1.0) |
| **Mobile Scanner** | QR code scanning (mobile_scanner ^4.0.1) |
| **Video Thumbnail** | Video preview generation (video_thumbnail ^0.5.3) |
| **Photo View** | Full-screen image viewer with zoom (photo_view ^0.14.0) |
| **File Picker** | Native file selection (file_picker ^6.1.1) |
| **Path Provider** | Platform-specific paths (path_provider ^2.1.1) |
| **Shimmer** | Loading animations (shimmer ^3.0.0) |
| **Animations** | Pre-built animations (animations ^2.0.11) |

### Desktop-Specific Packages

| Technology | Purpose |
|------------|---------|
| **window_manager** | Window management (minimize, close, tray) |
| **system_tray** | System tray icon and menu |
| **desktop_drop** | Drag and drop file selection |
| **local_notifier** | Desktop notifications with images |
| **launch_at_startup** | Auto-start on system boot |

### Audio

| Technology | Purpose |
|------------|---------|
| **audioplayers** | Play notification sounds (audioplayers ^5.2.1) |

---

## Usage Guide

### Installation

#### Android
1. Download APK from releases
2. Enable "Install from unknown sources" if needed
3. Install the APK
4. Grant storage and notification permissions on first launch

#### Windows
1. Download the Windows installer
2. Run the installer
3. Optionally install context menu integration via `install-context-menu.bat`

#### Linux
1. Download the AppImage or .deb package
2. For context menu integration:
   - Nautilus: Run `install-context-menu.sh`
   - Dolphin: Copy `syndro-dolphin.desktop` to the appropriate directory

### First Time Setup

1. **Grant Permissions** (Android)
   - Storage permission for file access
   - Notification permission for transfer alerts
   - Media permissions for images/videos (Android 13+)

2. **Device Name**
   - Your device is automatically named
   - Change it in Settings for easy identification

### Sending Files

#### Method 1: From App
1. Open Syndro
2. Tap "Send Files" or "Send Photos/Videos"
3. Select files to send
4. Choose destination device from discovered devices
5. Wait for acceptance (if not trusted)
6. Transfer begins automatically

#### Method 2: Android Share Sheet
1. Open any app (Gallery, File Manager, etc.)
2. Select files
3. Tap "Share"
4. Choose "App to App" for device transfer
   - OR choose "Browser Share" for web sharing
5. Syndro opens with files ready to send

#### Method 3: Desktop Right-Click
1. Right-click on file(s) in Explorer/Nautilus/Dolphin
2. Select "Send with Syndro"
3. App opens with files ready to send

#### Method 4: Drag & Drop
1. Open Syndro
2. Drag files onto the app window
3. Select destination device

### Receiving Files

#### From Another Device
1. Keep Syndro open
2. When someone sends files, you'll see a request
3. Tap "Accept" or "Reject"
4. Files save to Downloads folder

#### From Browser (Browser Receive Mode)
1. Open Syndro
2. Tap "Receive from Browser"
3. Share the QR code or URL with sender
4. Sender opens URL in any browser
5. Sender drags/drops or selects files
6. Files appear in your Downloads

### Browser Share Mode

1. Open Syndro
2. Select files to share
3. Tap "Share via Browser"
4. A QR code and URL are generated
5. Share the URL/QR with recipients
6. Recipients open URL in any browser
7. They can download files directly
8. Tap "Stop Sharing" when done

### Managing Trusted Devices

1. After accepting a transfer, tap "Trust Device"
2. Trusted devices can send without approval
3. Manage trusted devices in Settings
4. Remove trust anytime

### Viewing Transfer History

1. Open Syndro
2. Tap "History" tab
3. See all past transfers
4. View details: files, size, date, status

### Settings

| Setting | Description |
|---------|-------------|
| **Device Name** | Change your device display name |
| **Download Location** | Where received files are saved |
| **Auto-Accept Trusted** | Auto-accept from trusted devices |
| **Sound Notifications** | Play sound on transfer events |
| **Theme** | Dark/Light mode |

---

## Technical Details

### Transfer Protocol

1. **Discovery**: UDP broadcast on port 8771
   - Devices announce presence every 5 seconds
   - Stale devices removed after 30 seconds timeout

2. **Connection**: HTTP on ports 8765-8770
   - Server binds to first available port
   - Port scanning for device detection

3. **Encryption**: X25519 key exchange AES-256-GCM
   - Each chunk has unique nonce
   - Nonce tracking prevents replay attacks

4. **Chunking**: Files split into 1MB chunks
   - Streaming hash for integrity (SHA-256)
   - Memory-efficient processing

5. **Resume**: Checkpoint saved every 10MB
   - JSON checkpoint files stored in app directory
   - File-based locking for cross-process safety

6. **Parallel Transfer**: For files >10MB
   - 6 concurrent HTTP connections
   - Chunk-based transfer with resume support
   - Automatic speed optimization

### File Size Limits

| Platform | Limit |
|----------|-------|
| Android | No limit (storage dependent) |
| Windows | No limit (storage dependent) |
| Linux | No limit (storage dependent) |
| Browser | ~2GB (browser dependent) |

### Network Requirements

- Same WiFi network for P2P transfer
- No internet required
- Firewall: Allow ports 8765-8771

### Memory Efficiency

- **Streaming Hash**: ~1MB memory regardless of file size
- **Chunked Transfer**: 1MB chunks prevent memory overflow
- **Checkpoint System**: Resume without re-transferring

---

## Project Structure

```
lib/
 main.dart                 # App entry point, argument parsing, window setup
 core/
   database/               # SQLite database helper
     database_helper.dart
   models/                 # Data models
     device.dart           # Device model with platform enum
     transfer.dart         # Transfer item and progress models
     transfer_checkpoint.dart  # Checkpoint model for resume
     encryption_models.dart    # Encryption key models
     folder_structure.dart    # Folder structure model
   providers/              # Riverpod providers
     device_provider.dart      # Device discovery provider
     transfer_provider.dart    # Transfer state provider
     incoming_files_provider.dart  # Incoming files provider
     device_nickname_provider.dart  # Device nickname provider
   services/               # Business logic
     encryption_service.dart     # AES-256-GCM + X25519
     file_service.dart           # File operations, sanitization
     device_discovery_service.dart  # UDP broadcast discovery
     streaming_hash_service.dart   # Memory-efficient SHA-256
     checkpoint_manager.dart       # Resume checkpoint management
     background_transfer_service.dart  # Background transfer handling
     desktop_notification_service.dart  # Desktop notifications
     system_tray_service.dart      # System tray management
     share_intent_service.dart     # Share intent handling
     sound_service.dart            # Notification sounds
     transfer_service/             # Transfer implementation
       transfer_service_impl.dart  # Main transfer logic
       encryption_handler.dart     # Encryption for transfers
       trusted_devices_handler.dart  # Trusted device management
       http_response_helper.dart   # HTTP response utilities
       request_router.dart         # HTTP request routing
       models.dart                 # Transfer service models
     parallel/                     # Parallel transfer
       parallel_transfer_service.dart  # Multi-connection sender
       parallel_receiver_handler.dart  # Multi-connection receiver
       parallel_config.dart        # Configuration
       chunk_writer_service.dart   # Chunk writing
     web_share/                    # Browser sharing
       web_share_service.dart      # Main service
       servers/
         share_server.dart         # HTTP server for downloads
         receive_server.dart       # HTTP server for uploads
       models/
         received_file.dart        # Received file model
         pending_files_manager.dart  # Pending files management
       templates/
         share_page_template.dart  # HTML for download page
         receive_page_template.dart  # HTML for upload page
         parallel_download.js       # JS for parallel downloads
         parallel_upload.js         # JS for parallel uploads
         encrypted_download.js      # JS for encrypted downloads
       utils/
         file_type_utils.dart      # MIME type detection
         multipart_parser.dart     # Multipart form parsing
         network_utils.dart        # IP address utilities
         platform_paths.dart       # Platform-specific paths
 ui/
   animations/              # UI animations
     fade_animation.dart
     pulse_animation.dart
     scale_animation.dart
     slide_animation.dart
     staggered_list_animation.dart
     status_animations.dart
     transfer_animations.dart
     page_transitions.dart
   screens/                 # App screens
     home_screen.dart           # Main device list
     file_picker_screen.dart    # File selection
     browser_share_screen.dart  # Browser share mode
     browser_receive_screen.dart  # Browser receive mode
     transfer_progress_screen.dart  # Transfer progress
     history_screen.dart        # Transfer history
     settings_screen.dart       # App settings
     onboarding_screen.dart     # First-time tutorial
     permissions_onboarding_screen.dart  # Permission requests
     quick_send_screen.dart     # Direct send from arguments
     main_navigation_screen.dart  # Bottom navigation
   theme/                   # App theme
     app_theme.dart
   widgets/                 # Reusable widgets
     device_card.dart           # Device list item
     transfer_request_sheet.dart  # Incoming transfer dialog
     transfer_progress_widget.dart  # Progress indicator
     file_preview_widgets.dart  # File thumbnails
     full_screen_image_viewer.dart  # Image zoom viewer
     drop_zone_widget.dart      # Drag and drop area
     share_intent_dialog.dart   # Share intent handler
     device_nickname_dialog.dart  # Nickname editor
     file_summary_widget.dart   # File list summary
     shimmer_loading.dart       # Loading placeholders
     status_animations.dart     # Status indicators

android/
 app/src/main/
   AndroidManifest.xml         # Permissions, activities, activity-aliases
   kotlin/com/syndro/app/
     MainActivity.kt           # Flutter activity, method channels
     TransferService.kt        # Foreground service for notifications

installer/
 linux/
   syndro.desktop              # Desktop entry
   syndro-nautilus.py          # Nautilus context menu
   syndro-dolphin.desktop      # Dolphin context menu
   install-context-menu.sh     # Install script
   uninstall-context-menu.sh   # Uninstall script
 windows/
   install-context-menu.bat    # Windows context menu install
   uninstall-context-menu.bat  # Windows context menu uninstall
   add_context_menu.reg        # Registry entries
   remove_context_menu.reg     # Registry removal
```

---

## Platform-Specific Features

### Android Implementation

#### Share Sheet Integration
- **Activity-alias**: Two aliases in AndroidManifest.xml
  - `.ShareAppToApp`: Shows as "App to App" in share sheet
  - `.ShareBrowser`: Shows as "Browser Share" in share sheet
- **Intent Filters**: Handles SEND and SEND_MULTIPLE for all MIME types

#### Foreground Service
- **TransferService.kt**: Foreground service for background transfers
- **Notification**: Shows progress, file name, speed, time remaining
- **Actions**: Accept/Reject buttons in notification

#### Method Channels
- `com.syndro.app/device_info`: Get device name
- `com.syndro.app/transfer`: Start/update/stop background transfer
- `com.syndro.app/transfer_events`: Receive events from notification actions
- `com.syndro.app/share_intent`: Handle incoming share intents
- `com.syndro.app/sound`: Play notification sounds

### Desktop Implementation

#### Window Management
- **window_manager**: Window size (1200x800), minimum size (800x600)
- **system_tray**: Tray icon with menu (Show, Settings, Quit)
- **launch_at_startup**: Auto-start option

#### Context Menu Integration
- **Windows**: Registry entries for right-click menu
- **Linux Nautilus**: Python script for Nautilus extension
- **Linux Dolphin**: .desktop file for Dolphin service menu

#### Desktop Notifications
- **local_notifier**: Rich notifications with images
- **DesktopNotificationService**: Cross-platform notification handling

---

## Security Implementation

### Encryption Flow

1. **Key Generation**: Each device generates X25519 key pair
2. **Key Exchange**: Public keys exchanged during transfer handshake
3. **Shared Secret**: ECDH derives shared secret
4. **Session Key**: Shared secret used as AES-256-GCM key
5. **Chunk Encryption**: Each chunk encrypted with unique nonce
6. **Nonce Tracking**: Prevents replay attacks

### Encryption Service Features

- **AES-256-GCM**: Industry standard, hardware accelerated
- **X25519**: Same as Signal, WhatsApp
- **Streaming Encryption**: Memory-efficient for large files
- **Nonce Management**: Bounded cache (10,000 nonces) to prevent memory leak
- **Key Rotation**: Recommended after 2^32 nonces

### Trusted Devices

- **Storage**: Flutter Secure Storage
- **Format**: JSON map of device IDs
- **Auto-Accept**: Skip approval for trusted devices

---

## Transfer Protocol Details

### Discovery Phase

1. Device broadcasts UDP packet on port 8771
2. Packet contains: device ID, name, platform, IP, port
3. Other devices receive and add to discovered list
4. Stale devices removed after 30 seconds

### Connection Phase

1. Sender initiates HTTP POST to receiver's IP:port
2. Key exchange via request/response headers
3. Transfer request sent with file metadata
4. Receiver accepts/rejects

### Transfer Phase

1. Files split into 1MB chunks
2. Each chunk encrypted with unique nonce
3. SHA-256 hash calculated streaming
4. Checkpoint saved every 10MB
5. Progress updates via StreamController

### Resume Phase

1. On interruption, checkpoint loaded
2. Transfer resumes from last checkpoint
3. Hash verified for integrity
4. Duplicate chunks skipped

---

## License

MIT License - See LICENSE file for details.

---

## Contributing

Contributions welcome! Please read the contributing guidelines first.

---

## Support

For issues and feature requests, please use GitHub Issues.
