import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class MessageGroup {
  final DateTime date;
  final List<Map<String, dynamic>> messages;

  MessageGroup(this.date, this.messages);
}

class MerchantAdminChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chatRoom;

  const MerchantAdminChatDetailScreen({
    required this.chatRoom,
  });

  @override
  _MerchantAdminChatDetailScreenState createState() =>
      _MerchantAdminChatDetailScreenState();
}

class _MerchantAdminChatDetailScreenState
    extends State<MerchantAdminChatDetailScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;
  final ScrollController _scrollController = ScrollController();
  final isLoading = true.obs;
  StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMessages();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _initializeMessages() async {
    print('\nDEBUG: Initializing chat with admin...');
    print('  - Room ID: ${widget.chatRoom['id']}');
    print('  - Admin ID: 177a4777-87aa-47a5-95c6-6410c41706cf');

    final data = await supabase
        .from('admin_messages')
        .select()
        .eq('chat_room_id', widget.chatRoom['id'])
        .order('created_at', ascending: true);

    print('DEBUG: Found ${data.length} messages');

    messages.assignAll(data);
    isLoading.value = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    _messagesSubscription = supabase
        .from('admin_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_room_id', widget.chatRoom['id'])
        .order('created_at', ascending: true)
        .listen(
          (data) {
            print('\nDEBUG: New message received');
            print('  - Number of messages: ${data.length}');
            messages.assignAll(data);

            if (data.length > messages.length) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _scrollToBottom();
              });
            }
          },
          onError: (error) {
            print('ERROR: Message stream error: $error');
          },
        );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final messageContent = _messageController.text.trim();
    _messageController.clear();

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    print('\nDEBUG: Sending message to admin:');
    print('  - Content: $messageContent');
    print('  - Sender ID (Merchant): $userId');
    print('  - Room ID: ${widget.chatRoom['id']}');

    // Update UI immediately
    messages.add({
      'chat_room_id': widget.chatRoom['id'],
      'sender_id': userId,
      'content': messageContent,
      'is_read': false,
    });

    // Scroll ke pesan baru
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // Kirim ke table admin_messages
    unawaited(supabase.from('admin_messages').insert({
      'chat_room_id': widget.chatRoom['id'],
      'sender_id': userId,
      'content': messageContent,
      'is_read': false,
    }).then((_) {
      print('DEBUG: Message sent to admin successfully');
    }).catchError((error) {
      print('ERROR: Failed to send message: $error');
    }));
  }

  Future<void> _markMessagesAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('admin_messages')
        .update({'is_read': true})
        .eq('chat_room_id', widget.chatRoom['id'])
        .eq('sender_id', '177a4777-87aa-47a5-95c6-6410c41706cf')
        .eq('is_read', false);
  }

  List<MessageGroup> _groupMessagesByDate(List<Map<String, dynamic>> messages) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));

    for (var message in messages) {
      final createdAt = message['created_at'];
      DateTime messageDate;

      if (createdAt == null) {
        messageDate = today;
      } else {
        messageDate = DateTime.parse(createdAt);
      }

      final date =
          DateTime(messageDate.year, messageDate.month, messageDate.day);

      String key;
      if (date == today) {
        key = 'today';
      } else if (date == yesterday) {
        key = 'yesterday';
      } else {
        key = '${date.year}-${date.month}-${date.day}';
      }

      if (!groups.containsKey(key)) {
        groups[key] = [];
      }
      groups[key]!.add(message);
    }

    return groups.entries.map((entry) {
      DateTime date;
      if (entry.key == 'today') {
        date = today;
      } else if (entry.key == 'yesterday') {
        date = yesterday;
      } else {
        final parts = entry.key.split('-');
        date = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
      return MessageGroup(date, entry.value);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat with Admin'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }

              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'Belum ada pesan',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                );
              }

              final groupedMessages = _groupMessagesByDate(messages);

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: groupedMessages.length,
                itemBuilder: (context, index) {
                  final group = groupedMessages[index];
                  return Column(
                    children: [
                      _buildDateHeader(group.date),
                      ...group.messages.map((message) {
                        final isMine = message['sender_id'] ==
                            supabase.auth.currentUser?.id;
                        return _buildMessageBubble(
                          message: message['content'],
                          isMine: isMine,
                          time: message['created_at'],
                          isRead: message['is_read'] ?? false,
                        );
                      }).toList(),
                    ],
                  );
                },
              );
            }),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    String headerText;
    if (messageDate == today) {
      headerText = 'Hari Ini';
    } else if (messageDate == yesterday) {
      headerText = 'Kemarin';
    } else {
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year;
      headerText = '$day/$month/$year';
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            headerText,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isMine,
    String? time,
    required bool isRead,
  }) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatMessageTime(time),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine ? Colors.white70 : Colors.grey,
                  ),
                ),
                if (isMine) ...[
                  SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Tulis pesan...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send, color: AppTheme.primary),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(String? timestamp) {
    try {
      if (timestamp == null) return '';

      final date = DateTime.parse(timestamp);
      print('DEBUG: Formatting time:');
      print('  - Original: $timestamp');

      final hours = date.hour.toString().padLeft(2, '0');
      final minutes = date.minute.toString().padLeft(2, '0');
      return '$hours:$minutes';
    } catch (e) {
      print('ERROR: Failed to format time: $e');
      return '';
    }
  }
}
