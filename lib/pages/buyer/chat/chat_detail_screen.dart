import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../../../pages/buyer/product/product_detail_screen.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chatRoom;
  final Map<String, dynamic> seller;
  final bool isAdminRoom;

  ChatDetailScreen({
    required this.chatRoom,
    required this.seller,
    this.isAdminRoom = false,
  });

  @override
  _ChatDetailScreenState createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  late Stream<List<Map<String, dynamic>>> _messagesStream;
  final ScrollController _scrollController = ScrollController();
  bool _isFirstLoad = true;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeMessages();
    _markMessagesAsRead();

    // Cek apakah ada data produk yang perlu ditampilkan untuk konfirmasi
    if (Get.arguments != null && Get.arguments['productToSend'] != null) {
      final productData = Get.arguments['productToSend'];
      // Tampilkan dialog konfirmasi setelah widget selesai build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showProductSendConfirmation(productData);
      });
    }

    // Pastikan untuk menggulir ke bawah setelah pesan dimuat
    _scrollToBottom();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeMessages() {
    if (widget.isAdminRoom) {
      _messagesStream = supabase
          .from('admin_messages')
          .stream(primaryKey: ['id'])
          .eq('chat_room_id', widget.chatRoom['id'])
          .order('created_at', ascending: true)
          .map((List<Map<String, dynamic>> data) => data);
    } else {
      _messagesStream = supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .eq('room_id', widget.chatRoom['id'])
          .order('created_at', ascending: true)
          .map((List<Map<String, dynamic>> data) => data);
    }
  }

  Future<void> _markMessagesAsRead() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (widget.isAdminRoom) {
        final response = await supabase
            .from('admin_messages')
            .update({'is_read': true})
            .eq('chat_room_id', widget.chatRoom['id'])
            .neq('sender_id', userId)
            .eq('is_read', false);

        print('Update admin messages response: $response');

        // Verifikasi update berhasil
        final updatedMessages = await supabase
            .from('admin_messages')
            .select()
            .eq('chat_room_id', widget.chatRoom['id'])
            .eq('is_read', false);

        print('Messages still unread: ${updatedMessages.length}');
      } else {
        await supabase
            .from('chat_messages')
            .update({'is_read': true})
            .eq('room_id', widget.chatRoom['id'])
            .neq('sender_id', userId)
            .eq('is_read', false);
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final messageContent = _messageController.text;
    _messageController.clear();
    FocusScope.of(context).unfocus();

    try {
      if (widget.isAdminRoom) {
        await supabase.from('admin_messages').insert({
          'chat_room_id': widget.chatRoom['id'],
          'sender_id': userId,
          'content': messageContent,
          'is_read': false,
        }).select();

        // Update last_message di admin_chat_rooms
        await supabase.from('admin_chat_rooms').update({
          'last_message': messageContent,
          'last_message_time': DateTime.now().toIso8601String(),
          'last_message_sender_id': userId
        }).eq('id', widget.chatRoom['id']);
      } else {
        await supabase.from('chat_messages').insert({
          'room_id': widget.chatRoom['id'],
          'sender_id': userId,
          'message': messageContent,
          'is_read': false,
        });
      }

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel', // channel id
      'Chat Notifications', // channel name
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(''),
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
      payload: 'chat_detail',
    );
  }

  // Fungsi helper untuk scroll ke bawah
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.seller['store_name'] ?? 'Chat',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
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

                // Kelompokkan pesan berdasarkan tanggal
                final groupedMessages = <String, List<Map<String, dynamic>>>{};

                for (var message in messages) {
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
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                return ListView.builder(
                  controller: _scrollController,
                  itemCount: sortedKeys.length * 2,
                  itemBuilder: (context, index) {
                    final int groupIndex = index ~/ 2;
                    if (groupIndex >= sortedKeys.length)
                      return const SizedBox();

                    final dateStr = sortedKeys[groupIndex];

                    if (index.isEven) {
                      return _buildDateHeader(dateStr);
                    } else {
                      final messages = groupedMessages[dateStr]!;

                      return Column(
                        children: messages.asMap().entries.map((entry) {
                          final int msgIndex = entry.key;
                          final message = entry.value;
                          final isCurrentUser = message['sender_id'] ==
                              supabase.auth.currentUser?.id;
                          final String time =
                              _formatTime(message['created_at']);

                          return Container(
                            key: msgIndex == messages.length - 1
                                ? Key("lastMessage")
                                : null, // Tambahkan key
                            child: _buildMessageBubble(
                              message: widget.isAdminRoom
                                  ? message['content']
                                  : message['message'],
                              isMine: isCurrentUser,
                              time: time,
                              isRead: message['is_read'] ?? false,
                            ),
                          );
                        }).toList(),
                      );
                    }
                  },
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
    bool containsImageUrl = message.contains('http') &&
        (message.contains('.jpg') ||
            message.contains('.jpeg') ||
            message.contains('.png') ||
            message.contains('.gif'));

    String displayText = message;
    String? imageUrl;
    String? productId;

    // Extract dan sembunyikan product ID dari pesan
    final productIdMatch =
        RegExp(r'<!--product_id:(.*?)-->').firstMatch(message);
    if (productIdMatch != null) {
      productId = productIdMatch.group(1);
      // Hapus product ID dari tampilan pesan
      displayText = message.replaceAll(productIdMatch.group(0)!, '').trim();
    }

    if (containsImageUrl) {
      final urlMatch = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(message);
      if (urlMatch != null) {
        imageUrl = urlMatch.group(0);
        displayText = displayText.replaceAll(imageUrl!, '').trim();
      }
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl != null)
              GestureDetector(
                onTap: () {
                  if (productId != null) {
                    _navigateToProductDetail({'id': productId});
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 150,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: Icon(Icons.error_outline, size: 20),
                      );
                    },
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (displayText.isNotEmpty) ...[
                    Text(
                      displayText.trim(),
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 4),
                  ],
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
              textInputAction: TextInputAction.send,
              onEditingComplete: () {
                _sendMessage();
              },
              keyboardType: TextInputType.multiline,
              maxLines: 1,
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

  String _formatTime(String timestamp) {
    final date = DateTime.parse(timestamp);
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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

  // Tambahkan fungsi untuk navigasi ke detail produk
  void _navigateToProductDetail(Map<String, dynamic> productData) async {
    try {
      // Ambil detail produk dari database
      final product = await supabase
          .from('products')
          .select()
          .eq('id', productData['id'])
          .single();

      // Navigasi ke halaman detail produk
      Get.to(() => ProductDetailScreen(product: product));
    } catch (e) {
      print('Error navigating to product detail: $e');
      Get.snackbar(
        'Error',
        'Tidak dapat membuka detail produk',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Tambahkan fungsi untuk menampilkan dialog konfirmasi
  void _showProductSendConfirmation(Map<String, dynamic> product) {
    // Parse image URLs untuk mendapatkan gambar pertama
    String firstImageUrl = '';
    if (product['image_url'] != null) {
      try {
        if (product['image_url'] is List) {
          firstImageUrl = product['image_url'][0];
        } else if (product['image_url'] is String) {
          final List<dynamic> urls = json.decode(product['image_url']);
          firstImageUrl = urls.first;
        }
      } catch (e) {
        print('Error parsing image URLs: $e');
      }
    }

    Get.dialog(
      AlertDialog(
        title: Text(
          'Kirim Informasi Produk',
          style: TextStyle(fontSize: 16),
        ),
        contentPadding: EdgeInsets.all(12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (firstImageUrl.isNotEmpty)
              Container(
                height: 80, // Ukuran lebih kecil
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(firstImageUrl),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            SizedBox(height: 8), // Jarak lebih kecil
            Text(
              product['name'],
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2), // Jarak lebih kecil
            Text(
              'Rp ${NumberFormat('#,###').format(product['price'])}',
              style: TextStyle(color: AppTheme.primary, fontSize: 13),
            ),
            SizedBox(height: 8), // Jarak lebih kecil
            Text(
              'Kirim informasi produk ini ke penjual?',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _sendProductMessage(product);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size(60, 30),
            ),
            child: Text('Kirim', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  // Fungsi untuk mengirim pesan produk
  Future<void> _sendProductMessage(Map<String, dynamic> product) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Parse image URLs untuk mendapatkan gambar pertama
    String firstImageUrl = '';
    if (product['image_url'] != null) {
      try {
        if (product['image_url'] is List) {
          firstImageUrl = product['image_url'][0];
        } else if (product['image_url'] is String) {
          final List<dynamic> urls = json.decode(product['image_url']);
          firstImageUrl = urls.first;
        }
      } catch (e) {
        print('Error parsing image URLs: $e');
      }
    }

    // Format pesan produk
    String productMessage = '''
${product['name']}
Rp ${NumberFormat('#,###').format(product['price'])}
<!--product_id:${product['id']}-->
$firstImageUrl
''';

    try {
      // Kirim pesan dengan informasi produk
      await supabase.from('chat_messages').insert({
        'room_id': widget.chatRoom['id'],
        'sender_id': userId,
        'message': productMessage,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending product message: $e');
    }
  }
}
