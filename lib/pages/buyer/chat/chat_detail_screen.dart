import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chatRoom;
  final Map<String, dynamic> seller;

  ChatDetailScreen({
    required this.chatRoom,
    required this.seller,
  });

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  late Stream<List<Map<String, dynamic>>> _messagesStream;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeMessages();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeMessages() {
    _messagesStream = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.chatRoom['id'])
        .order('created_at', ascending: true)
        .map((List<Map<String, dynamic>> data) => data);
  }

  Future<void> _markMessagesAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('chat_messages')
        .update({'is_read': true})
        .eq('room_id', widget.chatRoom['id'])
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await supabase.from('chat_messages').insert({
        'room_id': widget.chatRoom['id'],
        'sender_id': userId,
        'message': _messageController.text,
        'created_at':
            DateTime.now().toUtc().add(Duration(hours: 7)).toIso8601String(),
      });

      FocusScope.of(context).unfocus(); // Menutup keyboard
      setState(() {
        _messageController.clear(); // Kosongkan input field
      });

      print("Message sent and input cleared"); // Log untuk debugging
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.seller['store_name'] ?? 'Chat'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    final isMine =
                        message['sender_id'] == supabase.auth.currentUser?.id;

                    return _buildMessageBubble(
                      message: message['message'],
                      isMine: isMine,
                      time: _formatTime(message['created_at']),
                      isRead: message['is_read'] ?? false,
                    );
                  },
                  controller: _scrollController,
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required bool isMine,
    required String time,
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
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
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

  String _formatTime(String timestamp) {
    final date = DateTime.parse(timestamp);
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
