import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/app_theme.dart';

class ChatRoomScreen extends StatefulWidget {
  final String roomId;
  final String otherUserId;
  final String hotelName;

  const ChatRoomScreen({
    Key? key,
    required this.roomId,
    required this.otherUserId,
    required this.hotelName,
  }) : super(key: key);

  @override
  _ChatRoomScreenState createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<Map<String, dynamic>>> _messagesStream;
  String? otherUserName;
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _setupMessagesStream();
    _fetchOtherUserName();
    _markMessagesAsRead();
  }

  void _setupMessagesStream() {
    _messagesStream = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', widget.roomId)
        .order('created_at', ascending: true)
        .map((List<Map<String, dynamic>> data) => data);
  }

  Future<void> _fetchOtherUserName() async {
    try {
      final response = await supabase
          .from('merchants')
          .select('store_name')
          .eq('id', widget.otherUserId)
          .maybeSingle();

      setState(() {
        otherUserName = response?['store_name'] ?? 'User';
      });
    } catch (e) {
      print('Error fetching other user name: $e');
      setState(() {
        otherUserName = 'User';
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('chat_messages')
        .update({'is_read': true})
        .eq('room_id', widget.roomId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await supabase.from('chat_messages').insert({
        'room_id': widget.roomId,
        'sender_id': supabase.auth.currentUser!.id,
        'message': _messageController.text.trim(),
        'is_read': false,
      });

      _messageController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengirim pesan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
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

  String _formatTime(String timestamp) {
    final date = DateTime.parse(timestamp);
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(otherUserName ?? 'Loading...'),
            Text(
              widget.hotelName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
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

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_isFirstLoad) {
                    _scrollToBottom();
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe =
                        message['sender_id'] == supabase.auth.currentUser!.id;

                    return _buildMessageBubble(
                      message: message['message'],
                      isMine: isMe,
                      time: _formatTime(message['created_at']),
                      isRead: message['is_read'] ?? false,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, -2),
                  blurRadius: 4,
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
                        borderRadius: BorderRadius.circular(24),
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
          ),
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
    if (message.contains('Detail Pesanan:') && message.contains('Order ID:')) {
      try {
        // Pisahkan bagian detail pesanan dan produk
        final parts = message.split('Produk dalam pesanan ini:');
        final orderDetailText = parts[0].trim();
        final productsText = parts.length > 1 ? parts[1].trim() : '';

        // Pisahkan setiap produk berdasarkan pemisah "---"
        final products = productsText
            .split('---')
            .where((p) => p.trim().isNotEmpty)
            .toList();

        print('Debug - Total produk: ${products.length}');

        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            width: MediaQuery.of(context).size.width * 0.75,
            decoration: BoxDecoration(
              color: isMine ? AppTheme.primary : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header section
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMine
                        ? AppTheme.primary.withOpacity(0.8)
                        : Colors.grey[300],
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: orderDetailText
                        .split('\n')
                        .where((line) => line.isNotEmpty)
                        .map((line) => Text(
                              line,
                              style: TextStyle(
                                color: isMine ? Colors.white : Colors.black87,
                                fontWeight: line.contains('Total:')
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ))
                        .toList(),
                  ),
                ),

                // Produk dalam pesanan
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Produk dalam pesanan ini:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMine ? Colors.white : Colors.black,
                    ),
                  ),
                ),

                // Products section
                ...products.map((product) {
                  final lines = product
                      .split('\n')
                      .map((line) => line.trim())
                      .where((line) => line.isNotEmpty)
                      .toList();

                  String? productName;
                  String? price;
                  String? imageUrl;

                  for (var line in lines) {
                    if (line.startsWith('Rp')) {
                      price = line;
                    } else if (line.startsWith('http')) {
                      imageUrl = line;
                    } else if (!line.contains('<!--') &&
                        !line.contains('product_id:')) {
                      productName = line;
                    }
                  }

                  if (productName == null || price == null) {
                    return Container();
                  }

                  return Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isMine ? Colors.white24 : Colors.grey[300]!,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (imageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.error,
                                      color: Colors.grey[500]),
                                );
                              },
                            ),
                          ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: TextStyle(
                                  color: isMine ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                price,
                                style: TextStyle(
                                  color: isMine ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                // Timestamp & Read Status
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
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
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        print('Error parsing order message: $e');
      }
    }

    // Cek apakah pesan mengandung URL gambar dan harga
    if (message.contains('https://') && message.contains('Rp')) {
      final parts = message.split('\n');
      String? imageUrl;
      String? price;

      for (var part in parts) {
        if (part.contains('https://')) {
          imageUrl = part.trim();
        } else if (part.contains('Rp')) {
          price = part.trim();
        }
      }

      return Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isMine ? AppTheme.primary : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    width: MediaQuery.of(context).size.width * 0.6,
                    height: 150,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 150,
                        width: MediaQuery.of(context).size.width * 0.6,
                        color: Colors.grey[200],
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                  ),
                ),
              if (price != null)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    price,
                    style: TextStyle(
                      color: isMine ? Colors.white : Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Row(
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
                        color: isMine ? Colors.white70 : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default message bubble untuk pesan biasa
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
