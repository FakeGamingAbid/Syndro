# Syndro - Cross-Platform File Sharing

A lightning-fast, privacy-first file sharing platform built with Flutter.

## Features (Phase 1)

✅ **Local Network Discovery** - Automatically find devices on the same WiFi  
✅ **Direct P2P Transfers** - No cloud, no servers, no tracking  
✅ **Cross-Platform** - Android, Windows, Linux from one codebase  
✅ **Platform-Adaptive UI** - Native feel on every platform  

## Development Setup

### Building Locally (Requires Flutter SDK)

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. Clone this repository
3. Run `flutter pub get`
4. Build for your platform:
   - Android: `flutter build apk`
   - Windows: `flutter build windows`
   - Linux: `flutter build linux`

### Building with GitHub Actions

This project uses GitHub Actions for automated builds. Simply push to the repository and download artifacts from the Actions tab.

**Workflows:**
- `.github/workflows/build-android.yml` - Builds Android APK
- `.github/workflows/build-windows.yml` - Builds Windows EXE
- `.github/workflows/build-linux.yml` - Builds Linux bundle

## Usage

1. **Connect** both devices to the same WiFi network
2. **Open** Syndro on both devices
3. **Send** files from one device by selecting the recipient
4. **Receive** automatically - transfers start immediately

## Project Structure

```
lib/
├── core/
│   ├── models/          # Data models (Device, Transfer, etc.)
│   ├── providers/       # Riverpod state management
│   └── services/        # Business logic (discovery, transfer, file)
├── ui/
│   ├── screens/         # App screens
│   ├── widgets/         # Reusable widgets
│   └── theme/           # Theme and styling
└── main.dart            # App entry point
```

## Tech Stack

- **Framework**: Flutter 3.16+
- **State Management**: Riverpod
- **Network Discovery**: mDNS/UDP broadcast
- **File Transfer**: HTTP-based P2P
- **Platforms**: Android 5.0+, Windows 10+, Linux

## License

MIT License - See LICENSE file for details

## Roadmap

**Phase 2** (Coming Soon):
- Folder transfers with structure preservation
- WebRTC for internet transfers
- Browser fallback mode
- Background transfers
- Transfer history
- Optional encryption
