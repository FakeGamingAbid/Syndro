import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

/// Provider for RoomService
final roomServiceProvider = StateNotifierProvider<RoomService, RoomState>((ref) {
  return RoomService();
});

/// Sync event types
enum SyncEventType {
  play,
  pause,
  seek,
}

/// Sync event from other participants
class SyncEvent {
  final SyncEventType type;
  final Duration position;
  final String senderId;

  SyncEvent({
    required this.type,
    required this.position,
    required this.senderId,
  });
}

/// Chat message
class ChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
  });
}

/// Emoji reaction
class EmojiReaction {
  final String id;
  final String userId;
  final String emoji;
  final DateTime timestamp;

  EmojiReaction({
    required this.id,
    required this.userId,
    required this.emoji,
    required this.timestamp,
  });
}

/// Watch participant
class WatchParticipant {
  final String id;
  final String name;
  final int avatarMoonPhase;
  final bool isHost;

  WatchParticipant({
    required this.id,
    required this.name,
    required this.avatarMoonPhase,
    required this.isHost,
  });
}

/// Room session
class RoomSession {
  final String roomCode;
  final bool isHost;
  final List<WatchParticipant> participants;
  final String? videoUrl;
  final String? title;

  RoomSession({
    required this.roomCode,
    required this.isHost,
    required this.participants,
    this.videoUrl,
    this.title,
  });
}

/// Room state
class RoomState {
  final RoomSession? session;
  final bool isConnecting;
  final String? error;
  final List<ChatMessage> chatMessages;
  final List<EmojiReaction> reactions;
  final SyncEvent? lastSyncEvent;
  final bool isPlaying;

  RoomState({
    this.session,
    this.isConnecting = false,
    this.error,
    this.chatMessages = const [],
    this.reactions = const [],
    this.lastSyncEvent,
    this.isPlaying = false,
  });

  RoomState copyWith({
    RoomSession? session,
    bool? isConnecting,
    String? error,
    List<ChatMessage>? chatMessages,
    List<EmojiReaction>? reactions,
    SyncEvent? lastSyncEvent,
    bool? isPlaying,
  }) {
    return RoomState(
      session: session ?? this.session,
      isConnecting: isConnecting ?? this.isConnecting,
      error: error,
      chatMessages: chatMessages ?? this.chatMessages,
      reactions: reactions ?? this.reactions,
      lastSyncEvent: lastSyncEvent,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

/// Room service - manages Watch Together rooms via LiveKit
class RoomService extends StateNotifier<RoomState> {
  Room? _room;
  Participant? _localParticipant;
  StreamSubscription? _participantSubscription;
  StreamSubscription? _dataSubscription;

  RoomService() : super(RoomState());

  /// Generate a random 6-digit room code
  String _generateRoomCode() {
    final random = DateTime.now().millisecondsSinceEpoch % 1000000;
    return random.toString().padLeft(6, '0');
  }

  /// Create a new room as host
  Future<RoomSession?> createRoom({
    required String videoUrl,
    required String title,
    required String userName,
    int avatarMoonPhase = 0,
  }) async {
    state = state.copyWith(isConnecting: true, error: null);

    try {
      // In production, you'd connect to your LiveKit server
      // For demo, we'll simulate a local room
      final roomCode = _generateRoomCode();
      
      final session = RoomSession(
        roomCode: roomCode,
        isHost: true,
        participants: [
          WatchParticipant(
            id: 'local',
            name: userName,
            avatarMoonPhase: avatarMoonPhase,
            isHost: true,
          ),
        ],
        videoUrl: videoUrl,
        title: title,
      );

      state = state.copyWith(
        session: session,
        isConnecting: false,
      );

      return session;
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Join an existing room
  Future<RoomSession?> joinRoom({
    required String roomCode,
    required String userName,
    int avatarMoonPhase = 0,
  }) async {
    state = state.copyWith(isConnecting: true, error: null);

    try {
      // In production, connect to LiveKit with the room code
      // For demo, simulate joining
      final session = RoomSession(
        roomCode: roomCode,
        isHost: false,
        participants: [
          WatchParticipant(
            id: 'host',
            name: 'Host',
            avatarMoonPhase: 0,
            isHost: true,
          ),
          WatchParticipant(
            id: 'local',
            name: userName,
            avatarMoonPhase: avatarMoonPhase,
            isHost: false,
          ),
        ],
      );

      state = state.copyWith(
        session: session,
        isConnecting: false,
      );

      return session;
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Sync play event to all participants
  Future<void> syncPlay(Duration position) async {
    final event = SyncEvent(
      type: SyncEventType.play,
      position: position,
      senderId: 'local',
    );
    
    _broadcastSyncEvent(event);
    state = state.copyWith(isPlaying: true);
  }

  /// Sync pause event to all participants
  Future<void> syncPause(Duration position) async {
    final event = SyncEvent(
      type: SyncEventType.pause,
      position: position,
      senderId: 'local',
    );
    
    _broadcastSyncEvent(event);
    state = state.copyWith(isPlaying: false);
  }

  /// Sync seek event to all participants
  Future<void> syncSeek(Duration position) async {
    final event = SyncEvent(
      type: SyncEventType.seek,
      position: position,
      senderId: 'local',
    );
    
    _broadcastSyncEvent(event);
  }

  /// Broadcast sync event to all participants
  void _broadcastSyncEvent(SyncEvent event) {
    // In production, send via LiveKit data channel
    // For now, just update local state
    debugPrint('Broadcasting sync event: ${event.type} at ${event.position}');
  }

  /// Handle incoming sync event from other participant
  void handleSyncEvent(SyncEvent event) {
    state = state.copyWith(lastSyncEvent: event);
  }

  /// Send chat message
  Future<void> sendChatMessage(String message) async {
    final chatMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'local',
      userName: state.session?.participants
              .firstWhere((p) => p.id == 'local')
              .name ??
          'You',
      message: message,
      timestamp: DateTime.now(),
    );

    // Add to local messages
    final messages = [...state.chatMessages, chatMessage];
    state = state.copyWith(chatMessages: messages);

    // In production, broadcast via LiveKit
    _broadcastChatMessage(chatMessage);
  }

  /// Broadcast chat message to other participants
  void _broadcastChatMessage(ChatMessage message) {
    // In production, send via LiveKit data channel
  }

  /// Handle incoming chat message from other participant
  void handleChatMessage(ChatMessage message) {
    final messages = [...state.chatMessages, message];
    state = state.copyWith(chatMessages: messages);
  }

  /// Send emoji reaction
  Future<void> sendReaction(String emoji) async {
    final reaction = EmojiReaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: 'local',
      emoji: emoji,
      timestamp: DateTime.now(),
    );

    // Add to local reactions
    final reactions = [...state.reactions, reaction];
    state = state.copyWith(reactions: reactions);

    // Remove after animation
    Future.delayed(const Duration(seconds: 3), () {
      final updated = state.reactions.where((r) => r.id != reaction.id).toList();
      state = state.copyWith(reactions: updated);
    });

    // Broadcast
    _broadcastReaction(reaction);
  }

  /// Broadcast emoji reaction to other participants
  void _broadcastReaction(EmojiReaction reaction) {
    // In production, send via LiveKit data channel
  }

  /// Handle incoming emoji reaction from other participant
  void handleReaction(EmojiReaction reaction) {
    final reactions = [...state.reactions, reaction];
    state = state.copyWith(reactions: reactions);

    // Remove after animation
    Future.delayed(const Duration(seconds: 3), () {
      final updated = state.reactions.where((r) => r.id != reaction.id).toList();
      state = state.copyWith(reactions: updated);
    });
  }

  /// Leave the room
  Future<void> leaveRoom() async {
    // Cleanup
    _participantSubscription?.cancel();
    _dataSubscription?.cancel();
    await _room?.disconnect();

    state = RoomState();
  }

  @override
  void dispose() {
    leaveRoom();
    super.dispose();
  }
}
