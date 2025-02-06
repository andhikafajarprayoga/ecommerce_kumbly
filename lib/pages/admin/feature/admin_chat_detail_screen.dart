import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:async';

class AdminChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chatRoom;
  final Map<String, dynamic> buyer;

  AdminChatDetailScreen({
    required this.chatRoom,
    required this.buyer,
  });

  @override
  _AdminChatDetailScreenState createState() => _AdminChatDetailScreenState();
}

class _AdminChatDetailScreenState extends State<AdminChatDetailScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final RxList<Map<String, dynamic>> _messages = <Map<String, dynamic>>[].obs;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _listenForNewMessages();
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _subscription?.cancel();
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

  Future<void> _fetchMessages() async {
    try {
      final response = await supabase
          .from('admin_messages')
          .select()
          .eq('chat_room_id', widget.chatRoom['id'])
          .order('created_at', ascending: true);

      _messages.assignAll(response);

      // Scroll ke bawah setelah pesan dimuat
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('Error fetching messages: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat pesan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _listenForNewMessages() {
    _subscription = supabase
        .from('admin_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_room_id', widget.chatRoom['id'])
        .order('created_at', ascending: true)
        .listen(
          (data) {
            _messages.assignAll(data);
            // Scroll ke bawah ketika ada pesan baru
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          },
          onError: (error) {
            print('Error in stream: $error');
            Get.snackbar(
              'Error',
              'Koneksi terputus, mencoba menghubungkan kembali...',
              backgroundColor: Colors.orange,
              colorText: Colors.white,
            );
          },
        );
  }

  Future<void> _markMessagesAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('admin_messages')
        .update({'is_read': true})
        .eq('chat_room_id', widget.chatRoom['id'])
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final messageContent = _messageController.text.trim();
    _messageController.clear();

    final newMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'chat_room_id': widget.chatRoom['id'],
      'sender_id': userId,
      'content': messageContent,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'is_read': false,
    };

    try {
      // Tambahkan pesan ke list
      _messages.add(newMessage);

      // Scroll ke bawah setelah menambahkan pesan
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      // Kirim ke database
      final response = await supabase.from('admin_messages').insert({
        'chat_room_id': widget.chatRoom['id'],
        'sender_id': userId,
        'content': messageContent,
        'created_at': newMessage['created_at'],
        'is_read': false,
      }).select();

      // Update messages list dengan data dari response
      if (response != null && response.isNotEmpty) {
        final index =
            _messages.indexWhere((msg) => msg['id'] == newMessage['id']);
        if (index != -1) {
          // Pilih salah satu metode:
          updateMessage1(index, response[0]);
          // atau
          // updateMessage2(index, response[0]);
          // atau
          // updateMessage3(index, response[0]);
        }
      }

      // Update waktu chat room
      await supabase
          .from('admin_chat_rooms')
          .update({'updated_at': newMessage['created_at']}).eq(
              'id', widget.chatRoom['id']);
    } catch (e) {
      print('Error sending message: $e');
      // Hapus pesan dari list jika gagal terkirim
      _messages.removeWhere((msg) => msg['id'] == newMessage['id']);
      Get.snackbar(
        'Error',
        'Gagal mengirim pesan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Metode 1: Menggunakan removeAt dan insert
  void updateMessage1(int index, Map<String, dynamic> newMessage) {
    _messages.removeAt(index);
    _messages.insert(index, newMessage);
  }

  // Metode 2: Menggunakan assignAll
  void updateMessage2(int index, Map<String, dynamic> newMessage) {
    final updatedMessages = List<Map<String, dynamic>>.from(_messages);
    updatedMessages[index] = newMessage;
    _messages.assignAll(updatedMessages);
  }

  // Metode 3: Menggunakan refresh
  void updateMessage3(int index, Map<String, dynamic> newMessage) {
    _messages[index] = newMessage;
    _messages.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatRoom['buyer_name'] ?? 'Chat'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('admin_messages')
                  .stream(primaryKey: ['id'])
                  .eq('chat_room_id', widget.chatRoom['id'])
                  .order('created_at', ascending: true)
                  .execute(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.active) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else if (snapshot.hasData) {
                    final messages = snapshot.data!;
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMine = message['sender_id'] ==
                            supabase.auth.currentUser?.id;
                        return _buildMessageBubble(
                          message: message['content'],
                          isMine: isMine,
                          time: _formatTime(message['created_at']),
                          isRead: message['is_read'] ?? false,
                        );
                      },
                    );
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                } else {
                  return Center(child: CircularProgressIndicator());
                }
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
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.send, color: AppTheme.primary),
            onPressed: () {
              _sendMessage();
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    // Jika hari ini
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      // Format: 14:30
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // Jika kemarin
    if (difference.inDays == 1) {
      return 'Kemarin ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // Jika dalam minggu ini
    if (difference.inDays < 7) {
      final List<String> days = [
        'Sen',
        'Sel',
        'Rab',
        'Kam',
        'Jum',
        'Sab',
        'Min'
      ];
      return '${days[date.weekday - 1]} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // Jika lebih dari seminggu
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
