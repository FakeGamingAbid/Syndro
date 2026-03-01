# 📱 Syndro - Cross-Platform File Sharing

<p align="center">
  <img src="assets/icon/app_icon.png" alt="Syndro Logo" width="120">
</p>

<p align="center">
  <strong>Lightning-fast, privacy-first file sharing across all your devices</strong>
</p>

<p align="center">
  Share files between Android, Windows, Linux, and macOS — no internet required, no cloud storage, complete privacy.
</p>

<p align="center">
  <a href="#-features">Features</a> •
  <a href="#-getting-started">Get Started</a> •
  <a href="#-usage">Usage</a> •
  <a href="#-technical-details">Technical</a> •
  <a href="#-contributing">Contribute</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.16+-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-green" alt="Platforms">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License">
  <img src="https://img.shields.io/badge/Encryption-AES--256--GCM-red" alt="Encryption">
</p>

---

## ✨ Highlights

- **🚀 Blazing Fast** — Parallel transfers with adaptive chunk sizing
- **🔒 End-to-End Encrypted** — AES-256-GCM with X25519 key exchange (same as Signal/WhatsApp)
- **🌐 No Internet Required** — Direct P2P transfer over local network
- **📦 Large File Support** — Transfer files of any size (GBs supported)
- **⏯️ Resume Transfers** — Interrupted? Continue from where you left off
- **📱 Multiple Share Modes** — App-to-App, Browser Share, QR Code

---

## 📋 Table of Contents

- [Features](#-features)
- [Getting Started](#-getting-started)
- [Usage](#-usage)
- [Technical Details](#-technical-details)
- [Project Structure](#-project-structure)
- [Platform-Specific Features](#-platform-specific-features)
- [Security Implementation](#-security-implementation)
- [Roadmap](#-roadmap)
- [License](#-license)

---

## 🎯 Features

### Core File Sharing

| Feature | Description |
|---------|-------------|
| **Cross-Platform Transfer** | Share files between Android, Windows, Linux, and macOS devices |
| **Peer-to-Peer (P2P)** | Direct device-to-device transfer over local network |
| **Multiple Files & Folders** | Send multiple files and entire folders at once |
| **Large File Support** | Transfer files of any size (tested with 7GB+ files) |
| **Resume Transfers** | Checkpoint system allows resuming interrupted transfers |
| **Parallel Transfer** | Multi-connection transfers for large files (>10MB) |
| **Adaptive Chunk Sizing** | Dynamically adjusts chunk size based on network speed |

### Security & Privacy

| Feature | Description |
|---------|-------------|
| **End-to-End Encryption** | All transfers encrypted with AES-256-GCM |
| **X25519 Key Exchange** | Same encryption protocol as Signal and WhatsApp |
| **Trusted Devices** | Mark devices as trusted for auto-accept |
| **Transfer Approval** | Accept/reject incoming transfers manually |
| **No Cloud Storage** | Files never leave your local network |
| **Nonce Tracking** | Prevents replay attacks with unique nonces per chunk |
| **Secure Key Storage** | Keys stored in platform secure storage |

### Android Features

| Feature | Description |
|---------|-------------|
| **Share Sheet Integration** | Share directly from gallery, file manager, or any app |
| **Two Share Modes** | "App to App" for device transfer, "Browser Share" for web |
| **Background Transfer** | Continue transfers while app is in background |
| **Notification Progress** | Real-time progress in notification bar |
| **Notification Actions** | Accept/Reject transfers from notification |
| **Android 13+ Support** | Proper handling of new media permissions |

### Desktop Features (Windows, Linux & macOS)

| Feature | Description |
|---------|-------------|
| **Right-Click Context Menu** | Send files directly from file manager |
| **System Tray** | App runs in tray for quick access |
| **Desktop Notifications** | Rich notifications with file thumbnails |
| **Drag & Drop** | Drag files onto app window to select |
| **Launch at Startup** | Option to start automatically on boot |

### macOS Features

| Feature | Description |
|---------|-------------|
| **Share Menu Integration** | Share files directly from macOS share menu |
| **Finder Integration** | Send files via right-click context menu |
| **System Tray** | App runs in menu bar for quick access |
| **Desktop Notifications** | Rich notifications with file thumbnails |
| **Drag & Drop** | Drag files onto app window to select |
| **Launch at Startup** | Option to start automatically on boot |

### Browser Share Mode

| Feature | Description |
|---------|-------------|
| **QR Code Sharing** | Generate QR code for instant browser access |
| **No App Required** | Receivers can download via any web browser |
| **Multiple Viewers** | Share with multiple people simultaneously |
| **Connection Approval** | Approve/deny connection requests from viewers |
| **Encrypted Downloads** | JavaScript-based decryption in browser |
| **Parallel Downloads** | Multi-connection downloads for large files |

### Browser Receive Mode

| Feature | Description |
|---------|-------------|
| **Receive from Browser** | Accept files uploaded from any web browser |
| **QR Code Access** | Scan QR to open upload page |
| **Drag & Drop Upload** | Drag files onto web page to upload |
| **Progress Tracking** | Real-time upload progress in browser |

### Supported File Types

| Category | Extensions |
|----------|------------|
| **Images** | jpg, jpeg, png, gif, webp, bmp, heic, heif, svg |
| **Videos** | mp4, mkv, avi, mov, wmv, flv, webm |
| **Audio** | mp3, wav, flac, aac, ogg, m4a |
| **Documents** | pdf, doc, docx, xls, xlsx, ppt, pptx, txt |
| **Archives** | zip, rar, 7z, tar, gz |
| **Android Apps** | apk, apks, apkm, xapk, aab |
| **Code** | dart, js, py, java, cpp, html, css, json, xml |

### Auto Cache Management

| Feature | Description |
|---------|-------------|
| **Post-Transfer Cleanup** | Temp files automatically deleted after successful transfer |
| **Error Cleanup** | Temp files deleted on transfer failure |
| **FilePicker Cache** | Cleared when leaving share screen |
| **Parallel Transfer Cleanup** | Chunk files deleted on completion/abort |

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.16 or higher

### Installation

```bash
# Clone the repository
git clone https://github.com/FakeGamingAbid/Syndro.git
cd Syndro

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Building for Release

```bash
# Android APK
flutter build apk

# Android App Bundle (for Play Store)
flutter build appbundle

# Windows
flutter build windows

# Linux
flutter build linux

# macOS
flutter build macos
```

### GitHub Actions CI/CD

Automated builds are available via GitHub Actions:

| Workflow | Output |
|----------|--------|
| `build-android.yml` | Android APK artifact |
| `build-windows.yml` | Windows EXE artifact |
| `build-linux.yml` | Linux bundle artifact |
| `build-macos.yml` | macOS app artifact |

---

## 📖 Usage

### Sending Files

#### Method 1: From App
1. Open Syndro
2. Tap **"Send Files"** or **"Send Photos/Videos"**
3. Select files to send
4. Choose destination device
5. Wait for acceptance (if not trusted)

#### Method 2: Android Share Sheet
1. Open any app (Gallery, File Manager, etc.)
2. Select files → Tap **"Share"**
3. Choose **"App to App"** or **"Browser Share"**

#### Method 3: Desktop Right-Click
1. Right-click on file(s) in Explorer/Nautilus/Dolphin
2. Select **"Send with Syndro"**

#### Method 4: Drag & Drop
1. Open Syndro
2. Drag files onto the app window

### Receiving Files

#### From Another Device
1. Keep Syndro open
2. When someone sends files, tap **"Accept"** or **"Reject"**
3. Files save to Downloads folder

#### From Browser
1. Tap **"Receive from Browser"**
2. Share QR code or URL with sender
3. Sender uploads files via browser

### Browser Share Mode

1. Select files → Tap **"Share via Browser"**
2. QR code and URL are generated
3. Share with recipients
4. **Approve connection requests** from viewers
5. Recipients download via browser
6. Tap **"Stop Sharing"** when done

### Managing Trusted Devices

1. After accepting a transfer, tap **"Trust Device"**
2. Trusted devices can send without approval
3. Manage in **Settings → Trusted Devices**

---

## 🔧 Technical Details

### Transfer Protocol

```
┌─────────────────────────────────────────────────────────────┐
│                     TRANSFER FLOW                           │
├─────────────────────────────────────────────────────────────┤
│  1. Discovery    UDP broadcast on port 8771                 │
│  2. Connection   HTTP on ports 8765-8770                   │
│  3. Encryption   X25519 key exchange → AES-256-GCM         │
│  4. Chunking     1MB chunks (adaptive: 256KB-8MB)          │
│  5. Integrity    SHA-256 streaming hash                     │
│  6. Resume       Checkpoint every 10MB                      │
└─────────────────────────────────────────────────────────────┘
```

### Adaptive Chunk Sizing

| Network Speed | Chunk Size |
|---------------|------------|
| Slow (<1 MB/s) | 256 KB |
| Medium (1-10 MB/s) | 1 MB |
| Fast (10-50 MB/s) | 4 MB |
| Very Fast (>50 MB/s) | 8 MB |

### Network Requirements

- **Same WiFi network** for P2P transfer
- **No internet required**
- **Firewall**: Allow ports 8765-8771

### Memory Efficiency

- **Streaming Hash**: ~1MB memory regardless of file size
- **Chunked Transfer**: Prevents memory overflow
- **Checkpoint System**: Resume without re-transferring

---

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── database/                # SQLite database
│   ├── models/                  # Data models
│   ├── providers/               # Riverpod providers
│   └── services/
│       ├── encryption_service.dart      # AES-256-GCM + X25519
│       ├── file_service.dart            # File operations
│       ├── device_discovery_service.dart # UDP discovery
│       ├── streaming_hash_service.dart  # SHA-256 streaming
│       ├── checkpoint_manager.dart      # Resume support
│       ├── transfer_service/            # Transfer logic
│       ├── parallel/                    # Parallel transfers
│       └── web_share/                   # Browser sharing
└── ui/
    ├── animations/              # UI animations
    ├── screens/                 # App screens
    ├── theme/                   # App theme
    └── widgets/                 # Reusable widgets
```

---

## 🔒 Security Implementation

### Encryption Flow

```
┌──────────────┐     ┌──────────────┐
│   Device A   │     │   Device B   │
│  (Sender)    │     │ (Receiver)   │
└──────┬───────┘     └──────┬───────┘
       │                    │
       │  1. Generate       │  1. Generate
       │     X25519 keypair │     X25519 keypair
       │                    │
       │  2. Exchange public keys
       │◄──────────────────►│
       │                    │
       │  3. ECDH shared secret
       │                    │
       │  4. AES-256-GCM encrypt
       │     each chunk with
       │     unique nonce    │
       │                    │
       │  5. Send encrypted │
       │     chunks ───────►│
       │                    │  6. Decrypt & verify
       │                    │
```

### Security Features

- **AES-256-GCM**: Industry standard authenticated encryption
- **X25519**: Curve25519 Diffie-Hellman (same as Signal)
- **Nonce Management**: Unique nonce per chunk, bounded cache
- **Key Rotation**: Recommended after 2^32 nonces

---

## 📊 Platform Support

| Platform | Status | Min Version |
|----------|--------|-------------|
| Android | ✅ Supported | Android 5.0 (API 21) |
| Windows | ✅ Supported | Windows 10 |
| Linux | ✅ Supported | Modern distros |
| iOS | ❌ Not supported | - |
| macOS | ❌ Not supported | - |
| Web | ❌ Not supported | - |

---

## 🗺️ Roadmap

### ✅ Completed

- [x] Local network device discovery
- [x] Direct P2P file transfers
- [x] Cross-platform support (Android, Windows, Linux)
- [x] Browser share/receive mode
- [x] QR code device pairing
- [x] Trusted devices system
- [x] Folder transfers with structure preservation
- [x] Resumable transfers (checkpoints)
- [x] Transfer history
- [x] Background transfers (Android)
- [x] End-to-end encryption (AES-256-GCM)
- [x] Parallel chunk transfers
- [x] Streaming hash verification
- [x] Adaptive chunk sizing
- [x] Connection approval for browser share
- [x] Android app bundle support (.apks, .apkm, .xapk)
- [x] Auto cache cleanup

### 🔮 Planned

- [ ] WebRTC for internet transfers
- [ ] Multi-file batch progress tracking
- [ ] Transfer scheduling
- [ ] Custom save locations per transfer
- [ ] iOS support

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

<p align="center">
  Made with ❤️ using <a href="https://flutter.dev">Flutter</a>
</p>

<p align="center">
  <a href="https://github.com/FakeGamingAbid/Syndro/stargazers">
    <img src="https://img.shields.io/github/stars/FakeGamingAbid/Syndro?style=social" alt="Stars">
  </a>
  <a href="https://github.com/FakeGamingAbid/Syndro/network/members">
    <img src="https://img.shields.io/github/forks/FakeGamingAbid/Syndro?style=social" alt="Forks">
  </a>
</p>
