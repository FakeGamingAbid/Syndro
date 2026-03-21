import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/player/player_controller.dart';
import '../../core/platform/platform_detector.dart';
import '../../core/providers/provider_manager.dart';
import 'subtitle_selector.dart';

/// Full screen player screen
class PlayerScreen extends ConsumerStatefulWidget {
  final String contentId;
  final String title;
  final String? imdbId;
  final String providerInternalName;
  final String linkId;

  const PlayerScreen({
    super.key,
    required this.contentId,
    required this.title,
    this.imdbId,
    required this.providerInternalName,
    required this.linkId,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  double _brightness = 0.5;
  double _lastHorizontalDrag = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final playerController = ref.read(playerControllerProvider.notifier);

    // Get links from provider
    final providerManager = ref.read(providerManagerProvider.notifier);
    final links = await providerManager.getLinks(
      widget.providerInternalName,
      widget.linkId,
    );

    if (links.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sources available')),
        );
        Navigator.pop(context);
      }
      return;
    }

    // Convert to ExtractedLink
    final extractedLinks = links.map((link) {
      return ExtractedLink(
        url: link['url'] as String,
        quality: link['quality'] as String? ?? 'Unknown',
        isHls: (link['url'] as String).contains('.m3u8'),
        providerName: link['provider'] as String?,
      );
    }).toList();

    // Add sources to player
    await playerController.addSources(extractedLinks);

    // Initialize with first source
    await playerController.loadMedia(
      extractedLinks.first.url,
      title: widget.title,
      contentId: widget.contentId,
    );
  }

  @override
  void dispose() {
    ref.read(playerControllerProvider.notifier).stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final videoController = playerController.videoController;

    // Set fullscreen
    if (playerState.isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => playerController.toggleControls(),
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: (details) =>
            _onHorizontalDragUpdate(details, playerController),
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(
          children: [
            // Video
            Video(
              controller: videoController,
              fit: BoxFit.contain,
            ),

            // Controls overlay
            AnimatedOpacity(
              opacity: playerState.showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: IgnorePointer(
                ignoring: !playerState.showControls,
                child: _buildControls(playerState, playerController),
              ),
            ),

            // Buffering indicator
            if (playerState.isBuffering)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF4A6FA5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(PlayerState state, PlayerController controller) {
    final isTv = PlatformDetector.isTV;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.7),
            Colors.transparent,
            Colors.transparent,
            Colors.black.withOpacity(0.7),
          ],
          stops: const [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top bar
          _buildTopBar(state, controller),

          const Spacer(),

          // Center controls
          _buildCenterControls(state, controller, isTv),

          const Spacer(),

          // Bottom bar
          _buildBottomBar(state, controller, isTv),
        ],
      ),
    );
  }

  Widget _buildTopBar(PlayerState state, PlayerController controller) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                controller.stop();
                Navigator.pop(context);
              },
            ),
            Expanded(
              child: Text(
                state.currentTitle ?? widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: () {
                // Show more options
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls(
      PlayerState state, PlayerController controller, bool isTv) {
    final buttonSize = isTv ? 64.0 : 48.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind
        IconButton(
          iconSize: buttonSize,
          icon: const Icon(Icons.replay_10, color: Colors.white),
          onPressed: () => controller.seekBackward(),
        ),

        const SizedBox(width: 32),

        // Play/Pause
        IconButton(
          iconSize: buttonSize + 16,
          icon: Icon(
            state.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
          ),
          onPressed: () => controller.togglePlayPause(),
        ),

        const SizedBox(width: 32),

        // Forward
        IconButton(
          iconSize: buttonSize,
          icon: const Icon(Icons.forward_10, color: Colors.white),
          onPressed: () => controller.seekForward(),
        ),
      ],
    );
  }

  Widget _buildBottomBar(
      PlayerState state, PlayerController controller, bool isTv) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            // Source chips
            if (state.sources.length > 1) _buildSourceChips(state, controller),

            const SizedBox(height: 8),

            // Progress bar
            _buildProgressBar(state, controller),

            const SizedBox(height: 8),

            // Control buttons
            _buildControlButtons(state, controller, isTv),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceChips(PlayerState state, PlayerController controller) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: state.sources.asMap().entries.map((entry) {
          final index = entry.key;
          final source = entry.value;
          final isActive = index == state.activeSourceIndex;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => controller.switchSource(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF4A6FA5) : Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isActive ? const Color(0xFF4A6FA5) : Colors.white30,
                  ),
                ),
                child: Text(
                  source.quality,
                  style: TextStyle(
                    color: isActive ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgressBar(PlayerState state, PlayerController controller) {
    final position = state.position;
    final duration = state.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: const Color(0xFF4A6FA5),
        inactiveTrackColor: Colors.white30,
        thumbColor: const Color(0xFF4A6FA5),
        overlayColor: const Color(0xFF4A6FA5).withOpacity(0.3),
      ),
      child: Slider(
        value: progress.clamp(0.0, 1.0),
        onChanged: (value) {
          final newPosition = Duration(
            milliseconds: (value * duration.inMilliseconds).round(),
          );
          controller.seek(newPosition);
        },
      ),
    );
  }

  Widget _buildControlButtons(
      PlayerState state, PlayerController controller, bool isTv) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Time display
        Text(
          '${_formatDuration(state.position)} / ${_formatDuration(state.duration)}',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),

        // CC button
        IconButton(
          icon: const Icon(Icons.closed_caption, color: Colors.white, size: 20),
          onPressed: () {
            // Subtitle selection - simplified for now
          },
        ),

        // Speed button
        IconButton(
          icon: const Icon(Icons.speed, color: Colors.white, size: 20),
          onPressed: () => _showSpeedSelector(controller),
        ),

        // PiP button (not on TV)
        if (!isTv)
          IconButton(
            icon: const Icon(Icons.picture_in_picture_alt,
                color: Colors.white, size: 20),
            onPressed: () => controller.togglePiP(),
          ),

        // Fullscreen button
        IconButton(
          icon: Icon(
            state.isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => controller.toggleFullscreen(),
        ),
      ],
    );
  }

  void _showSpeedSelector(PlayerController controller) {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A28),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Playback Speed',
              style: TextStyle(
                color: Color(0xFFE8EDF2),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...speeds.map((speed) => ListTile(
                title: Text(
                  '${speed}x',
                  style: const TextStyle(color: Color(0xFFE8EDF2)),
                ),
                onTap: () {
                  controller.setPlaybackSpeed(speed);
                  Navigator.pop(context);
                },
              )),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (Platform.isAndroid && !PlatformDetector.isTV) {
      _lastHorizontalDrag = details.localPosition.dx;
      _isDragging = true;
    }
  }

  void _onHorizontalDragUpdate(
      DragUpdateDetails details, PlayerController controller) {
    if (Platform.isAndroid && !PlatformDetector.isTV && _isDragging) {
      final screenWidth = MediaQuery.of(context).size.width;
      final dx = details.localPosition.dx;
      final delta = dx - _lastHorizontalDrag;

      if (dx < screenWidth / 2) {
        // Left side - brightness
        _brightness = (_brightness - delta / 500).clamp(0.0, 1.0);
        // Could integrate with system brightness
      } else {
        // Right side - volume
        final volume = controller.state.volume + delta / 500;
        controller.setVolume(volume.clamp(0.0, 1.0));
      }

      _lastHorizontalDrag = dx;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    _isDragging = false;
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
