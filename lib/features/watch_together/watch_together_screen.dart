import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/watch_together/room_service.dart';

/// Watch Together screen - synchronized video watching with chat
class WatchTogetherScreen extends ConsumerStatefulWidget {
  final String videoUrl;
  final String title;
  final String? imdbId;

  const WatchTogetherScreen({
    super.key,
    required this.videoUrl,
    required this.title,
    this.imdbId,
  });

  @override
  ConsumerState<WatchTogetherScreen> createState() => _WatchTogetherScreenState();
}

class _WatchTogetherScreenState extends ConsumerState<WatchTogetherScreen> {
  final _roomCodeController = TextEditingController();
  bool _isCreatingRoom = true;
  bool _isInRoom = false;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomServiceProvider);

    if (!_isInRoom) {
      return _buildJoinCreateScreen();
    }

    return _buildWatchTogetherScreen(roomState);
  }

  Widget _buildJoinCreateScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12121A),
        title: const Text(
          'Watch Together',
          style: TextStyle(color: Color(0xFFE8EDF2)),
        ),
      ),
      body: Column(
        children: [
          // Tab selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCreatingRoom = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isCreatingRoom
                            ? const Color(0xFF4A6FA5)
                            : const Color(0xFF2A3A50),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(8),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Create Room',
                          style: TextStyle(
                            color: _isCreatingRoom
                                ? Colors.white
                                : const Color(0xFF8B9BB0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCreatingRoom = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isCreatingRoom
                            ? const Color(0xFF4A6FA5)
                            : const Color(0xFF2A3A50),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(8),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Join Room',
                          style: TextStyle(
                            color: !_isCreatingRoom
                                ? Colors.white
                                : const Color(0xFF8B9BB0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isCreatingRoom
                ? _buildCreateRoomContent()
                : _buildJoinRoomContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRoomContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.movie_creation_outlined,
            color: Color(0xFF4A6FA5),
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'Create a Watch Together room',
            style: TextStyle(
              color: Color(0xFFE8EDF2),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Share the code with friends to watch together',
            style: TextStyle(
              color: Color(0xFF8B9BB0),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6FA5),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            ),
            onPressed: _createRoom,
            child: const Text(
              'Create Room',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinRoomContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.group_add_outlined,
            color: Color(0xFF4A6FA5),
            size: 80,
          ),
          const SizedBox(height: 24),
          const Text(
            'Join a Watch Together room',
            style: TextStyle(
              color: Color(0xFFE8EDF2),
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _roomCodeController,
            style: const TextStyle(color: Color(0xFFE8EDF2)),
            textAlign: TextAlign.center,
            maxLength: 6,
            decoration: InputDecoration(
              hintText: 'Enter 6-digit code',
              hintStyle: const TextStyle(color: Color(0xFF4A5568)),
              counterStyle: const TextStyle(color: Color(0xFF4A5568)),
              filled: true,
              fillColor: const Color(0xFF1A1A28),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A3A50)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A3A50)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4A6FA5)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6FA5),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
            ),
            onPressed: _joinRoom,
            child: const Text(
              'Join Room',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchTogetherScreen(RoomState roomState) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: isLandscape
            ? Row(
                children: [
                  // Video player area (placeholder)
                  Expanded(
                    flex: 3,
                    child: _buildVideoArea(roomState),
                  ),
                  // Chat sidebar
                  Container(
                    width: 300,
                    decoration: const BoxDecoration(
                      color: Color(0xFF12121A),
                      border: Border(
                        left: BorderSide(color: Color(0xFF2A3A50)),
                      ),
                    ),
                    child: _buildChatArea(roomState),
                  ),
                ],
              )
            : Column(
                children: [
                  // Video player area
                  Expanded(
                    flex: 2,
                    child: _buildVideoArea(roomState),
                  ),
                  // Chat area
                  Expanded(
                    flex: 3,
                    child: _buildChatArea(roomState),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildVideoArea(RoomState roomState) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Video placeholder
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Color(0xFF4A6FA5),
              size: 80,
            ),
          ),

          // Room code badge
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF4A6FA5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.share, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    roomState.session?.roomCode ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Participants
          Positioned(
            top: 16,
            right: 16,
            child: Row(
              children: (roomState.session?.participants ?? [])
                  .map((p) => _buildParticipantAvatar(p))
                  .toList(),
            ),
          ),

          // Emoji reactions
          ...roomState.reactions.map((r) => _buildEmojiReaction(r)),
        ],
      ),
    );
  }

  Widget _buildParticipantAvatar(WatchParticipant participant) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF4A6FA5),
        shape: BoxShape.circle,
        border: Border.all(
          color: participant.isHost ? const Color(0xFF4ECDC4) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          participant.name[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiReaction(EmojiReaction reaction) {
    return Positioned(
      bottom: 100,
      right: (reaction.id.hashCode % 200) + 50.0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(seconds: 3),
        builder: (context, value, child) {
          return Opacity(
            opacity: 1 - value,
            child: Transform.translate(
              offset: Offset(0, -50 * value),
              child: Text(
                reaction.emoji,
                style: const TextStyle(fontSize: 32),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatArea(RoomState roomState) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF2A3A50)),
            ),
          ),
          child: Row(
            children: [
              const Text(
                'Chat',
                style: TextStyle(
                  color: Color(0xFFE8EDF2),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF8B9BB0)),
                onPressed: () {
                  ref.read(roomServiceProvider.notifier).leaveRoom();
                  setState(() => _isInRoom = false);
                },
              ),
            ],
          ),
        ),

        // Messages
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roomState.chatMessages.length,
            itemBuilder: (context, index) {
              final message = roomState.chatMessages[index];
              return _buildChatMessage(message);
            },
          ),
        ),

        // Emoji reactions
        _buildEmojiBar(),

        // Input
        _buildChatInput(),
      ],
    );
  }

  Widget _buildChatMessage(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF4A6FA5),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                message.userName[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.userName,
                  style: const TextStyle(
                    color: Color(0xFF8B9BB0),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.message,
                  style: const TextStyle(
                    color: Color(0xFFE8EDF2),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['👍', '❤️', '😂', '😮', '👏', '🔥']
            .map((emoji) => GestureDetector(
                  onTap: () {
                    ref.read(roomServiceProvider.notifier).sendReaction(emoji);
                  },
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildChatInput() {
    final controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A28),
        border: Border(
          top: BorderSide(color: Color(0xFF2A3A50)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Color(0xFFE8EDF2)),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(color: Color(0xFF4A5568)),
                filled: true,
                fillColor: const Color(0xFF0A0A0F),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF4A6FA5)),
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(roomServiceProvider.notifier).sendChatMessage(controller.text);
                controller.clear();
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _createRoom() async {
    final roomService = ref.read(roomServiceProvider.notifier);
    final session = await roomService.createRoom(
      videoUrl: widget.videoUrl,
      title: widget.title,
      userName: 'User',
    );

    if (session != null && mounted) {
      setState(() => _isInRoom = true);
    }
  }

  Future<void> _joinRoom() async {
    final code = _roomCodeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit code'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
      return;
    }

    final roomService = ref.read(roomServiceProvider.notifier);
    final session = await roomService.joinRoom(
      roomCode: code,
      userName: 'User',
    );

    if (session != null && mounted) {
      setState(() => _isInRoom = true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to join room. Check the code and try again.'),
          backgroundColor: Color(0xFFFF6B6B),
        ),
      );
    }
  }
}
