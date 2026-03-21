import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../database/app_database.dart';
import '../providers/providers.dart';

/// Provider for PlayerController
final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerState>((ref) {
  return PlayerController(ref);
});

/// Extracted link from provider
class ExtractedLink {
  final String url;
  final String quality;
  final bool isHls;
  final String? providerName;
  final List<SubtitleTrack>? subtitles;

  ExtractedLink({
    required this.url,
    required this.quality,
    this.isHls = false,
    this.providerName,
    this.subtitles,
  });
}

/// Player state
class PlayerState {
  final String? currentUrl;
  final String? currentTitle;
  final String? contentId;
  final String? imdbId;
  final List<ExtractedLink> sources;
  final int activeSourceIndex;
  final bool isPlaying;
  final bool isBuffering;
  final Duration position;
  final Duration duration;
  final double volume;
  final double playbackSpeed;
  final List<SubtitleTrack> subtitleTracks;
  final int activeSubtitleIndex;
  final bool isFullScreen;
  final bool showControls;
  final bool isPip;
  final String? error;

  PlayerState({
    this.currentUrl,
    this.currentTitle,
    this.contentId,
    this.imdbId,
    this.sources = const [],
    this.activeSourceIndex = 0,
    this.isPlaying = false,
    this.isBuffering = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.subtitleTracks = const [],
    this.activeSubtitleIndex = -1,
    this.isFullScreen = false,
    this.showControls = true,
    this.isPip = false,
    this.error,
  });

  PlayerState copyWith({
    String? currentUrl,
    String? currentTitle,
    String? contentId,
    String? imdbId,
    List<ExtractedLink>? sources,
    int? activeSourceIndex,
    bool? isPlaying,
    bool? isBuffering,
    Duration? position,
    Duration? duration,
    double? volume,
    double? playbackSpeed,
    List<SubtitleTrack>? subtitleTracks,
    int? activeSubtitleIndex,
    bool? isFullScreen,
    bool? showControls,
    bool? isPip,
    String? error,
  }) {
    return PlayerState(
      currentUrl: currentUrl ?? this.currentUrl,
      currentTitle: currentTitle ?? this.currentTitle,
      contentId: contentId ?? this.contentId,
      imdbId: imdbId ?? this.imdbId,
      sources: sources ?? this.sources,
      activeSourceIndex: activeSourceIndex ?? this.activeSourceIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isBuffering: isBuffering ?? this.isBuffering,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      subtitleTracks: subtitleTracks ?? this.subtitleTracks,
      activeSubtitleIndex: activeSubtitleIndex ?? this.activeSubtitleIndex,
      isFullScreen: isFullScreen ?? this.isFullScreen,
      showControls: showControls ?? this.showControls,
      isPip: isPip ?? this.isPip,
      error: error,
    );
  }
}

/// Player controller
class PlayerController extends StateNotifier<PlayerState> {
  final Ref _ref;
  late final Player _player;
  VideoController? _videoController;
  Timer? _positionTimer;

  PlayerController(this._ref)
      : _player = Player(),
        super(PlayerState()) {
    _videoController = VideoController(_player);
    _init();
  }

  void _init() {
    _player.stream.playing.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });

    _player.stream.buffering.listen((buffering) {
      state = state.copyWith(isBuffering: buffering);
    });

    _player.stream.position.listen((position) {
      state = state.copyWith(position: position);
    });

    _player.stream.duration.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    _player.stream.volume.listen((volume) {
      state = state.copyWith(volume: volume);
    });

    _player.stream.track.listen((track) {
      final subtitleIndex = track.subtitle.id.isEmpty 
          ? -1 
          : state.subtitleTracks.indexWhere((t) => t.id == track.subtitle.id);
      state = state.copyWith(activeSubtitleIndex: subtitleIndex);
    });
  }

  VideoController get videoController => _videoController!;

  Future<void> loadMedia(
    String url, {
    String? title,
    String? contentId,
    List<ExtractedLink>? sources,
  }) async {
    state = state.copyWith(
      currentUrl: url,
      currentTitle: title,
      contentId: contentId,
      sources: sources ?? [ExtractedLink(url: url, quality: 'auto')],
      activeSourceIndex: 0,
    );
    await _player.open(Media(url));
  }

  Future<void> addSources(List<ExtractedLink> newSources) async {
    final allSources = [...state.sources, ...newSources];
    state = state.copyWith(sources: allSources);
  }

  Future<void> initialize() async {
    // Initialize player
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> setPlaybackSpeed(double speed) => _player.setRate(speed);

  Future<void> toggleFullscreen() async {
    state = state.copyWith(isFullScreen: !state.isFullScreen);
  }

  Future<void> toggleControls() async {
    state = state.copyWith(showControls: !state.showControls);
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekForward() async {
    await seek(state.position + const Duration(seconds: 10));
  }

  Future<void> seekBackward() async {
    await seek(state.position - const Duration(seconds: 10));
  }

  Future<void> switchSource(int index) async {
    if (index >= 0 && index < state.sources.length) {
      final source = state.sources[index];
      state = state.copyWith(activeSourceIndex: index);
      await loadMedia(source.url);
    }
  }

  Future<void> togglePiP() async {
    state = state.copyWith(isPip: !state.isPip);
  }

  Future<void> setSubtitleTrack(int? index) async {
    if (index == null || index < 0) {
      // Disable subtitles - create empty track
      await _player.setSubtitleTrack(SubtitleTrack('', '', ''));
      state = state.copyWith(activeSubtitleIndex: -1);
    } else if (index >= 0 && index < state.subtitleTracks.length) {
      final track = state.subtitleTracks[index];
      await _player.setSubtitleTrack(track);
      state = state.copyWith(activeSubtitleIndex: index);
    }
  }

  Future<void> saveProgress() async {
    if (state.contentId == null) return;
    
    try {
      final db = _ref.read(appDatabaseProvider);
      // Upsert continue watching
    } catch (e) {
      // Database not available
    }
  }

  void _startPositionSaveTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      saveProgress();
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    saveProgress();
    _player.dispose();
    super.dispose();
  }
}
