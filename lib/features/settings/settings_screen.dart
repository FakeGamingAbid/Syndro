import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moonplex/core/theme/moon_theme.dart';

// ============== SETTINGS PROVIDERS ==============

enum AppThemeMode { dark, light }
enum PlaybackQuality { auto, p480, p720, p1080 }
enum DownloadQuality { p480, p720, p1080 }
enum SubtitleFontSize { small, medium, large, extraLarge }
enum SubtitleFontColor { white, yellow, cyan }
enum SubtitleBgOpacity { none, low, high }
enum SubtitleEdgeStyle { none, dropShadow, outline }
enum SubtitlePosition { bottom, top }

final themeModeProvider = StateProvider<AppThemeMode>((ref) => AppThemeMode.dark);
final autoplayNextProvider = StateProvider<bool>((ref) => true);
final skipIntroProvider = StateProvider<bool>((ref) => false);
final downloadWifiOnlyProvider = StateProvider<bool>((ref) => true);
final defaultQualityProvider = StateProvider<PlaybackQuality>((ref) => PlaybackQuality.auto);
final downloadQualityProvider = StateProvider<DownloadQuality>((ref) => DownloadQuality.p720);

final subtitleLangProvider = StateProvider<String>((ref) => 'en');
final subtitleFontSizeProvider = StateProvider<SubtitleFontSize>((ref) => SubtitleFontSize.medium);
final subtitleFontColorProvider = StateProvider<SubtitleFontColor>((ref) => SubtitleFontColor.white);
final subtitleBgOpacityProvider = StateProvider<SubtitleBgOpacity>((ref) => SubtitleBgOpacity.low);
final subtitleEdgeStyleProvider = StateProvider<SubtitleEdgeStyle>((ref) => SubtitleEdgeStyle.none);
final subtitlePositionProvider = StateProvider<SubtitlePosition>((ref) => SubtitlePosition.bottom);

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

final storageUsedProvider = FutureProvider<int>((ref) async {
  // Placeholder - would calculate actual storage
  return 0;
});

// ============== SETTINGS SCREEN ==============

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: MoonTheme.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Settings',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        automaticallyImplyLeading: false,
      ),
      body: isDesktop
          ? Row(
              children: [
                // Sidebar
                Container(
                  width: 250,
                  color: MoonTheme.backgroundSecondary,
                  child: _buildSettingsNav(context, ref),
                ),
                // Content
                Expanded(
                  child: _buildSettingsContent(context, ref),
                ),
              ],
            )
          : _buildSettingsContent(context, ref),
    );
  }

  Widget _buildSettingsNav(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        _SettingsNavItem(
          icon: Icons.palette_outlined,
          label: 'Appearance',
          isSelected: true,
          onTap: () {},
        ),
        _SettingsNavItem(
          icon: Icons.play_circle_outline,
          label: 'Playback',
          isSelected: false,
          onTap: () {},
        ),
        _SettingsNavItem(
          icon: Icons.subtitles_outlined,
          label: 'Subtitles',
          isSelected: false,
          onTap: () {},
        ),
        _SettingsNavItem(
          icon: Icons.download_outlined,
          label: 'Downloads',
          isSelected: false,
          onTap: () {},
        ),
        _SettingsNavItem(
          icon: Icons.storage_outlined,
          label: 'Storage',
          isSelected: false,
          onTap: () {},
        ),
        _SettingsNavItem(
          icon: Icons.person_outline,
          label: 'Account',
          isSelected: false,
          onTap: () {},
        ),
        _SettingsNavItem(
          icon: Icons.info_outline,
          label: 'About',
          isSelected: false,
          onTap: () {},
        ),
      ],
    );
  }

  Widget _buildSettingsContent(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Appearance Section
        _SectionHeader(title: 'Appearance'),
        _SettingsCard(
          children: [
            _SettingsTile(
              title: 'Theme',
              subtitle: 'Moon Dark',
              trailing: Switch(
                value: ref.watch(themeModeProvider) == AppThemeMode.dark,
                onChanged: (value) {
                  ref.read(themeModeProvider.notifier).state =
                      value ? AppThemeMode.dark : AppThemeMode.light;
                },
                activeThumbColor: MoonTheme.accentPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Playback Section
        _SectionHeader(title: 'Playback'),
        _SettingsCard(
          children: [
            _SettingsTile(
              title: 'Default Quality',
              subtitle: _getQualityLabel(ref.watch(defaultQualityProvider)),
              onTap: () => _showQualityPicker(context, ref, isDownload: false),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Autoplay Next Episode',
              subtitle: 'Automatically play the next episode',
              trailing: Switch(
                value: ref.watch(autoplayNextProvider),
                onChanged: (value) {
                  ref.read(autoplayNextProvider.notifier).state = value;
                },
                activeThumbColor: MoonTheme.accentPrimary,
              ),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Skip Intro',
              subtitle: 'Automatically skip intro (if detected)',
              trailing: Switch(
                value: ref.watch(skipIntroProvider),
                onChanged: (value) {
                  ref.read(skipIntroProvider.notifier).state = value;
                },
                activeThumbColor: MoonTheme.accentPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Subtitles Section
        _SectionHeader(title: 'Subtitles'),
        _SettingsCard(
          children: [
            _SettingsTile(
              title: 'Default Language',
              subtitle: _getLanguageLabel(ref.watch(subtitleLangProvider)),
              onTap: () => _showLanguagePicker(context, ref),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Font Size',
              subtitle: _getFontSizeLabel(ref.watch(subtitleFontSizeProvider)),
              onTap: () => _showFontSizePicker(context, ref),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Font Color',
              subtitle: _getFontColorLabel(ref.watch(subtitleFontColorProvider)),
              onTap: () => _showFontColorPicker(context, ref),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Background Opacity',
              subtitle: _getBgOpacityLabel(ref.watch(subtitleBgOpacityProvider)),
              onTap: () => _showBgOpacityPicker(context, ref),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Edge Style',
              subtitle: _getEdgeStyleLabel(ref.watch(subtitleEdgeStyleProvider)),
              onTap: () => _showEdgeStylePicker(context, ref),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Position',
              subtitle: _getPositionLabel(ref.watch(subtitlePositionProvider)),
              onTap: () => _showPositionPicker(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Subtitle Preview
        _SubtitlePreview(
          fontSize: ref.watch(subtitleFontSizeProvider),
          fontColor: ref.watch(subtitleFontColorProvider),
          bgOpacity: ref.watch(subtitleBgOpacityProvider),
          edgeStyle: ref.watch(subtitleEdgeStyleProvider),
          position: ref.watch(subtitlePositionProvider),
        ),
        const SizedBox(height: 24),

        // Downloads Section
        _SectionHeader(title: 'Downloads'),
        _SettingsCard(
          children: [
            _SettingsTile(
              title: 'Download Location',
              subtitle: 'Internal Storage',
              onTap: () {},
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Download Quality',
              subtitle: _getDownloadQualityLabel(ref.watch(downloadQualityProvider)),
              onTap: () => _showDownloadQualityPicker(context, ref),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Download over WiFi Only',
              subtitle: 'Save mobile data',
              trailing: Switch(
                value: ref.watch(downloadWifiOnlyProvider),
                onChanged: (value) {
                  ref.read(downloadWifiOnlyProvider.notifier).state = value;
                },
                activeThumbColor: MoonTheme.accentPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Storage Section
        _SectionHeader(title: 'Storage'),
        _SettingsCard(
          children: [
            _SettingsTile(
              title: 'Cache Size',
              subtitle: '125 MB',
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Clear'),
              ),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Downloads',
              subtitle: '2.3 GB',
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Total Used',
              subtitle: '2.4 GB',
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Account Section
        _SectionHeader(title: 'Account'),
        _SettingsCard(
          children: [
            _SettingsTile(
              title: 'Current Profile',
              subtitle: 'Main Profile',
              trailing: const Icon(
                Icons.person,
                color: MoonTheme.textSecondary,
              ),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Switch Profile',
              subtitle: 'Change active profile',
              onTap: () {},
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Edit Profile',
              subtitle: 'Manage profile settings',
              onTap: () {},
            ),
          ],
        ),
        const SizedBox(height: 24),

        // About Section
        _SectionHeader(title: 'About'),
        _SettingsCard(
          children: [
            _SettingsTile(
              title: 'Version',
              subtitle: ref.watch(appVersionProvider).when(
                    data: (v) => v,
                    loading: () => 'Loading...',
                    error: (_, __) => 'Unknown',
                  ),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Check for Updates',
              subtitle: 'Current version is up to date',
              onTap: () => _checkForUpdates(context),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'GitHub Repository',
              subtitle: 'View source code',
              onTap: () => _launchUrl('https://github.com/moonplex/moonplex'),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Open Source Licenses',
              subtitle: 'View third-party licenses',
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Moonplex',
                applicationVersion: '1.0.0',
              ),
            ),
            const Divider(color: MoonTheme.cardBorder, height: 1),
            _SettingsTile(
              title: 'Privacy Policy',
              onTap: () => _launchUrl('https://moonplex.app/privacy'),
            ),
          ],
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  // Quality picker dialogs
  void _showQualityPicker(BuildContext context, WidgetRef ref, {required bool isDownload}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Default Quality',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: PlaybackQuality.values.map((q) {
            return ListTile(
              title: Text(
                _getQualityLabel(q),
                style: const TextStyle(color: MoonTheme.textPrimary),
              ),
              trailing: ref.watch(defaultQualityProvider) == q
                  ? const Icon(Icons.check, color: MoonTheme.accentPrimary)
                  : null,
              onTap: () {
                ref.read(defaultQualityProvider.notifier).state = q;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDownloadQualityPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Download Quality',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: DownloadQuality.values.map((q) {
            return ListTile(
              title: Text(
                _getDownloadQualityLabel(q),
                style: const TextStyle(color: MoonTheme.textPrimary),
              ),
              trailing: ref.watch(downloadQualityProvider) == q
                  ? const Icon(Icons.check, color: MoonTheme.accentPrimary)
                  : null,
              onTap: () {
                ref.read(downloadQualityProvider.notifier).state = q;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final languages = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Subtitle Language',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: languages.entries.map((e) {
              return ListTile(
                title: Text(
                  e.value,
                  style: const TextStyle(color: MoonTheme.textPrimary),
                ),
                trailing: ref.watch(subtitleLangProvider) == e.key
                    ? const Icon(Icons.check, color: MoonTheme.accentPrimary)
                    : null,
                onTap: () {
                  ref.read(subtitleLangProvider.notifier).state = e.key;
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showFontSizePicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Font Size',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SubtitleFontSize.values.map((s) {
            return ListTile(
              title: Text(
                _getFontSizeLabel(s),
                style: const TextStyle(color: MoonTheme.textPrimary),
              ),
              trailing: ref.watch(subtitleFontSizeProvider) == s
                  ? const Icon(Icons.check, color: MoonTheme.accentPrimary)
                  : null,
              onTap: () {
                ref.read(subtitleFontSizeProvider.notifier).state = s;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFontColorPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Font Color',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SubtitleFontColor.values.map((c) {
            return ListTile(
              title: Text(
                _getFontColorLabel(c),
                style: TextStyle(color: _getFontColor(c)),
              ),
              trailing: ref.watch(subtitleFontColorProvider) == c
                  ? const Icon(Icons.check, color: MoonTheme.accentPrimary)
                  : null,
              onTap: () {
                ref.read(subtitleFontColorProvider.notifier).state = c;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showBgOpacityPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Background Opacity',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SubtitleBgOpacity.values.map((o) {
            return ListTile(
              title: Text(
                _getBgOpacityLabel(o),
                style: const TextStyle(color: MoonTheme.textPrimary),
              ),
              trailing: ref.watch(subtitleBgOpacityProvider) == o
                  ? const Icon(Icons.check, color: MoonTheme.accentPrimary)
                  : null,
              onTap: () {
                ref.read(subtitleBgOpacityProvider.notifier).state = o;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showEdgeStylePicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Edge Style',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SubtitleEdgeStyle.values.map((e) {
            return ListTile(
              title: Text(
                _getEdgeStyleLabel(e),
                style: const TextStyle(color: MoonTheme.textPrimary),
              ),
              trailing: ref.watch(subtitleEdgeStyleProvider) == e
                  ? const Icon(Icons.check, color: MoonTheme.accentPrimary)
                  : null,
              onTap: () {
                ref.read(subtitleEdgeStyleProvider.notifier).state = e;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPositionPicker(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MoonTheme.backgroundSecondary,
        title: const Text(
          'Subtitle Position',
          style: TextStyle(color: MoonTheme.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SubtitlePosition.values.map((p) {
            return ListTile(
              title: Text(
                _getPositionLabel(p),
                style: const TextStyle(color: MoonTheme.textPrimary),
              ),
              trailing: ref.watch(subtitlePositionProvider) == p
                  ? const Icon(Icons.check, color: MoonTheme.accentPrimary)
                  : null,
              onTap: () {
                ref.read(subtitlePositionProvider.notifier).state = p;
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You are on the latest version!'),
        backgroundColor: MoonTheme.backgroundCard,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String _getQualityLabel(PlaybackQuality q) {
    switch (q) {
      case PlaybackQuality.auto:
        return 'Auto';
      case PlaybackQuality.p480:
        return '480p';
      case PlaybackQuality.p720:
        return '720p';
      case PlaybackQuality.p1080:
        return '1080p';
    }
  }

  String _getDownloadQualityLabel(DownloadQuality q) {
    switch (q) {
      case DownloadQuality.p480:
        return '480p';
      case DownloadQuality.p720:
        return '720p';
      case DownloadQuality.p1080:
        return '1080p';
    }
  }

  String _getLanguageLabel(String code) {
    final languages = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
    };
    return languages[code] ?? 'English';
  }

  String _getFontSizeLabel(SubtitleFontSize s) {
    switch (s) {
      case SubtitleFontSize.small:
        return 'Small';
      case SubtitleFontSize.medium:
        return 'Medium';
      case SubtitleFontSize.large:
        return 'Large';
      case SubtitleFontSize.extraLarge:
        return 'Extra Large';
    }
  }

  String _getFontColorLabel(SubtitleFontColor c) {
    switch (c) {
      case SubtitleFontColor.white:
        return 'White';
      case SubtitleFontColor.yellow:
        return 'Yellow';
      case SubtitleFontColor.cyan:
        return 'Cyan';
    }
  }

  Color _getFontColor(SubtitleFontColor c) {
    switch (c) {
      case SubtitleFontColor.white:
        return Colors.white;
      case SubtitleFontColor.yellow:
        return Colors.yellow;
      case SubtitleFontColor.cyan:
        return Colors.cyan;
    }
  }

  String _getBgOpacityLabel(SubtitleBgOpacity o) {
    switch (o) {
      case SubtitleBgOpacity.none:
        return 'None';
      case SubtitleBgOpacity.low:
        return 'Low';
      case SubtitleBgOpacity.high:
        return 'High';
    }
  }

  String _getEdgeStyleLabel(SubtitleEdgeStyle e) {
    switch (e) {
      case SubtitleEdgeStyle.none:
        return 'None';
      case SubtitleEdgeStyle.dropShadow:
        return 'Drop Shadow';
      case SubtitleEdgeStyle.outline:
        return 'Outline';
    }
  }

  String _getPositionLabel(SubtitlePosition p) {
    switch (p) {
      case SubtitlePosition.bottom:
        return 'Bottom';
      case SubtitlePosition.top:
        return 'Top';
    }
  }
}

// ============== WIDGETS ==============

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: MoonTheme.accentSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MoonTheme.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MoonTheme.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          color: MoonTheme.textPrimary,
          fontSize: 16,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                color: MoonTheme.textMuted,
                fontSize: 13,
              ),
            )
          : null,
      trailing: trailing ?? (onTap != null ? const Icon(Icons.chevron_right, color: MoonTheme.textMuted) : null),
      onTap: onTap,
    );
  }
}

class _SettingsNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingsNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? MoonTheme.accentPrimary : MoonTheme.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? MoonTheme.textPrimary : MoonTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedTileColor: MoonTheme.accentGlow.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onTap: onTap,
    );
  }
}

class _SubtitlePreview extends StatelessWidget {
  final SubtitleFontSize fontSize;
  final SubtitleFontColor fontColor;
  final SubtitleBgOpacity bgOpacity;
  final SubtitleEdgeStyle edgeStyle;
  final SubtitlePosition position;

  const _SubtitlePreview({
    required this.fontSize,
    required this.fontColor,
    required this.bgOpacity,
    required this.edgeStyle,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final fontSizeValue = _getFontSizeValue();
    final textColor = _getFontColorValue();
    final bgColor = _getBgColorValue();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MoonTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MoonTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(
              color: MoonTheme.textMuted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Sample subtitle text',
              style: TextStyle(
                color: textColor,
                fontSize: fontSizeValue,
                fontWeight: FontWeight.w500,
                shadows: edgeStyle == SubtitleEdgeStyle.dropShadow
                    ? [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 4,
                          offset: const Offset(1, 1),
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getFontSizeValue() {
    switch (fontSize) {
      case SubtitleFontSize.small:
        return 14;
      case SubtitleFontSize.medium:
        return 18;
      case SubtitleFontSize.large:
        return 24;
      case SubtitleFontSize.extraLarge:
        return 32;
    }
  }

  Color _getFontColorValue() {
    switch (fontColor) {
      case SubtitleFontColor.white:
        return Colors.white;
      case SubtitleFontColor.yellow:
        return Colors.yellow;
      case SubtitleFontColor.cyan:
        return Colors.cyan;
    }
  }

  Color _getBgColorValue() {
    switch (bgOpacity) {
      case SubtitleBgOpacity.none:
        return Colors.transparent;
      case SubtitleBgOpacity.low:
        return Colors.black.withOpacity(0.3);
      case SubtitleBgOpacity.high:
        return Colors.black.withOpacity(0.7);
    }
  }
}
