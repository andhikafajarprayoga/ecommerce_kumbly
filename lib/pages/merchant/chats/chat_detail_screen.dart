import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  final String currentUserId;
  final String userName;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.userName,
  });

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final RxList<Map<String, dynamic>> _messages = <Map<String, dynamic>>[].obs;
  final ScrollController _scrollController = ScrollController();
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _listenForNewMessages();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      if (_isFirstLoad) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        _isFirstLoad = false;
      } else {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// Fetch existing messages from the database based on `room_id`
  Future<void> _fetchMessages() async {
    try {
      final roomExists = await _supabase
          .from('chat_rooms')
          .select('id')
          .eq('id', widget.roomId)
          .maybeSingle();

      if (roomExists == null) {
        Get.snackbar('Error', 'Chat room does not exist.');
        return;
      }

      final response = await _supabase
          .from('chat_messages')
          .select()
          .eq('room_id', widget.roomId)
          .order('created_at', ascending: true);

      _messages.assignAll(response);
      // Scroll ke bawah setelah pesan dimuat
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      print("Error fetching messages: $e");
    }
  }

  /// Listen for new messages in real-time
  void _listenForNewMessages() {
    _supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: true)
        .listen((data) {
          _messages.assignAll(data);
          // Scroll ke bawah setiap kali ada pesan baru
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _scrollToBottom());
        });
  }

  /// Send a new message
  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) return;

    final newMessage = {
      'room_id': widget.roomId,
      'sender_id': widget.currentUserId,
      'message': _messageController.text,
      'is_read': false,
    };

    try {
      await _supabase.from('chat_messages').insert(newMessage);
      _messageController.clear();
      // Scroll ke bawah setelah mengirim pesan
      _scrollToBottom();
    } catch (e) {
      print("Error sending message: $e");
    }
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
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          bottom: 8,
          left: isMine ? 50 : 0,
          right: isMine ? 0 : 50,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
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
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        isMine ? Colors.white.withOpacity(0.7) : Colors.black54,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppTheme.primary.withOpacity(0.1),
              child: Text(
                widget.userName.isNotEmpty
                    ? widget.userName[0].toUpperCase()
                    : "?",
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.userName,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              if (_messages.isEmpty) {
                return const Center(
                  child: Text('Belum ada pesan'),
                );
              }

              // Kelompokkan pesan berdasarkan tanggal
              final groupedMessages = <String, List<Map<String, dynamic>>>{};

              for (var message in _messages) {
                final date = DateTime.parse(message['created_at']).toLocal();
                final dateStr = _formatMessageDate(date);

                if (!groupedMessages.containsKey(dateStr)) {
                  groupedMessages[dateStr] = [];
                }
                groupedMessages[dateStr]!.add(message);
              }

              // Urutkan pesan dalam setiap grup
              for (var key in groupedMessages.keys) {
                groupedMessages[key]!.sort((a, b) =>
                    DateTime.parse(a['created_at'])
                        .compareTo(DateTime.parse(b['created_at'])));
              }

              // Urutkan keys berdasarkan tanggal terlama ke terbaru
              final sortedKeys = groupedMessages.keys.toList()
                ..sort((a, b) {
                  if (a == 'Hari ini') return 1;
                  if (b == 'Hari ini') return -1;
                  if (a == 'Kemarin') return 1;
                  if (b == 'Kemarin') return -1;
                  return a.compareTo(b);
                });

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: sortedKeys.length * 2,
                itemBuilder: (context, index) {
                  final int groupIndex = index ~/ 2;
                  if (groupIndex >= sortedKeys.length) return const SizedBox();

                  final dateStr = sortedKeys[groupIndex];

                  if (index.isEven) {
                    return _buildDateHeader(dateStr);
                  } else {
                    final messages = groupedMessages[dateStr]!;

                    return Column(
                      children: messages.map((message) {
                        final isCurrentUser =
                            message['sender_id'] == widget.currentUserId;
                        final DateTime dateTime =
                            DateTime.parse(message['created_at']).toLocal();
                        final String time =
                            '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

                        return _buildMessageBubble(
                          message: message['message'],
                          isMine: isCurrentUser,
                          time: time,
                          isRead: message['is_read'] ?? false,
                        );
                      }).toList(),
                    );
                  }
                },
              );
            }),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon:
                          const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            date,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String _formatMessageDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Hari ini';
    } else if (messageDate == yesterday) {
      return 'Kemarin';
    } else {
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }
}
