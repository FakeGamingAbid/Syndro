# Syndro - Cross-Platform File Sharing App

A secure, fast, and easy-to-use file sharing application for Android, Windows, and Linux.

---

## 📱 Features

### Core File Sharing

| Feature | Description |
|---------|-------------|
| **Cross-Platform Transfer** | Share files between Android, Windows, and Linux devices |
| **Peer-to-Peer (P2P)** | Direct device-to-device transfer over local network (no internet required) |
| **Multiple Files** | Send multiple files and folders at once |
| **Large File Support** | Transfer files of any size (GBs supported) |
| **Folder Transfer** | Send entire folders with directory structure preserved |
| **Resume Transfers** | Interrupted transfers can be resumed from where they left off |

### Security & Privacy

| Feature | Description |
|---------|-------------|
| **End-to-End Encryption** | All transfers encrypted with AES-256-GCM |
| **X25519 Key Exchange** | Same encryption used by Signal and WhatsApp |
| **Trusted Devices** | Mark devices as trusted for auto-accept |
| **Transfer Approval** | Accept/receive incoming transfers manually |
| **No Cloud Storage** | Files never leave your local network |

### Android-Specific Features

| Feature | Description |
|---------|-------------|
| **Android Share Sheet Integration** | Share files directly from gallery, file manager, or any app |
| **Two Share Modes** | "App to App" for device transfer, "Browser Share" for web sharing |
| **Content URI Support** | Handles content:// URIs from other apps correctly |
| **Media Thumbnails** | Shows image/video thumbnails when sharing from gallery |
| **Background Transfer** | Continue transfers while app is in background |
| **Notification Progress** | Real-time progress in notification bar |
| **Notification Actions** | Accept/Reject transfers from notification |

### Desktop-Specific Features (Windows & Linux)

| Feature | Description |
|---------|-------------|
| **Right-Click Context Menu** | Send files directly from Windows Explorer / Linux file manager |
| **System Tray** | App runs in system tray for quick access |
| **Desktop Notifications** | Rich notifications with file thumbnails |
| **Drag & Drop** | Drag files onto app window to select |
| **Window Management** | Minimize to tray, close behavior options |

### Browser Share Mode

| Feature | Description |
|---------|-------------|
| **QR Code Sharing** | Generate QR code for instant browser access |
| **No App Required** | Receivers can download via any web browser |
| **Multiple Viewers** | Share with multiple people simultaneously |
| **Connection Tracking** | See connected viewers (IP, device type) |
| **Expiration Timer** | Auto-stop sharing after configurable time |
| **Drop Zone** | Drag & drop files directly onto web page |

### Browser Receive Mode

| Feature | Description |
|---------|-------------|
| **Receive from Browser** | Accept files uploaded from any web browser |
| **QR Code Access** | Scan QR to open upload page |
| **Drag & Drop Upload** | Drag files onto web page to upload |
| **Progress Tracking** | Real-time upload progress in browser |
| **Multiple Files** | Upload multiple files at once |

### User Interface

| Feature | Description |
|---------|-------------|
| **Device Discovery** | Automatic discovery of nearby devices |
| **Device Nicknames** | Custom names for easy device identification |
| **Transfer History** | View past transfers with details |
| **Dark Theme** | Modern dark UI theme |
| **Animations** | Smooth transitions and loading animations |
| **File Previews** | Thumbnail previews for images and videos |
| **Full-Screen Image Viewer** | View images in full screen with zoom |

---

## 🛠️ Technology Stack

### Framework & Language

| Technology | Purpose |
|------------|---------|
| **Flutter/Dart** | Cross-platform UI framework |
| **Kotlin** | Android native code (notifications, share intent) |
| **C++** | Linux native code |

### Networking

| Technology | Purpose |
|------------|---------|
| **HTTP Server** | Built-in HTTP server for file transfers |
| **UDP Broadcast** | Device discovery on local network |
| **Multicast DNS** | Service discovery |
| **WebSocket** | Real-time browser communication |

### Security

| Technology | Purpose |
|------------|---------|
| **X25519** | Key exchange algorithm |
| **AES-256-GCM** | Symmetric encryption |
| **SHA-256** | File integrity verification |
| **Flutter Secure Storage** | Secure key storage |

### Data Storage

| Technology | Purpose |
|------------|---------|
| **SQLite (sqflite)** | Local database for transfer history |
| **SharedPreferences** | App settings storage |
| **File System** | Temporary file storage |

### State Management

| Technology | Purpose |
|------------|---------|
| **Riverpod** | State management |
| **StreamController** | Event streaming |

### Platform Integration

| Technology | Purpose |
|------------|---------|
| **MethodChannel** | Flutter ↔ Native communication |
| **EventChannel** | Native → Flutter event streams |
| **Platform Channels** | Platform-specific functionality |

### UI Components

| Technology | Purpose |
|------------|---------|
| **Material Design** | UI components |
| **QR Flutter** | QR code generation |
| **Video Thumbnail** | Video preview generation |
| **File Picker** | Native file selection |
| **Path Provider** | Platform-specific paths |

---

## 📖 Usage Guide

### Installation

#### Android
1. Download APK from releases
2. Enable "Install from unknown sources" if needed
3. Install the APK

#### Windows
1. Download the Windows installer
2. Run the installer
3. Optionally install context menu integration

#### Linux
1. Download the AppImage or .deb package
2. For context menu: run `install-context-menu.sh`

### First Time Setup

1. **Grant Permissions** (Android)
   - Storage permission for file access
   - Notification permission for transfer alerts

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

## 🔧 Technical Details

### Transfer Protocol

1. **Discovery**: UDP broadcast on port 8771
2. **Connection**: HTTP on ports 8765-8770
3. **Encryption**: X25519 key exchange → AES-256-GCM
4. **Chunking**: Files split into 1MB chunks
5. **Resume**: Checkpoint saved every 10MB

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

---

## 📂 Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── database/            # SQLite database
│   ├── models/              # Data models
│   ├── providers/           # Riverpod providers
│   └── services/            # Business logic
│       ├── encryption_service.dart
│       ├── file_service.dart
│       ├── device_discovery_service.dart
│       ├── transfer_service/
│       ├── web_share/
│       └── ...
└── ui/
    ├── animations/          # UI animations
    ├── screens/             # App screens
    ├── theme/               # App theme
    └── widgets/             # Reusable widgets
```

---

## 📜 License

MIT License - See LICENSE file for details.

---

## 🤝 Contributing

Contributions welcome! Please read the contributing guidelines first.

---

## 📧 Support

For issues and feature requests, please use GitHub Issues.
