# Syndro - Cross-Platform File Sharing

<p align="center">
  <strong>A lightning-fast, privacy-first file sharing platform built with Flutter.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.16+-02569B?logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Linux-green" alt="Platforms">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License">
</p>

---

## ✨ Features

### Core Features
- 📡 **Local Network Discovery** - Automatically find devices on the same WiFi
- 📁 **Direct P2P Transfers** - No cloud, no servers, no tracking
- 🖥️ **Cross-Platform** - Android, Windows, Linux from one codebase
- 🎨 **Platform-Adaptive UI** - Native feel on every platform

### Advanced Features
- 🌐 **Browser Share Mode** - Share files with any device via web browser (no app needed!)
- 📱 **QR Code Pairing** - Quickly connect devices by scanning QR codes
- 🔒 **Trusted Devices** - Approve transfers and optionally trust devices for future transfers
- 📂 **Folder Transfers** - Send entire folders with structure preservation
- ⏸️ **Resumable Transfers** - Resume interrupted transfers with checkpoint support
- 📜 **Transfer History** - Track all your past file transfers
- 🔄 **Background Transfers** - Transfers continue even when app is in background

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.16 or higher

### Installation

1. Clone this repository
   ```bash
   git clone https://github.com/FakeGamingAbid/Syndro.git
   cd Syndro
   ```

2. Install dependencies
   ```bash
   flutter pub get
   ```

3. Run the app
   ```bash
   flutter run
   ```

### Building for Release

```bash
# Android APK
flutter build apk

# Windows
flutter build windows

# Linux
flutter build linux
```

### GitHub Actions

This project uses GitHub Actions for automated builds. Push to the repository and download artifacts from the Actions tab.

**Workflows:**
- `.github/workflows/build-android.yml` - Builds Android APK
- `.github/workflows/build-windows.yml` - Builds Windows EXE
- `.github/workflows/build-linux.yml` - Builds Linux bundle

---

## 📖 Usage

### Standard Transfer (App to App)
1. **Connect** both devices to the same WiFi network
2. **Open** Syndro on both devices
3. **Select** the recipient device from the discovered list
4. **Pick** files or folders to send
5. **Approve** the transfer on the receiving device
6. **Done!** Files are transferred directly

### Browser Share Mode
1. **Open** Syndro and tap "Share via Browser"
2. **Select** files to share
3. **Scan** the QR code from any device's browser
4. **Download** files directly in the browser - no app needed!

---

## 🏗️ Project Structure

```
lib/
├── core/
│   ├── database/         # SQLite database for transfer history
│   ├── models/           # Data models
│   │   ├── device.dart           # Device info & platform detection
│   │   ├── transfer.dart         # Transfer items & progress
│   │   ├── transfer_checkpoint.dart  # Resumable transfer support
│   │   └── folder_structure.dart # Folder transfer support
│   ├── providers/        # Riverpod state management
│   │   ├── device_provider.dart
│   │   └── transfer_provider.dart
│   └── services/
│       ├── device_discovery_service.dart   # Network scanning & discovery
│       ├── transfer_service.dart           # Core file transfer logic
│       ├── file_service.dart               # File system operations
│       ├── checkpoint_manager.dart         # Resume interrupted transfers
│       ├── background_transfer_service.dart
│       └── web_share/                      # Browser-based sharing
│           ├── servers/          # HTTP servers for web sharing
│           ├── templates/        # HTML templates for browser UI
│           ├── models/           # Web share data models
│           └── utils/            # Utility functions
├── ui/
│   ├── screens/
│   │   ├── home_screen.dart              # Main device list & actions
│   │   ├── file_picker_screen.dart       # File/folder selection
│   │   ├── transfer_progress_screen.dart # Real-time transfer progress
│   │   ├── browser_share_screen.dart     # Share via browser
│   │   ├── browser_receive_screen.dart   # Receive via browser
│   │   ├── history_screen.dart           # Transfer history
│   │   ├── onboarding_screen.dart        # First-time setup
│   │   ├── permissions_onboarding_screen.dart
│   │   └── main_navigation_screen.dart
│   ├── widgets/          # Reusable UI components
│   ├── animations/       # Custom animations
│   └── theme/            # Dark theme with glassmorphism
└── main.dart             # App entry point
```

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.16+ |
| **State Management** | Riverpod |
| **Network Discovery** | UDP broadcast + HTTP |
| **File Transfer** | HTTP-based P2P with chunking |
| **Database** | SQLite (sqflite + sqflite_common_ffi) |
| **QR Code** | mobile_scanner + qr_flutter |
| **Secure Storage** | flutter_secure_storage |
| **Platforms** | Android 5.0+, Windows 10+, Linux |

---

## 📱 Platform Support

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
- [x] Platform-adaptive UI
- [x] Browser share/receive mode
- [x] QR code device pairing
- [x] Trusted devices system
- [x] Folder transfers with structure preservation
- [x] Resumable transfers (checkpoints)
- [x] Transfer history
- [x] Background transfers

### 🔮 Future Plans
- [ ] WebRTC for internet transfers (beyond local network)
- [ ] End-to-end encryption
- [ ] Multi-file batch progress tracking
- [ ] Transfer scheduling
- [ ] Custom save locations per transfer

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---

<p align="center">
  Made with ❤️ using Flutter
</p>
