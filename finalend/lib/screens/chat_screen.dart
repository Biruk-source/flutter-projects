import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

// --- Project Imports ---
import '../../models/chat_message.dart';
import '../../models/user.dart';
import '../../services/firebase_service.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId;
  final String otherUserId;
  final String? jobId; // Optional job context for the chat

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    this.jobId,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseService _firebaseService = FirebaseService();

  AppUser? _currentUser;
  AppUser? _otherUser;
  String? _chatRoomId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    _chatRoomId = _getChatRoomId(widget.currentUserId, widget.otherUserId);

    // Fetch profiles for both users in parallel for faster loading
    final results = await Future.wait([
      _firebaseService.getUser(widget.currentUserId),
      _firebaseService.getUser(widget.otherUserId),
    ]);

    if (mounted) {
      setState(() {
        _currentUser = results[0];
        _otherUser = results[1];
        _isLoading = false;
      });
    }
  }

  String _getChatRoomId(String userId1, String userId2) {
    if (userId1.hashCode <= userId2.hashCode) {
      return '$userId1\_$userId2';
    } else {
      return '$userId2\_$userId1';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _chatRoomId == null) return;

    final messageControllerCopy = TextEditingController(
      text: _messageController.text,
    );
    _messageController.clear();

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    try {
      final messageData = ChatMessage(
        id: '',
        senderId: widget.currentUserId,
        receiverId: widget.otherUserId,
        message: messageText,
        timestamp: DateTime.now(),
        isRead: false,
        jobId: widget.jobId,
      ).toJson();

      final chatRoomRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId);
      final messagesRef = chatRoomRef.collection('messages');

      WriteBatch batch = FirebaseFirestore.instance.batch();
      batch.set(messagesRef.doc(), messageData);
      batch.set(chatRoomRef, {
        'participants': [widget.currentUserId, widget.otherUserId],
        'lastMessage': messageText,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'lastMessageSenderId': widget.currentUserId,
        if (widget.jobId != null) 'jobId': widget.jobId,
      }, SetOptions(merge: true));
      await batch.commit();

      await _firebaseService.createNotification(
        userId: widget.otherUserId,
        title: _currentUser?.name ?? 'New Message',
        body: messageText,
        type: 'message_received',
        data: {
          'chatRoomId': _chatRoomId,
          'senderId': widget.currentUserId,
          'jobId': widget.jobId,
        },
      );
    } catch (e) {
      if (mounted) {
        _messageController.text = messageControllerCopy.text;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error sending message.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: _buildAppBar(theme),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildMessageInput(theme),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(ThemeData theme) {
    // CORRECTED: Add null checks for profileImage
    final profileImageUrl = _otherUser?.profileImage;
    final hasImage = profileImageUrl != null && profileImageUrl.isNotEmpty;

    return AppBar(
      elevation: 1,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      title: _isLoading || _otherUser == null
          ? const Text('Loading...')
          : Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: hasImage
                      ? CachedNetworkImageProvider(profileImageUrl)
                      : null,
                  child: !hasImage
                      ? Text(
                          _otherUser!.name.isNotEmpty
                              ? _otherUser!.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  _otherUser!.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_chatRoomId == null) {
      return const Center(child: Text('Could not initialize chat.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet.\nStart the conversation!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final messages = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return ChatMessage.fromJson(data);
        }).toList();

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isMe = message.senderId == widget.currentUserId;
            return _MessageBubble(message: message, isMe: isMe);
          },
        );
      },
    );
  }

  Widget _buildMessageInput(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              minLines: 1,
              maxLines: 5,
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
            icon: const Icon(Icons.send_rounded),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? theme.colorScheme.primary
                : theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe
                  ? const Radius.circular(20)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                message.message,
                style: TextStyle(
                  fontSize: 16,
                  color: isMe
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat.jm().format(message.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color:
                      (isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSecondaryContainer)
                          .withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
