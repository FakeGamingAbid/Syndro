# Syndro UI Documentation

## Theme & Design Language

### Color Palette (from `lib/ui/theme/app_theme.dart`)

**Primary Colors (Logo Gradient)**
| Name | Hex | Usage |
|------|-----|-------|
| `primaryColor` | `#7B5EF2` | Purple — primary actions, selected states, buttons, indicators |
| `secondaryColor` | `#5B8DEF` | Blue — secondary actions, logo gradient start |
| `accentColor` | `#06B6D4` | Cyan — highlights, speed indicators |

**Background Colors**
| Name | Hex | Usage |
|------|-----|-------|
| `backgroundColor` | `#0A0A0F` | Near-black — scaffold background |
| `surfaceColor` | `#141420` | Dark purple-gray — cards, sheets, navigation bar background |
| `cardColor` | `#1E1E2E` | Card background, dividers, unselected nav items |

**Status Colors**
| Name | Hex | Usage |
|------|-----|-------|
| `successColor` | `#22C55E` | Green — online indicators, completed transfers, save actions |
| `errorColor` | `#EF4444` | Red — failed transfers, delete actions, cancel buttons |
| `warningColor` | `#F59E0B` | Amber — pending states, large file warnings |

**Text Colors**
| Name | Hex | Usage |
|------|-----|-------|
| `textPrimary` | `#F8FAFC` | White — headings, primary labels |
| `textSecondary` | `#CBD5E1` | Light gray — body text, secondary labels |
| `textTertiary` | `#94A3B8` | Muted gray — captions, hints, timestamps |

**Other**
| Name | Hex | Usage |
|------|-----|-------|
| `borderColor` | `#2D2D3D` | Subtle borders on cards and containers |

### Typography Scale

| Text Theme Key | Size | Weight | Color | Usage |
|---------------|------|--------|-------|-------|
| `displayLarge` | 32px | Bold | `textPrimary` | Screen titles |
| `displayMedium` | 28px | Bold | `textPrimary` | Section headers |
| `displaySmall` | 24px | w600 | `textPrimary` | Card headings |
| `headlineMedium` | 20px | w600 | `textPrimary` | AppBar titles, device names |
| `titleLarge` | 18px | w600 | `textPrimary` | "Nearby Devices", section labels |
| `titleMedium` | 16px | w500 | `textPrimary` | List item titles, button labels |
| `bodyLarge` | 16px | Regular | `textSecondary` | Descriptions |
| `bodyMedium` | 14px | Regular | `textSecondary` | Body text, subtitles |
| `bodySmall` | 12px | Regular | `textTertiary` | Captions, timestamps, badges |

### Border Radius Values

| Context | Radius |
|---------|--------|
| Cards | `16px` (`BorderRadius.circular(16)`) |
| Elevated/Outlined buttons | `12px` |
| Dialogs | `20px` |
| Bottom sheets | `24px` (top corners only) |
| Chips | `8px` |
| Navigation items (mobile) | `24px` |
| FABs / Circular buttons | `32px` (half of 64px height) |
| Onboarding icon containers | `32px` outer, `20px` inner |
| Permission list container | `20px` |
| QR code card | `24px` |
| Input fields | `12px` |
| Snackbar | `12px` |

### Glassmorphism & Visual Effects

- **Glassmorphism**: `AppTheme.glassmorphicDecoration()` — White background at 10% opacity, 1px white border at 10% opacity, black box shadow at 20% opacity with configurable blur (default 10px) and offset (0, 4)
- **Background Gradient**: Three-stop linear gradient from `#0A0A0F` (top-left) → `#141420` → `#1E1E2E` (bottom-right)
- **Logo Gradient**: Linear gradient from `#5B8DEF` (blue, top-left) → `#7B5EF2` (purple, bottom-right)
- **Primary Gradient**: Same as logo gradient, used for buttons
- **Gradient Shader**: Used for gradient text effects via `ShaderMask` — applies logo gradient to text rendering
- **Card Shadows**: Every card uses layered `BoxShadow` with `primaryColor` at 8-15% opacity, blur 10-20px, offset (0, 4-8)
- **Selected Card Glow**: Selected device cards have `primaryColor` shadow at 25% opacity, blur 20px, offset (0, 8)
- **Navigation Bar**: Floating bar with gradient surface color (95% → 85% opacity), 30px blur purple glow shadow, 1.5px purple border at 20% opacity

### Dark/Light Mode

- **Dark Theme** (primary): Full implementation with `Brightness.dark`, Material 3 enabled. Uses `ColorScheme.dark` with primary/secondary/surface/error.
- **Light Theme**: Partial implementation. Scaffold background `#FFFFFF`, surface `#F8FAFC`, card color `#F8FAFC`, text colors inverted to dark (`#0F172A` for primary, `#475569` for body). AppBar has white background with dark icons/text. Only basic text theme defined.
- The app defaults to dark mode. Light theme is defined but the navigation between modes is not exposed in the settings screen UI.

---

## Navigation Structure

### Mobile (Android)

**Floating Bottom Navigation Bar** — positioned at bottom center, 24px from bottom edge.

- Container: 68px height, horizontal padding 12px, vertical padding 8px
- Background: Gradient from `surfaceColor` 95% opacity → 85% opacity
- Border radius: 34px (pill shape)
- Shadow: `primaryColor` at 15% opacity, blur 30px, offset (0, 15)
- Border: 1.5px `primaryColor` at 20% opacity

**Navigation Items (3):**

| Index | Unselected Icon | Selected Icon | Label |
|-------|----------------|---------------|-------|
| 0 | `Icons.devices_outlined` | `Icons.devices` | Devices |
| 1 | `Icons.history_outlined` | `Icons.history` | History |
| 2 | `Icons.settings_outlined` | `Icons.settings` | Settings |

- **Unselected**: `textSecondary` color, 26px icon
- **Selected**: `primaryColor` icon, gradient background (`primaryColor` 20% → 10%), border at 40% opacity, purple glow shadow. Label shown: 15px, w700, `primaryColor`, letterSpacing 0.3
- **Tap behavior**: Instant state change (no animation), `GestureDetector` with `HitTestBehavior.opaque`
- **Layout**: Row with 8px spacing between items

### Desktop (Windows/Linux)

**Navigation Rail** — left side, extended mode, 200px minimum width.

- Background: `surfaceColor`, transparent inside widget
- Right border: 1px `primaryColor` at 10% opacity
- Selected indicator: `primaryColor` at 20% opacity
- Selected icons: `primaryColor`, 24px
- Unselected icons: `textTertiary`, 24px
- Selected labels: `primaryColor`, w600
- Unselected labels: `textTertiary`

**Rail Destinations (3):**

| Index | Unselected Icon | Selected Icon | Label |
|-------|----------------|---------------|-------|
| 0 | `Icons.devices_outlined` | `Icons.devices` | Devices |
| 1 | `Icons.history_outlined` | `Icons.history` | History |
| 2 | `Icons.settings_outlined` | `Icons.settings` | Settings |

**Leading (Logo):**
- 12px padding container with logo gradient background, 14px border radius
- Share icon: 26px, white, with purple glow shadow (blur 10px)
- "Syndro" text: `ShaderMask` with logo gradient, 20px, bold, white base color
- 14px spacing between logo icon and text

**Vertical Divider**: 1px wide, vertical linear gradient from `primaryColor` 10% → 30% → 10%

### ASCII Flow Diagram

```
                    ┌─────────────────┐
                    │ OnboardingScreen│
                    │  (3 pages)      │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │ Platform.isAndroid?          │
              │ YES                          │ NO
              ▼                              ▼
  ┌───────────────────────┐    ┌─────────────────────────┐
  │PermissionsOnboarding  │    │   MainNavigationScreen   │
  │  Screen               │    │  ┌───────────────────┐  │
  └───────────┬───────────┘    │  │  HomeScreen (0)   │  │
              │                │  ├───────────────────┤  │
              ▼                │  │  HistoryScreen (1) │  │
  ┌─────────────────────────┐ │  ├───────────────────┤  │
  │   MainNavigationScreen  │ │  │  SettingsScreen (2)│  │
  │  ┌───────────────────┐  │ │  └───────────────────┘  │
  │  │  HomeScreen (0)   │  │ └─────────────────────────┘
  │  ├───────────────────┤  │
  │  │  HistoryScreen (1) │  │
  │  ├───────────────────┤  │
  │  │  SettingsScreen (2)│  │
  │  └───────────────────┘  │
  └────────────┬────────────┘
               │
    ┌──────────┼──────────────────────────────┐
    │          │                              │
    ▼          ▼                              ▼
┌────────┐ ┌──────────────┐  ┌──────────────────────────────┐
│FilePick│ │BrowserShare  │  │    BrowserReceiveScreen       │
│erScreen│ │Screen        │  │  (QR code to receive files)   │
└───┬────┘ └──────────────┘  └──────────────────────────────┘
    │
    ├────────────────────────┐
    │                        │
    ▼                        ▼
┌─────────────────┐  ┌──────────────────────────┐
│TransferProgress │  │MultiTransferProgress      │
│Screen           │  │Screen                     │
└─────────────────┘  └──────────────────────────┘
```

**Entry Points:**
- App start → `OnboardingScreen` (if first launch) or `MainNavigationScreen`
- Onboarding → Permissions (Android only) → Main
- Home → Tap device → FilePickerScreen
- Home → Browser Share FAB → Bottom sheet → BrowserShareScreen / BrowserReceiveScreen
- FilePicker → Send → TransferProgressScreen or MultiTransferProgressScreen
- Right-click send (desktop) → QuickSendScreen → FilePickerScreen

---

## Screens

### OnboardingScreen
- **File**: `lib/ui/screens/onboarding_screen.dart`
- **Route/entry**: First app launch (checked via `SharedPreferences` key `onboarding_complete`)
- **Mobile layout**: Full-width PageView with 3 pages, centered content, bottom button
- **Desktop layout**: Constrained to max 450px width, centered on screen
- **Key UI elements**:
  - **Skip button**: Top-right, `TextButton`, `textTertiary` color, 14px, w500, label "Skip"
  - **Page content** (3 pages):
    - Page 1: `Icons.wifi_rounded`, title "CONNECT", `primaryColor` (#7B5EF2)
    - Page 2: `Icons.swap_horiz_rounded`, title "APP TO APP", `secondaryColor` (#5B8DEF)
    - Page 3: `Icons.language_rounded`, title "BROWSER SHARE", `accentColor` (#06B6D4)
  - **Icon container**: 140x140px, gradient background (iconColor 25% → 10%), 32px border radius, 2px border at 40%, shadow blur 30px offset (0, 15). Inner container: 16px margin, 20px border radius. Icon: 64px
  - **Title**: 26px, w700, `ShaderMask` with gradient text (iconColor → 70% opacity), letterSpacing 1.5
  - **Description**: 16px, `textSecondary`, textAlign center, lineHeight 1.6, horizontal padding 16px
  - **Decorative bar**: 80x4px, gradient from iconColor 30% → 80% → 30%, 2px border radius
  - **Page indicators**: Row of animated containers. Active: 24x8px, `primaryColor`, 4px border radius. Inactive: 8x8px, `cardColor`. 4px horizontal margin each. Animation: 300ms
  - **Next/Start button**: 52px height, 180px width on desktop / full-width on mobile. `primaryColor` background, white text, 16px w600, 12px border radius. Label: "NEXT" or "GET STARTED". Loading state: 20x20px white `CircularProgressIndicator`
- **User interactions**: Swipe between pages, tap Next/Get Started, tap Skip
- **Special effects**: Page transition with `Curves.easeInOut`, 300ms. Haptic feedback (`HapticFeedback.lightImpact`) on tap. `AnimatedContainer` for page indicators.

### PermissionsOnboardingScreen
- **File**: `lib/ui/screens/permissions_onboarding_screen.dart`
- **Route/entry**: Android only — reached after OnboardingScreen completes
- **Mobile layout**: Full-width, single-page layout
- **Desktop layout**: Constrained to 450px width
- **Key UI elements**:
  - **Skip button**: Same as OnboardingScreen
  - **Icon container**: 140x140px, `Icons.security_rounded`, `primaryColor`, same gradient treatment as OnboardingScreen
  - **Title**: "PERMISSIONS", 26px w700, `ShaderMask` with `logoGradient`
  - **Description**: "Syndro needs a few permissions to share files seamlessly", 16px, `textSecondary`
  - **Permissions list container**: Gradient background (cardColor 90% → surfaceColor 70%), 20px border radius, 1px border at 15%, shadow blur 20px
  - **3 Permission Tiles**:
    - Storage: `Icons.folder_rounded`, `primaryColor`, "Save received files to your device"
    - WiFi Access: `Icons.wifi_rounded`, `secondaryColor`, "Discover devices on local network"
    - Notifications: `Icons.notifications_rounded`, `accentColor`, "Show transfer progress & requests"
  - **Tile layout**: 48x48px icon container (14px border radius, gradient background), 16px spacing, title 16px w600, description 13px `textSecondary`
  - **Status indicator** (Android only): 28x28px circle. Granted: green gradient background, green border, check icon. Ungranted: surface color, gray border, dash icon. AnimatedContainer 300ms
  - **Dividers**: Between tiles, 1px, `primaryColor` at 10% opacity, indent 70px from start
  - **Action button**: "GRANT PERMISSIONS" or "GET STARTED", 52px height, full-width on mobile / 220px on desktop
  - **Missing permissions text**: 13px, `textTertiary`, shown below button when permissions missing
  - **Decorative bar**: 60x4px, same gradient as OnboardingScreen
- **User interactions**: Tap Skip, tap Grant Permissions, tap Continue (if all granted), Open Settings if denied
- **Special effects**: `AnimatedContainer` 300ms for permission status indicator transitions

### MainNavigationScreen
- **File**: `lib/ui/screens/main_navigation_screen.dart`
- **Route/entry**: Root screen after onboarding/permissions
- **Mobile layout**: Scaffold with Stack — main content + floating bottom nav
- **Desktop layout**: Scaffold with Row — NavigationRail + vertical divider + Expanded content
- **Key UI elements**:
  - **Mobile floating nav bar**: Described in Navigation Structure section above
  - **Desktop rail**: Described in Navigation Structure section above
- **User interactions**: Tap nav items to switch between Home/History/Settings
- **Special effects**: None beyond standard navigation transitions

### HomeScreen
- **File**: `lib/ui/screens/home_screen.dart`
- **Route/entry**: Index 0 in MainNavigationScreen
- **Mobile layout**: AppBar + column with device card + "Nearby Devices" header + device list + FABs. Bottom padding 120px to clear floating nav bar.
- **Desktop layout**: Same content, no bottom padding needed (no floating nav)
- **Key UI elements**:
  - **AppBar**: Background `backgroundColor`, elevation 0, centered title. Title: Row with logo icon (20px, white, logo gradient background, 8px border radius) + "Syndro" text (20px, w600, `textPrimary`)
  - **Current Device Card**: Container with gradient (cardColor 80% → surfaceColor 60%), 20px border radius, 1px border at 20%, shadow blur 20px. Contains:
    - Logo icon: 28px, white, logo gradient background, 16px border radius, purple glow
    - "This Device" label: `bodySmall`, `textTertiary`
    - Online badge: 6px green dot + "Online" text, green at 15% background, 6px border radius
    - Device name: `titleLarge`, w700
    - IP address: `Icons.wifi_rounded` 14px + IP text, `textSecondary`, `bodySmall`
  - **"Nearby Devices" header**: 4px wide vertical gradient bar + "Nearby Devices" text (`titleLarge`) + device count badge (primaryColor pill, white text, 14px bold)
  - **Device count badge states**: Data: purple pill with count. Loading: gray pill with "...". Error: red pill with "!"
  - **Refreshing indicator**: 12px `CircularProgressIndicator` + "Scanning..." text, `textTertiary`, 12px
  - **Device list**: `ListView.builder`, horizontal padding 16px, item spacing 12px
  - **Empty state**: `Icons.devices` 64px `textTertiary` + "No devices found" title + troubleshooting text (WiFi, VPN, firewall ports) + "Scan Again" `OutlinedButton`
  - **Loading state**: `Icons.devices` 64px + "Scanning for devices..." + `CircularProgressIndicator`
  - **Error state**: `Icons.error_outline` 64px `errorColor` + "Error discovering devices" + error text + "Retry" `ElevatedButton`
  - **Browser Share FAB**: Bottom-right, 64x64px circle, `surfaceColor` background, `Icons.language` 30px `primaryColor`, 1.5px `cardColor` border, shadow blur 20px
  - **Send Files FAB** (single device selected): 56px height, auto width, row with `Icons.send` 24px + "Send Files" 16px w600, `surfaceColor` background, 28px border radius
  - **Multi-select Send FAB**: Same shape but with logo gradient background, white text "Send to N"
  - **Multi-select Cancel FAB**: 56x56px circle, `surfaceColor`, `Icons.close` 24px `errorColor`, red border at 50%
  - **Transfer Request Bottom Sheet**: `_TransferRequestSheetContent` — 24px padding, `cardColor` background, 24px top border radius. Handle bar: 40x4px, `textTertiary`. Icon: 64x64px container, `primaryColor` at 20%, `Icons.file_download_rounded` 32px. "Incoming Transfer" 20px bold. Sender name 16px `textSecondary`. File count/size 14px `textTertiary`. Buttons: REJECT (outlined, `errorColor`), ACCEPT (elevated, `successColor`), both 12px border radius, vertical padding 16
- **User interactions**: Tap device card (select), long press (multi-select), tap Browser Share FAB, tap Send Files, pull to refresh, accept/reject transfer requests
- **Special effects**: `RefreshIndicator` for pull-to-refresh. Haptic feedback on interactions.

### HistoryScreen
- **File**: `lib/ui/screens/history_screen.dart`
- **Route/entry**: Index 1 in MainNavigationScreen
- **Mobile/Desktop layout**: Same layout — AppBar + statistics card + history list
- **Key UI elements**:
  - **AppBar**: "Transfer History" title with `Icons.history` in logo gradient container. Clear All button: `Icons.delete_sweep` in `errorColor` at 15% background
  - **Statistics Card**: Gradient (cardColor 90% → surfaceColor 70%), 20px border radius, 20px padding, border at 20%, shadow blur 20px. Contains 3 stat items in a Row:
    - Total: `Icons.swap_horiz`, value (bold titleLarge)
    - Completed: `Icons.check_circle`, green, value
    - Data: `Icons.data_usage`, formatted byte value
    - Each stat: 48px icon container (12px padding, gradient background, 14px border radius), 12px spacing, value (titleLarge bold), label (bodyMedium, `textTertiary`)
  - **History list**: `ListView.builder`, horizontal padding 16px, item spacing 12px
  - **Transfer item card**: Gradient (cardColor 90% → surfaceColor 70%), 16px border radius, status-colored border at 20%. Contains:
    - Status icon: 48x48px gradient container matching status color. Icons: completed=`check_circle`, failed=`error`, cancelled=`cancel`, other=`sync`
    - Receiver name: `titleMedium` w600
    - File count badge: `surfaceColor` at 50% background, 6px border radius, folder/drive_file icon 12px + "N file(s)" text
    - Total size: `primaryColor`, w600
    - Timestamp: `Icons.access_time_rounded` 12px + formatted time, `textTertiary`
    - Chevron right icon in surface container
  - **Empty state**: `Icons.history` 64px + "No transfer history" + "Your completed transfers will appear here"
  - **Dismiss swipe**: Red background with delete icon (end-to-start swipe)
- **User interactions**: Swipe to delete transfer, tap Clear All, tap history item
- **Special effects**: `Dismissible` with red background for swipe-to-delete

### SettingsScreen
- **File**: `lib/ui/screens/settings_screen.dart`
- **Route/entry**: Index 2 in MainNavigationScreen
- **Mobile/Desktop layout**: Same layout — AppBar + scrollable ListView with sections
- **Key UI elements**:
  - **AppBar**: "Settings" title with `Icons.settings` in logo gradient container
  - **Device Section**:
    - Section header: "Device", `titleSmall`, w600, `primaryColor`
    - Card container: Same gradient treatment, 20px border radius
    - **Device Name tile**: `Icons.devices_rounded` at 22px, `primaryColor`. Shows name + "Custom" badge (logo gradient, 10px white text) if nickname set. Edit button: `Icons.edit_rounded` 18px in surface container
    - **IP Address tile**: `Icons.wifi_rounded`, `secondaryColor`. Shows IP. Copy button: `Icons.copy_rounded` 18px
    - **Auto-accept toggle**: `SwitchListTile` with `Icons.check_circle_outline` at 24px, `successColor`. Title: "Auto-accept from trusted devices". Subtitle: "Automatically accept transfers from devices you trust", 12px
    - Dividers: 1px, indent 60px
  - **About Section**:
    - Section header: "About"
    - Version tile: `Icons.info_outline`, shows version string
    - Syndro tile: `Icons.share`, "Fast & secure file sharing"
  - **Developer Credit**: "Made by FakeAbid" (FakeAbid in `primaryColor` w600) + "Built with Flutter" badge (logo gradient, 13px white, heart icon)
  - **Edit Device Name Dialog**: AlertDialog with `surfaceColor`, 20px border radius. Title row: edit icon in `primaryColor` container + "Edit Device Name". TextField: 30 maxLength, input formatters to deny special chars. Buttons: Reset, Cancel, Save
- **User interactions**: Tap to edit device name, toggle auto-accept, copy IP, tap version
- **Special effects**: None

### FilePickerScreen
- **File**: `lib/ui/screens/file_picker_screen.dart`
- **Route/entry**: From HomeScreen — tap device card then Send Files, or from QuickSendScreen
- **Mobile layout**: AppBar + recipient card + file picker/list + bottom action bar
- **Desktop layout**: Same + DropTarget wrapper for drag-and-drop
- **Key UI elements**:
  - **AppBar**: "Select Files" title, Clear All button (`Icons.clear_all`)
  - **Recipient Info Card**: `_AnimatedCard` with 100ms delay. Gradient (cardColor 90% → surfaceColor 70%), 20px border radius, 1.5px border at 20%. Shows:
    - Device icon: `_AnimatedIcon` (200ms delay, elastic scale) in logo gradient container, 32px icon
    - "Sending to" label, device name (titleLarge w700), IP address
    - Online badge: green dot (8px) with glow + "Online" text, 12px
  - **Empty State with Drop Zone**: `_AnimatedEmptyStateWithDrop`
    - Animated folder icon: `TweenAnimationBuilder` with elastic curve, 800ms. Icon: `Icons.folder_open_rounded` 64px or `Icons.file_download_rounded` (when dragging)
    - "No files selected" / "Drop files here!" title
    - Subtitle: "Drag & drop files here, or use the buttons below" (desktop) or "Select files or folders to send"
    - Three action buttons (animated, staggered):
      - "Select Files": `Icons.insert_drive_file_rounded`, primary
      - "Select Media": `Icons.photo_library_rounded`, outlined
      - "Select Folder": `Icons.folder_rounded`, outlined
    - Drag overlay: `primaryColor` at 10% background, 3px `primaryColor` border, 24px border radius
  - **File list header**: "N file(s)" + total size badge (primaryColor at 20%, 12px) + "Add More" text button
  - **File list tiles**: `_AnimatedListItem` (staggered 50ms per item). Each tile:
    - Container: gradient, 16px border radius, 1px border at 10%
    - File preview: `FilePreviewWidget` in gradient container (color based on file type)
    - File name: `titleSmall` w600
    - File type badge: colored background at 15%, 6px border radius, 10px uppercase text
    - File size: `textTertiary`
    - Remove button: `Icons.close` 20px in `errorColor` at 10% background
    - Uses `Hero` tag `file_preview_{path}`
  - **Bottom action bar**: `_AnimatedCard` (200ms delay, slides up). `cardColor` background, 24px top border radius. Shows "Total Size" label + value + "Send N file(s)" `ElevatedButton` (or loading spinner)
  - **Desktop drag overlay**: When files being dragged over list, shows purple-tinted overlay with `Icons.add_rounded` 48px + "Drop to add more files" text
- **User interactions**: Tap file buttons, drag-and-drop (desktop), tap files for details, remove files, clear all, send
- **Special effects**: Staggered list animations (50ms per item). `_AnimatedCard` fade+slide. `_AnimatedIcon` elastic scale. `_AnimatedButton` scale+fade with stagger. `_AnimatedSendButton` with loading state transition. `FadeThroughTransition` when navigating to transfer progress.

### BrowserShareScreen
- **File**: `lib/ui/screens/browser_share_screen.dart`
- **Route/entry**: From HomeScreen → Browser Share bottom sheet → "Share Media" or "Send Files"
- **Mobile/Desktop layout**: Same — AppBar + scrollable content
- **Key UI elements**:
  - **AppBar**: "Share Media" or "Share via Browser" depending on mode. Actions: viewer count badge (clickable), Copy Link button
  - **Viewer count badge**: Green pill when connected (green background at 20%, green border, "N" count + chevron). Gray when no connections
  - **QR Code Card**: Gradient (surfaceColor 90% → cardColor 70%), 24px border radius, accent-colored border at 30%. Contains:
    - Connection status banner: Green gradient when connected, "N people connected" with pulsing green dot (10px with glow)
    - QR code: 200x200px, white background, 20px border radius, shadow blur 25px. Eye style: square, `#7B5EF2`. Data modules: square, `#1a1a2e`
    - "Scan to download files/media" title: `ShaderMask` with accent gradient, 18px w700
    - "No app needed on the other device" subtitle
    - URL display bar: gradient (cardColor 90% → surfaceColor 70%), 14px border radius. Link icon + monospace URL + copy button
  - **File count section**: Row with folder icon + "Sharing N files" + total size
  - **File list**: Surface background, 16px border radius. Each item:
    - Image files: Thumbnail preview (56x56, 10px border radius) or file type icon
    - Video files: Video icon + play circle overlay
    - Other files: Type-colored icon (56x56, 10px border radius)
    - File name, type badge (uppercase, 10px, colored), size
    - Remove button: `Icons.close` in `errorColor` at 10%
  - **"Add More Files/Media" button**: Outlined, full-width, accent-colored
  - **Timer notice**: `Icons.timer_outlined` 16px + "Link active while this screen is open", 12px `textTertiary`
  - **"Stop Sharing" button**: Outlined, `errorColor`, full-width
  - **File type colors**: Image=#F472B6 (pink), Video=#FB923C (orange), Audio=#A78BFA (purple), Document=#60A5FA (blue), Spreadsheet=#34D399 (green), Presentation=#FBBF24 (yellow), Archive=#F87171 (red), Code=#2DD4BF (cyan), APK=#A3E635 (lime), Executable=#818CF8 (indigo)
  - **Connection confirmation dialog**: AlertDialog with `_accentColor` border. Shows device OS (parsed from user agent), IP address. Approve/Deny buttons
  - **Viewers dialog**: Lists connected clients with OS icon (Android/iPhone/Windows/macOS/Linux), IP address in monospace
- **User interactions**: Copy link, add more files, remove files, stop sharing, approve/deny connections, view connected clients
- **Special effects**: None significant

### BrowserReceiveScreen
- **File**: `lib/ui/screens/browser_receive_screen.dart`
- **Route/entry**: From HomeScreen → Browser Share bottom sheet → "Receive Files"
- **Mobile/Desktop layout**: Same
- **Key UI elements**:
  - **AppBar**: "Receive Files" title, Copy Link action button
  - **Instructions banner**: `Icons.info_outline` 16px `primaryColor` + "Open the link on any device to send files to this device", 14px
  - **Download location**: `Icons.folder` 20px + path text, 12px `textSecondary`, surface container with border
  - **QR Code Card**: Same style as BrowserShareScreen — gradient container, white QR code box, "Scan to send files" title with `ShaderMask`, URL display
  - **Pending Files Section** (appears when files received):
    - Header: `Icons.hourglass_empty` / `Icons.check_circle` + "Received N file(s)" + pending/saved count badges
    - Action buttons: "Save All" (green elevated) + "Discard All" (red outlined)
    - File list: Each item has thumbnail (48x48), name, size, status badge (PENDING/SAVING/SAVED/DISCARDED/ERROR), Save/Discard buttons
    - Status badges: PENDING=warning, SAVING=primary, SAVED=success, DISCARDED=textTertiary, ERROR=error
  - **Image gallery preview**: Full-screen overlay with PageView, pinch-to-zoom (InteractiveViewer), swipe navigation, top bar with file info, bottom bar with Save/Discard buttons for pending files
  - **"Stop Receiving" button**: Outlined, `errorColor`, full-width. Shows "Unsaved Files" dialog if pending files exist
  - **Error states**: Permission error with "Open Settings" button, generic error with "Try Again"
- **User interactions**: Copy link, save/discard individual files, save all, discard all, stop receiving, tap images for gallery preview
- **Special effects**: Fade transition for image gallery opening. InteractiveViewer for pinch-to-zoom.

### QuickSendScreen
- **File**: `lib/ui/screens/quick_send_screen.dart`
- **Route/entry**: From right-click context menu (desktop) when files are pre-selected
- **Mobile/Desktop layout**: Same
- **Key UI elements**:
  - **Header**: Logo icon (28px, white, logo gradient, 16px border radius) + "Quick Send" (`ShaderMask` gradient, 24px bold) + "Select a device to send your files" (14px `textSecondary`)
  - **File Summary Card**: Gradient container, 20px border radius, 20px padding. Shows file thumbnail (for single image/video) or gradient icon (folder/file). Name, size (`Icons.storage_rounded` 14px + formatted size). File count badge (logo gradient, 20px border radius)
  - **Device List**: "Available Devices" label (16px w600 `textSecondary`) + scanning indicator. Uses `DeviceCard` widgets. Empty state: scanning/no devices icons, "Scan Again" button
  - **Cancel button**: Outlined, full-width, `borderColor` at 50%, 12px border radius, 16px w600
- **User interactions**: Tap device to select and navigate to FilePickerScreen, tap Cancel
- **Special effects**: None

### TransferProgressScreen
- **File**: `lib/ui/screens/transfer_progress_screen.dart`
- **Route/entry**: After FilePickerScreen sends files (single device)
- **Mobile/Desktop layout**: Same
- **Key UI elements**:
  - **AppBar**: "Sending Files" / "Receiving Files" title, close button (shows confirmation dialog for active transfers)
  - **Device Card**: Gradient container, 20px border radius. Upload/download icon (32px) in gradient container. Device name (20px w700). Status badge pill (12px, colored by status: Connecting=warning, Transferring=primary, Completed=success, Failed=error, Cancelled=textTertiary)
  - **Waiting State**: Pulsing circle (`_pulseController`, 1500ms repeat) with upload/download icon 64px. "Connecting..." / "Waiting for approval..." text 20px w600. `CircularProgressIndicator`
  - **Transferring State**:
    - Current file card: File icon (24px, colored), file name (16px w500), "File N of M" (12px `textTertiary`)
    - Progress bar: `LinearProgressIndicator`, 12px height, 8px border radius, `primaryColor` value, `cardColor` track
    - Size info: "X / Y" formatted + percentage (16px bold `primaryColor`)
    - Stats row: Speed card (`Icons.speed`, accentColor, "Calculating..." for first 2s then "X/s") + Remaining time card (`Icons.timer_outlined`, secondaryColor, "Xm Xs")
    - File list: `ListView` in surface container, 16px border radius. Each item: status icon (check_circle for completed, file type for current/pending), name, size
  - **Completed State**: 80x80px green circle + `Icons.check_circle` 80px + "Transfer Complete!" (24px bold) + "N files sent/received successfully"
  - **Failed State**: 80x80px red circle + `Icons.error_outline` 80px + "Transfer Failed" + error message
  - **Cancelled State**: 80x80px gray circle + `Icons.cancel_outlined` 80px + "Transfer Cancelled"
  - **Action Button**: Completed="Done" (green), Failed/Cancelled="Close" (surface), Active="Cancel Transfer" (red outlined)
- **User interactions**: Tap close (with confirmation), cancel transfer
- **Special effects**: Pulse animation (1500ms, repeat, reverse) on waiting state icon. Speed calculation every 1 second. Auto-pop after 2 seconds on completion.

### MultiTransferProgressScreen
- **File**: `lib/ui/screens/multi_transfer_progress_screen.dart`
- **Route/entry**: After FilePickerScreen sends files to multiple devices
- **Mobile/Desktop layout**: Same
- **Key UI elements**:
  - **Header**: Logo icon (24px, logo gradient, 12px border radius) + "Sending to N devices" (titleLarge bold) + "M file(s)" subtitle + status badge
  - **Status badge**: "Sending..." (primary), "Complete" (success), "Partial" (warning), "All Failed" (error). Colored pill with icon
  - **Overall Progress**: "Overall Progress" label + percentage, `LinearProgressIndicator` 8px height. Count chips: "Completed" (green), "Failed" (red), "Remaining" (textTertiary)
  - **Transfer cards** (`_TransferProgressCard`): For each recipient:
    - Device icon (20px, colored by platform) + device name + file count
    - Status icon: colored circle with icon
    - Progress bar (6px) when active
    - Status text + bytes transferred/total
    - Error container if failed
  - **Done button**: Full-width, `primaryColor`, shown when all complete
- **User interactions**: Tap Done to dismiss
- **Special effects**: None beyond live progress updates

---

## Widgets

### DeviceCard
- **File**: `lib/ui/widgets/device_card.dart`
- **Purpose**: Reusable card displaying a discovered device with platform icon, name/nickname, IP, and online status
- **Visual description**: 20px border radius container with gradient background. Left: 60x60px platform icon container (16px border radius, platform-colored gradient). Center: device name (titleLarge w700), optional original name (11px textTertiary), platform badge (14px icon + text), IP (12px textTertiary with router icon). Right: 14px online indicator dot (green with glow when online, gray when offline) + "Online"/"Offline" text badge (10px, 8px border radius)
- **States**:
  - **Normal**: cardColor background, no border, subtle shadow
  - **Selected**: primaryColor border (2px), primaryColor at 12% background, purple glow shadow (blur 20px)
  - **Tapped**: Scales to 0.97 via `Matrix4`, 150ms `AnimatedContainer`
  - **Has nickname**: Shows edit icon badge (12px, primaryColor) next to name, original name below
- **Used in**: HomeScreen device list, QuickSendScreen device list

### DeviceNicknameDialog
- **File**: `lib/ui/widgets/device_nickname_dialog.dart`
- **Purpose**: AlertDialog for editing a device's display nickname
- **Visual description**: Standard AlertDialog with "Edit Device Name" title, original name text (bodySmall), TextField with 30 char max, word capitalization. Buttons: Reset (if nickname exists), Cancel, Save (FilledButton, disabled when no changes)
- **States**:
  - Has changes: Save button enabled
  - No changes: Save button disabled
  - Empty input: Save clears nickname
- **Used in**: DeviceCard long-press, SettingsScreen device name edit

### DropZoneWidget
- **File**: `lib/ui/widgets/drop_zone_widget.dart`
- **Purpose**: Wraps content to enable drag-and-drop file receiving on desktop platforms
- **Visual description**: Wraps child widget. When dragging: overlay with 16px margin, `primaryColor` at 10% background, 3px `primaryColor` border, 24px border radius. Center: 64px download icon in circle + "Drop files here" (24px bold) + "Release to add files for transfer" (16px textSecondary)
- **States**:
  - **Idle**: No visual change
  - **Dragging**: Overlay appears with scale animation (0.98), fade in 200ms
  - **Dropped**: Overlay disappears, files processed
- **Used in**: FilePickerScreen (desktop), general drag-and-drop areas

### EmptyDropZone
- **File**: `lib/ui/widgets/drop_zone_widget.dart`
- **Purpose**: Standalone empty-state drop zone with pick buttons
- **Visual description**: AnimatedContainer (200ms) with folder icon that pulses (1500ms, 1.0→1.05 scale). "No files selected" title + subtitle + two action buttons (Files/Folder) in primary-colored outlined containers (12px border radius)
- **States**:
  - **Idle**: Folder icon pulsing, surface background, borderColor border
  - **Dragging**: Download icon, primaryColor border (3px), primaryColor background at 10%, icon scales to 1.1
- **Used in**: As an alternative empty state in file picking scenarios

### FilePreviewWidget
- **File**: `lib/ui/widgets/file_preview_widgets.dart`
- **Purpose**: Shows file thumbnail (image/video) or type-colored icon for any file
- **Visual description**: Sized container (default 56x56) with background color from FileTypeHelper. Images: `Image.file` with cacheWidth. Videos: thumbnail (Android only via VideoThumbnail) or video_file icon + play overlay. Other types: colored icon at 50% of container size
- **States**:
  - **Image**: Photo thumbnail, rounded corners
  - **Video**: Loading spinner → thumbnail with play icon overlay (black circle at 60% opacity) OR generic video icon
  - **Other**: File type icon with colored background
  - **Error**: Falls back to type icon
- **Used in**: FilePickerScreen file list, QuickSendScreen file summary, FilePreviewCard

### LargeFilePreview
- **File**: `lib/ui/widgets/file_preview_widgets.dart`
- **Purpose**: Larger file preview for detail views (up to 300px height)
- **Visual description**: Constrained box with image/video/icon. Images: `Image.file` with `BoxFit.contain`, 16px border radius. Videos: thumbnail or video icon with play button overlay (48px play icon in black circle). Others: 150px tall container with 64px icon + extension text
- **Used in**: File detail bottom sheets

### FilePreviewCard
- **File**: `lib/ui/widgets/file_preview_widgets.dart`
- **Purpose**: Card showing file preview thumbnail alongside file info
- **Visual description**: Card with Row layout: 48x8px FilePreviewWidget + Column (file name w500, extension badge + file size). Extension badge: colored background, 4px border radius, 10px uppercase text
- **Used in**: FileSummaryWidget file list

### FileTypeHelper
- **File**: `lib/ui/widgets/file_preview_widgets.dart`
- **Purpose**: Static utility class for file type detection, icons, and colors
- **File type colors**:
  - Image: `#4CAF50` (green)
  - Video: `#E91E63` (pink)
  - Audio: `#9C27B0` (purple)
  - Document: `#2196F3` (blue)
  - PDF: `#FF5722` (deep orange)
  - Archive: `#FF9800` (orange)
  - Code: `#00BCD4` (cyan)
  - Unknown: `textTertiary`
- **Icons**: `image_rounded`, `video_file_rounded`, `audio_file_rounded`, `description_rounded`, `picture_as_pdf_rounded`, `folder_zip_rounded`, `code_rounded`, `insert_drive_file_rounded`

### FileSummaryWidget
- **File**: `lib/ui/widgets/file_summary_widget.dart`
- **Purpose**: Shows summary of selected files with type breakdown
- **Visual description**: Card with folder icon + "N files selected" + total size. Below: Wrap of Chips (one per file type, colored icon + count + type name). Optional file list (up to 5) using FilePreviewCard, or "+X more" card if >5 files
- **Used in**: FilePickerScreen, QuickSendScreen (as informational widget)

### FullScreenImageViewer
- **File**: `lib/ui/widgets/full_screen_image_viewer.dart`
- **Purpose**: Full-screen gallery with pinch-to-zoom and swipe between images
- **Visual description**: Black background, extend behind AppBar. AppBar: transparent, close button, image counter pill ("1 / N"), share button. Body: PhotoViewGallery with BouncingScrollPhysics. Pinch-to-zoom (contained to 3x covered). Hero transitions.
- **States**:
  - **Loading**: `CircularProgressIndicator` with progress
  - **Error**: Broken image icon + "Cannot load image"
- **Used in**: As a standalone viewer, called via `FullScreenImageViewer.show()`

### ImageGalleryGrid
- **File**: `lib/ui/widgets/full_screen_image_viewer.dart`
- **Purpose**: Grid of image thumbnails that open full-screen viewer on tap
- **Visual description**: GridView with configurable crossAxisCount (default 3), 4px spacing. Each cell: ClipRRect 8px border radius, Image.file with cacheWidth 200. Hero tag per image.
- **Used in**: Potential gallery views

### ShareIntentDialog
- **File**: `lib/ui/widgets/share_intent_dialog.dart`
- **Purpose**: Dialog shown when receiving share intent from Android system
- **Visual description**: AlertDialog with `surfaceColor`, 20px border radius. Header: 40px share icon in primaryColor circle. "Share with Syndro" title (titleLarge bold). "N files selected" subtitle. Two option rows:
  - App to App: `Icons.phone_android`, "Direct transfer to nearby devices"
  - Browser Share: `Icons.language`, "Share via web browser"
  - Each option: 24px icon in primaryColor container + title/subtitle + chevron
  - Cancel text button
- **States**:
  - **Processing**: Shows `CircularProgressIndicator` + "Preparing files..." + "Please wait"
- **Used in**: Android share intent handler

### ShimmerLoading
- **File**: `lib/ui/widgets/shimmer_loading.dart`
- **Purpose**: Shimmer skeleton loading effect
- **Visual description**: Wraps child with `Shimmer.fromColors`. Dark mode: base `#1E1E2E`, highlight `#2A2A3E`. Light mode: base `#E0E0E0`, highlight `#F5F5F5`
- **Used in**: DeviceCardSkeleton, HistoryItemSkeleton (skeleton loading placeholders)

### DeviceCardSkeleton
- **File**: `lib/ui/widgets/shimmer_loading.dart`
- **Purpose**: Skeleton placeholder for device cards during loading
- **Visual description**: Card with Row: 56x56px rounded square (icon placeholder) + Column of 3 rounded rectangles (name 20px, platform 14px, IP 12px) + 12px circle (status indicator)
- **Used in**: HomeScreen loading state

### HistoryItemSkeleton
- **File**: `lib/ui/widgets/shimmer_loading.dart`
- **Purpose**: Skeleton placeholder for history items during loading
- **Visual description**: Card with Row: 48x48px rounded square + Column of 2 rounded rectangles (name 16px, details 12px)
- **Used in**: HistoryScreen loading state

### SuccessAnimation
- **File**: `lib/ui/widgets/status_animations.dart` and `lib/ui/animations/status_animations.dart`
- **Purpose**: Animated success checkmark with scale-in effect
- **Visual description**: 80x80px circle (successColor at 20%). Animation: 600ms total. First 300ms: scale from 0→1 with `elasticOut` curve. Last 300ms: check_circle icon scales from 0→1 with `easeOut`. Calls `onComplete` when done.
- **Used in**: Transfer completion states

### ErrorAnimation
- **File**: `lib/ui/widgets/status_animations.dart` and `lib/ui/animations/status_animations.dart`
- **Purpose**: Animated error icon with shake effect
- **Visual description**: 80x80px circle (errorColor at 20%). Animation: 600ms total. First 200ms: scale 0→1. Last 400ms: horizontal shake (-8→8px, elasticIn). Error icon 60px. Calls `onComplete` when done.
- **Used in**: Transfer failure states

### PulseAnimation (Widget)
- **File**: `lib/ui/widgets/status_animations.dart` and `lib/ui/animations/status_animations.dart`
- **Purpose**: Continuous pulsing scale effect for loading/scanning states
- **Visual description**: Wraps child, scales 1.0→1.1 continuously (1500ms, repeat, reverse, easeInOut). Can be toggled on/off via `animate` parameter.
- **Used in**: Scanning indicators, loading states

### FadeInAnimation
- **File**: `lib/ui/widgets/status_animations.dart` and `lib/ui/animations/status_animations.dart`
- **Purpose**: Fade-in + slide-up animation for new items appearing
- **Visual description**: Wraps child. 400ms animation (configurable delay). Opacity 0→1 (easeOut) + slide from (0, 0.1) to (0, 0) (easeOut).
- **Used in**: List items appearing, new content

### TransferProgressWidget
- **File**: `lib/ui/widgets/transfer_progress_widget.dart`
- **Purpose**: Compact transfer progress card for inline display
- **Visual description**: Card with: status text (titleMedium), file names (bodyMedium), `LinearProgressIndicator` (8px, primaryColor), progress info (bytes + percentage), speed (accentColor) + ETA. Completed: green check + "Transfer completed". Failed: red error + message + "Retry Transfer" button. Cancelled: warning icon + "Try Again" button.
- **States**: Pending, Connecting, Transferring, Completed, Failed, Cancelled
- **Used in**: Inline transfer status displays

### TransferRequestSheet
- **File**: `lib/ui/widgets/transfer_request_sheet.dart`
- **Purpose**: Bottom sheet for incoming transfer requests with accept/reject/trust options
- **Visual description**: `surfaceColor` background, 24px top border radius. Handle bar (40x4px). Download icon (48px) in primaryColor container. "Incoming Transfer" title. Sender name + "wants to send you:" + optional "Trusted" badge (green pill with verified_user icon). File details card. Scrollable file list (max 150px height) if multiple files. Buttons: Decline (red outlined), Accept (green elevated), "Accept & Always Trust This Device" (primaryColor text button)
- **Used in**: Transfer request handling

### TransferRequestStrings
- **File**: `lib/ui/widgets/transfer_request_strings.dart`
- **Purpose**: Localization constants for transfer request UI
- **Strings**: "Incoming Transfer", "wants to send you:", "Decline", "Accept", "Accept & Always Trust This Device", "Transfer accepted", "Transfer rejected"

---

## Animations

### FadeAnimation
- **File**: `lib/ui/animations/fade_animation.dart`
- **What animates**: Opacity from 0→1
- **Duration**: Default 400ms, configurable
- **Delay**: Configurable (default zero)
- **Curve**: `Curves.easeOut` (configurable)
- **Usage**: General fade-in wrapper

### SlideAnimation
- **File**: `lib/ui/animations/slide_animation.dart`
- **What animates**: Slide from offset to zero + fade in
- **Duration**: Default 400ms, configurable
- **Delay**: Configurable
- **Curve**: `Curves.easeOutCubic` (configurable)
- **Directions**: up/down/left/right (default up, 30px offset)
- **Usage**: Content sliding into view

### ScaleAnimation
- **File**: `lib/ui/animations/scale_animation.dart`
- **What animates**: Scale from 0.8→1.0 + fade in
- **Duration**: Default 400ms
- **Delay**: Configurable
- **Curve**: `Curves.easeOutBack` (configurable)
- **Usage**: Elements popping into view with slight overshoot

### StaggeredListItem
- **File**: `lib/ui/animations/staggered_list_animation.dart`
- **What animates**: Fade in + slide up (0.2 offset) per list item
- **Duration**: Default 400ms per item
- **Stagger delay**: 50ms between items (configurable)
- **Curve**: `Curves.easeOutCubic`
- **Usage**: List items appearing sequentially

### PulseAnimation (Animation)
- **File**: `lib/ui/animations/pulse_animation.dart`
- **What animates**: Continuous scale oscillation (default 0.95→1.05)
- **Duration**: Default 1000ms per cycle
- **Behavior**: Repeats in reverse automatically
- **Usage**: Scanning indicators, breathing effects

### Page Transitions
- **File**: `lib/ui/animations/page_transitions.dart`
- **SlidePageRoute**: Slide from direction (right/left/up/down) + fade. Duration 300ms, `easeOutCubic` curve
- **FadePageRoute**: Simple fade transition. Duration 300ms
- **ScalePageRoute**: Scale from 0.9→1.0 + fade. Duration 300ms, `easeOutCubic`
- **Usage**: Custom navigation transitions between screens

### Transfer Animations
- **File**: `lib/ui/animations/transfer_animations.dart`
- **FadeInAnimation**: Opacity 0→1, 500ms, `easeIn` curve. Delay configurable
- **SlideInAnimation**: Slide from configurable offset (default 0, 0.3) to zero, 500ms, `easeOutCubic`
- **PulseAnimation**: Scale 0.95→1.05, 1000ms, repeat reverse
- **ShakeAnimation**: Horizontal shake sequence (0→10→-10→10→-10→0), 500ms total. Uses `TweenSequence` with 5 steps
- **SuccessCheckAnimation**: Scale from 0→1 with `elasticOut` curve, 600ms. Displays check_circle icon with configurable size and color

### Status Animations (in animations/)
- **File**: `lib/ui/animations/status_animations.dart`
- **SuccessAnimation**: Same as widget version — 80x80 circle, elastic scale + check icon fade, 600ms
- **ErrorAnimation**: Same as widget version — 80x80 circle, scale + horizontal shake, 600ms
- **PulseAnimation**: Same — 1.0→1.1 scale, 1500ms repeat
- **FadeInAnimation**: Opacity + slide up (0.1 offset), 400ms

---

## Summary of Screen-to-Screen Navigation

```
App Launch
    │
    ├── [First Launch] ──→ OnboardingScreen (3 pages)
    │                           │
    │                           ├── [Android] ──→ PermissionsOnboardingScreen
    │                           │                       │
    │                           │                       └──→ MainNavigationScreen
    │                           │
    │                           └── [Desktop] ──→ MainNavigationScreen
    │
    └── [Returning] ──→ MainNavigationScreen
                            │
            ┌───────────────┼───────────────┐
            │               │               │
         [Tab 0]         [Tab 1]         [Tab 2]
      HomeScreen      HistoryScreen   SettingsScreen
            │
            ├── Tap device → FilePickerScreen
            │                    │
            │                    ├── [Single device] → TransferProgressScreen
            │                    │
            │                    └── [Multi device] → MultiTransferProgressScreen
            │
            ├── Browser Share FAB → Bottom Sheet
            │       ├── Share Media → BrowserShareScreen
            │       ├── Send Files → BrowserShareScreen
            │       └── Receive Files → BrowserReceiveScreen
            │
            └── [Desktop right-click] → QuickSendScreen → FilePickerScreen
```
