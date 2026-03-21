import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/providers.dart';

/// Subtitle settings section for the settings screen
class SubtitleSettingsSection extends ConsumerStatefulWidget {
  final int profileId;

  const SubtitleSettingsSection({
    super.key,
    required this.profileId,
  });

  @override
  ConsumerState<SubtitleSettingsSection> createState() => _SubtitleSettingsSectionState();
}

class _SubtitleSettingsSectionState extends ConsumerState<SubtitleSettingsSection> {
  SubtitlePreference? _preferences;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final db = ref.read(appDatabaseProvider);
    final prefs = await db.getSubtitlePreferences(widget.profileId);
    setState(() {
      _preferences = prefs;
      _isLoading = false;
    });
  }

  Future<void> _savePreferences() async {
    if (_preferences == null) return;
    
    final db = ref.read(appDatabaseProvider);
    await db.setSubtitlePreferences(SubtitlePreferencesCompanion(
      profileId: Value(widget.profileId),
      preferredLanguage: Value(_preferences!.preferredLanguage),
      fontSize: Value(_preferences!.fontSize),
      fontColor: Value(_preferences!.fontColor),
      backgroundOpacity: Value(_preferences!.backgroundOpacity),
      edgeStyle: Value(_preferences!.edgeStyle),
      position: Value(_preferences!.position),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF4A6FA5),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Subtitles',
            style: TextStyle(
              color: Color(0xFFE8EDF2),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        
        // Preview
        _buildPreview(),
        
        const SizedBox(height: 16),
        
        // Preferred Language
        _buildLanguageSelector(),
        
        const SizedBox(height: 16),
        
        // Font Size
        _buildFontSizeSelector(),
        
        const SizedBox(height: 16),
        
        // Font Color
        _buildColorSelector(),
        
        const SizedBox(height: 16),
        
        // Background Opacity
        _buildBackgroundSelector(),
        
        const SizedBox(height: 16),
        
        // Edge Style
        _buildEdgeStyleSelector(),
        
        const SizedBox(height: 16),
        
        // Position
        _buildPositionSelector(),
        
        const SizedBox(height: 24),
        
        // Reset button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Color(0xFFFF6B6B),
              side: const BorderSide(color: Color(0xFFFF6B6B)),
            ),
            onPressed: _resetToDefaults,
            child: const Text('Reset to Defaults'),
          ),
        ),
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A3A50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF000000).withOpacity(_preferences?.backgroundOpacity ?? 0.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Sample subtitle text',
              style: TextStyle(
                color: _parseColor(_preferences?.fontColor ?? '#FFFFFF'),
                fontSize: (_preferences?.fontSize ?? 16).toDouble(),
                fontWeight: FontWeight.normal,
                shadows: _preferences?.edgeStyle == 'shadow'
                    ? [
                        const Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 2,
                          color: Colors.black,
                        ),
                      ]
                    : _preferences?.edgeStyle == 'outline'
                        ? [
                            const Shadow(
                              offset: Offset(-1, -1),
                              color: Colors.black,
                            ),
                            const Shadow(
                              offset: Offset(1, -1),
                              color: Colors.black,
                            ),
                            const Shadow(
                              offset: Offset(-1, 1),
                              color: Colors.black,
                            ),
                            const Shadow(
                              offset: Offset(1, 1),
                              color: Colors.black,
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

  Widget _buildLanguageSelector() {
    final languages = [
      ('en', 'English'),
      ('hi', 'Hindi'),
      ('ta', 'Tamil'),
      ('te', 'Telugu'),
      ('ml', 'Malayalam'),
      ('kn', 'Kannada'),
      ('ja', 'Japanese'),
      ('ko', 'Korean'),
      ('zh', 'Chinese'),
      ('es', 'Spanish'),
      ('fr', 'French'),
      ('de', 'German'),
      ('pt', 'Portuguese'),
      ('ru', 'Russian'),
      ('ar', 'Arabic'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonFormField<String>(
        value: _preferences?.preferredLanguage ?? 'en',
        dropdownColor: const Color(0xFF2A3A50),
        style: const TextStyle(color: Color(0xFFE8EDF2)),
        decoration: const InputDecoration(
          labelText: 'Preferred Language',
          labelStyle: TextStyle(color: Color(0xFF8B9BB0)),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2A3A50)),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF4A6FA5)),
          ),
        ),
        items: languages.map((lang) {
          return DropdownMenuItem(
            value: lang.$1,
            child: Text(lang.$2),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _preferences = _preferences?.copyWith(preferredLanguage: value) ??
                  SubtitlePreference(
                    id: 0,
                    profileId: widget.profileId,
                    preferredLanguage: value,
                    fontSize: 16,
                    fontColor: '#FFFFFF',
                    backgroundOpacity: 0.5,
                    edgeStyle: 'none',
                    position: 100,
                  );
            });
            _savePreferences();
          }
        },
      ),
    );
  }

  Widget _buildFontSizeSelector() {
    final sizes = [
      (12, 'Small'),
      (16, 'Medium'),
      (20, 'Large'),
      (24, 'Extra Large'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Font Size',
            style: TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: sizes.map((size) {
              final isSelected = _preferences?.fontSize == size.$1;
              return ChoiceChip(
                label: Text(size.$2),
                selected: isSelected,
                selectedColor: const Color(0xFF4A6FA5),
                backgroundColor: const Color(0xFF2A3A50),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFE8EDF2) : const Color(0xFF8B9BB0),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _preferences = _preferences?.copyWith(fontSize: size.$1) ??
                          SubtitlePreference(
                            id: 0,
                            profileId: widget.profileId,
                            preferredLanguage: 'en',
                            fontSize: size.$1,
                            fontColor: '#FFFFFF',
                            backgroundOpacity: 0.5,
                            edgeStyle: 'none',
                            position: 100,
                          );
                    });
                    _savePreferences();
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector() {
    final colors = [
      ('#FFFFFF', 'White', Colors.white),
      ('#FFFF00', 'Yellow', Colors.yellow),
      ('#00FFFF', 'Cyan', Colors.cyan),
      ('#00FF00', 'Green', Colors.green),
      ('#FF00FF', 'Magenta', Colors.purple),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Font Color',
            style: TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: colors.map((color) {
              final isSelected = _preferences?.fontColor == color.$1;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _preferences = _preferences?.copyWith(fontColor: color.$1) ??
                        SubtitlePreference(
                          id: 0,
                          profileId: widget.profileId,
                          preferredLanguage: 'en',
                          fontSize: 16,
                          fontColor: color.$1,
                          backgroundOpacity: 0.5,
                          edgeStyle: 'none',
                          position: 100,
                        );
                  });
                  _savePreferences();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.$3,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4A6FA5) : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.$3 == Colors.white || color.$3 == Colors.yellow
                              ? Colors.black
                              : Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundSelector() {
    final backgrounds = [
      (0.0, 'None'),
      (0.5, 'Low'),
      (0.8, 'High'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Background',
            style: TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: backgrounds.map((bg) {
              final isSelected = (_preferences?.backgroundOpacity ?? 0.5) == bg.$1;
              return ChoiceChip(
                label: Text(bg.$2),
                selected: isSelected,
                selectedColor: const Color(0xFF4A6FA5),
                backgroundColor: const Color(0xFF2A3A50),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFE8EDF2) : const Color(0xFF8B9BB0),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _preferences = _preferences?.copyWith(backgroundOpacity: bg.$1) ??
                          SubtitlePreference(
                            id: 0,
                            profileId: widget.profileId,
                            preferredLanguage: 'en',
                            fontSize: 16,
                            fontColor: '#FFFFFF',
                            backgroundOpacity: bg.$1,
                            edgeStyle: 'none',
                            position: 100,
                          );
                    });
                    _savePreferences();
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEdgeStyleSelector() {
    final styles = [
      ('none', 'None'),
      ('outline', 'Outline'),
      ('shadow', 'Shadow'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Edge Style',
            style: TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: styles.map((style) {
              final isSelected = (_preferences?.edgeStyle ?? 'none') == style.$1;
              return ChoiceChip(
                label: Text(style.$2),
                selected: isSelected,
                selectedColor: const Color(0xFF4A6FA5),
                backgroundColor: const Color(0xFF2A3A50),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFE8EDF2) : const Color(0xFF8B9BB0),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _preferences = _preferences?.copyWith(edgeStyle: style.$1) ??
                          SubtitlePreference(
                            id: 0,
                            profileId: widget.profileId,
                            preferredLanguage: 'en',
                            fontSize: 16,
                            fontColor: '#FFFFFF',
                            backgroundOpacity: 0.5,
                            edgeStyle: style.$1,
                            position: 100,
                          );
                    });
                    _savePreferences();
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionSelector() {
    final positions = [
      (100, 'Bottom'),
      (50, 'Center'),
      (10, 'Top'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Position',
            style: TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: positions.map((pos) {
              final isSelected = (_preferences?.position ?? 100) == pos.$1;
              return ChoiceChip(
                label: Text(pos.$2),
                selected: isSelected,
                selectedColor: const Color(0xFF4A6FA5),
                backgroundColor: const Color(0xFF2A3A50),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFE8EDF2) : const Color(0xFF8B9BB0),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _preferences = _preferences?.copyWith(position: pos.$1) ??
                          SubtitlePreference(
                            id: 0,
                            profileId: widget.profileId,
                            preferredLanguage: 'en',
                            fontSize: 16,
                            fontColor: '#FFFFFF',
                            backgroundOpacity: 0.5,
                            edgeStyle: 'none',
                            position: pos.$1,
                          );
                    });
                    _savePreferences();
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _resetToDefaults() async {
    final db = ref.read(appDatabaseProvider);
    await db.resetSubtitlePreferences(widget.profileId);
    await _loadPreferences();
  }

  Color _parseColor(String hex) {
    final cleanHex = hex.replaceFirst('#', '');
    return Color(int.parse('FF$cleanHex', radix: 16));
  }
}
