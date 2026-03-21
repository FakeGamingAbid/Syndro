import 'dart:math';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moonplex/core/database/app_database.dart';
import 'package:moonplex/core/providers/providers.dart';
import 'package:moonplex/core/theme/moon_theme.dart';

// ============== MOON PHASE ICONS ==============

class MoonPhaseIcon extends StatelessWidget {
  final int
      phase; // 0-7: new, waxing crescent, first quarter, waxing gibbous, full, waning gibbous, last quarter, waning crescent
  final double size;
  final Color color;

  const MoonPhaseIcon({
    super.key,
    required this.phase,
    this.size = 48,
    this.color = MoonTheme.accentPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MoonPhasePainter(phase: phase, color: color),
    );
  }
}

class _MoonPhasePainter extends CustomPainter {
  final int phase;
  final Color color;

  _MoonPhasePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // Draw moon circle
    final moonPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, moonPaint);

    // Draw shadow to show phase
    final shadowPaint = Paint()
      ..color = MoonTheme.backgroundPrimary
      ..style = PaintingStyle.fill;

    switch (phase) {
      case 0: // New moon - full shadow
        canvas.drawCircle(center, radius, shadowPaint);
        break;
      case 1: // Waxing crescent - shadow on right
        _drawCrescent(canvas, center, radius, shadowPaint, true, 0.75);
        break;
      case 2: // First quarter - half shadow (right half)
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -pi / 2,
          pi,
          true,
          shadowPaint,
        );
        break;
      case 3: // Waxing gibbous - small shadow
        _drawCrescent(canvas, center, radius, shadowPaint, true, 0.25);
        break;
      case 4: // Full moon - no shadow
        break;
      case 5: // Waning gibbous - small shadow on left
        _drawCrescent(canvas, center, radius, shadowPaint, false, 0.25);
        break;
      case 6: // Last quarter - half shadow (left half)
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          pi / 2,
          pi,
          true,
          shadowPaint,
        );
        break;
      case 7: // Waning crescent - shadow on left
        _drawCrescent(canvas, center, radius, shadowPaint, false, 0.75);
        break;
    }
  }

  void _drawCrescent(Canvas canvas, Offset center, double radius, Paint paint,
      bool shadowOnRight, double shadowAmount) {
    final path = Path();
    final shadowWidth = radius * 2 * shadowAmount;

    if (shadowOnRight) {
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCenter(center: center, width: shadowWidth, height: radius * 2),
        -pi / 2,
        pi,
        false,
      );
      path.close();
    } else {
      path.moveTo(center.dx, center.dy - radius);
      path.arcTo(
        Rect.fromCenter(center: center, width: shadowWidth, height: radius * 2),
        pi / 2,
        pi,
        false,
      );
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============== PROVIDERS ==============

final profilesProvider = FutureProvider<List<Profile>>((ref) async {
  final db = ref.watch(appDatabaseProvider);
  return db.getAllProfiles();
});

final selectedProfileProvider = StateProvider<Profile?>((ref) => null);

// ============== PROFILES SCREEN ==============

class ProfilesScreen extends ConsumerWidget {
  final VoidCallback? onProfileSelected;

  const ProfilesScreen({super.key, this.onProfileSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(profilesProvider);

    return Scaffold(
      backgroundColor: MoonTheme.backgroundPrimary,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              const Text(
                'Who is watching?',
                style: TextStyle(
                  color: MoonTheme.textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              // Profiles grid
              profilesAsync.when(
                data: (profiles) => _buildProfilesGrid(context, ref, profiles),
                loading: () => const CircularProgressIndicator(
                  color: MoonTheme.accentPrimary,
                ),
                error: (error, _) => Text(
                  'Error loading profiles',
                  style: TextStyle(color: MoonTheme.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilesGrid(
      BuildContext context, WidgetRef ref, List<Profile> profiles) {
    return Wrap(
      spacing: 24,
      runSpacing: 24,
      alignment: WrapAlignment.center,
      children: [
        ...profiles.map((profile) => _ProfileCard(
              profile: profile,
              onTap: () => _selectProfile(context, ref, profile),
            )),
        // Add profile button
        if (profiles.length < 4)
          _AddProfileCard(
            onTap: () => _showAddProfileDialog(context, ref),
          ),
      ],
    );
  }

  void _selectProfile(
      BuildContext context, WidgetRef ref, Profile profile) async {
    // Check if PIN is required
    if (profile.pinHash != null && profile.pinHash!.isNotEmpty) {
      final verified = await _showPinDialog(context, profile);
      if (!verified) return;
    }

    // Set active profile
    final db = ref.read(appDatabaseProvider);
    await db.setActiveProfile(profile.id);

    // Notify callback
    onProfileSelected?.call();
  }

  Future<bool> _showPinDialog(BuildContext context, Profile profile) async {
    String enteredPin = '';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PinDialog(
        title: 'Enter PIN for ${profile.name}',
        onVerify: (pin) async {
          // Verify PIN (simplified - use proper hashing in production)
          return pin == profile.pinHash;
        },
      ),
    );

    return result ?? false;
  }

  void _showAddProfileDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _AddProfileDialog(
        onSave: (name, moonPhase, pin) async {
          final db = ref.read(appDatabaseProvider);
          await db.insertProfile(ProfilesCompanion(
            name: Value(name),
            avatarMoonPhase: Value(moonPhase),
            pinHash: Value(pin),
          ));
          ref.invalidate(profilesProvider);
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Profile profile;
  final VoidCallback? onTap;

  const _ProfileCard({required this.profile, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MoonTheme.cardBorder, width: 3),
            ),
            child: ClipOval(
              child: Container(
                color: MoonTheme.backgroundSecondary,
                child: Center(
                  child: MoonPhaseIcon(
                    phase: profile.avatarMoonPhase,
                    size: 64,
                    color: MoonTheme.accentPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Name
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.name,
                style: const TextStyle(
                  color: MoonTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (profile.pinHash != null && profile.pinHash!.isNotEmpty) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock, color: MoonTheme.textMuted, size: 16),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  final VoidCallback? onTap;

  const _AddProfileCard({this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          // Add icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MoonTheme.cardBorder, width: 3),
            ),
            child: ClipOval(
              child: Container(
                color: MoonTheme.backgroundSecondary,
                child: const Center(
                  child: Icon(
                    Icons.add,
                    color: MoonTheme.textMuted,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Text
          const Text(
            'Add Profile',
            style: TextStyle(
              color: MoonTheme.textMuted,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  final String title;
  final Future<bool> Function(String pin) onVerify;

  const _PinDialog({required this.title, required this.onVerify});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog>
    with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isError = false;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onKeyPressed(String key) async {
    if (_pin.length >= 4) return;

    setState(() {
      _pin += key;
      _isError = false;
    });

    if (_pin.length == 4) {
      final verified = await widget.onVerify(_pin);
      if (verified) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isError = true;
          _pin = '';
        });
        _shakeController.forward().then((_) => _shakeController.reset());
      }
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _isError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MoonTheme.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: MoonTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // PIN display
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    _isError
                        ? _shakeAnimation.value *
                            ((_shakeController.value * 10).toInt() % 2 == 0
                                ? 1
                                : -1)
                        : 0,
                    0,
                  ),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length
                          ? (_isError
                              ? MoonTheme.error
                              : MoonTheme.accentPrimary)
                          : Colors.transparent,
                      border: Border.all(
                        color: _isError ? MoonTheme.error : MoonTheme.textMuted,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            // Number pad
            _buildNumberPad(),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['1', '2', '3'].map(_buildKey).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['4', '5', '6'].map(_buildKey).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ['7', '8', '9'].map(_buildKey).toList(),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKey(''), // Empty
            _buildKey('0'),
            _buildKey('back', isBackspace: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String key, {bool isBackspace = false}) {
    return GestureDetector(
      onTap: isBackspace
          ? _onBackspace
          : (key.isNotEmpty ? () => _onKeyPressed(key) : null),
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: MoonTheme.backgroundCard,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Center(
          child: isBackspace
              ? const Icon(Icons.backspace_outlined,
                  color: MoonTheme.textSecondary)
              : Text(
                  key,
                  style: const TextStyle(
                    color: MoonTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}

class _AddProfileDialog extends StatefulWidget {
  final Future<void> Function(String name, int moonPhase, String? pin) onSave;

  const _AddProfileDialog({required this.onSave});

  @override
  State<_AddProfileDialog> createState() => _AddProfileDialogState();
}

class _AddProfileDialogState extends State<_AddProfileDialog> {
  final _nameController = TextEditingController();
  int _selectedPhase = 4; // Full moon by default
  bool _usePin = false;
  String _pin = '';
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MoonTheme.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Profile',
                style: TextStyle(
                  color: MoonTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Name field
              TextField(
                controller: _nameController,
                style: const TextStyle(color: MoonTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: const TextStyle(color: MoonTheme.textSecondary),
                  filled: true,
                  fillColor: MoonTheme.backgroundCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MoonTheme.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MoonTheme.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: MoonTheme.accentGlow),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Moon phase picker
              const Text(
                'Choose Avatar',
                style: TextStyle(
                  color: MoonTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(8, (index) {
                  final isSelected = _selectedPhase == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedPhase = index),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? MoonTheme.accentGlow
                              : MoonTheme.cardBorder,
                          width: isSelected ? 3 : 1,
                        ),
                        color: MoonTheme.backgroundCard,
                      ),
                      child: Center(
                        child: MoonPhaseIcon(
                          phase: index,
                          size: 36,
                          color: isSelected
                              ? MoonTheme.accentPrimary
                              : MoonTheme.textMuted,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              // PIN toggle
              Row(
                children: [
                  Switch(
                    value: _usePin,
                    onChanged: (value) => setState(() => _usePin = value),
                    activeThumbColor: MoonTheme.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Use PIN',
                    style: TextStyle(color: MoonTheme.textSecondary),
                  ),
                ],
              ),
              if (_usePin) ...[
                const SizedBox(height: 16),
                // PIN input
                const Text(
                  'Enter 4-digit PIN',
                  style: TextStyle(color: MoonTheme.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(4, (index) {
                    return Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: MoonTheme.backgroundCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: MoonTheme.cardBorder),
                      ),
                      child: Center(
                        child: Text(
                          index < _pin.length ? '●' : '',
                          style: const TextStyle(
                            color: MoonTheme.accentPrimary,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                // PIN pad
                _buildPinPad(),
              ],
              const SizedBox(height: 24),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving || _nameController.text.isEmpty
                      ? null
                      : () async {
                          setState(() => _isSaving = true);
                          await widget.onSave(
                            _nameController.text,
                            _selectedPhase,
                            _usePin ? _pin : null,
                          );
                          if (mounted) Navigator.of(context).pop();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MoonTheme.accentPrimary,
                    foregroundColor: MoonTheme.backgroundPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: MoonTheme.backgroundPrimary,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinPad() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'back']
        ])
          for (var key in row)
            if (key.isEmpty)
              const SizedBox(width: 56, height: 56)
            else
              GestureDetector(
                onTap: () {
                  if (key == 'back') {
                    if (_pin.isNotEmpty) {
                      setState(() => _pin = _pin.substring(0, _pin.length - 1));
                    }
                  } else if (_pin.length < 4) {
                    setState(() => _pin += key);
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: MoonTheme.backgroundCard,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Center(
                    child: key == 'back'
                        ? const Icon(Icons.backspace_outlined,
                            color: MoonTheme.textSecondary)
                        : Text(
                            key,
                            style: const TextStyle(
                              color: MoonTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
      ],
    );
  }
}
