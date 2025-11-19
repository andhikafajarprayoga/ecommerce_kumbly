import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import '../../../pages/buyer/product/product_detail_screen.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> chatRoom;
  final Map<String, dynamic> seller;
  final bool isAdminRoom;
  final Map<String, dynamic>? orderToConfirm;

  ChatDetailScreen({
    required this.chatRoom,
    required this.seller,
    this.isAdminRoom = false,
    this.orderToConfirm,
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

    // Tambahkan kode ini untuk menampilkan dialog konfirmasi order
    if (widget.orderToConfirm != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showOrderSendConfirmation(widget.orderToConfirm!);
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
                            child: _buildMessageItem(message),
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

  Widget _buildMessageItem(Map<String, dynamic> message) {
    final isMe = message['sender_id'] == supabase.auth.currentUser!.id;
    // Ambil field pesan sesuai tipe room
    final messageText = widget.isAdminRoom
        ? (message['content'] ?? '')
        : (message['message'] ?? '');

    // Cek apakah ini pesan gabungan (detail pesanan + produk)
    if (messageText.contains('Detail Pesanan:') &&
        messageText.contains('Produk dalam pesanan ini:')) {
      return _buildCombinedOrderMessage(messageText, isMe);
    }

    // Cek apakah ini pesan detail pesanan
    if (messageText.startsWith('Detail Pesanan:')) {
      return _buildOrderDetailMessage(messageText, isMe);
    }

    // Cek apakah ini pesan produk dalam pesanan
    if (messageText.startsWith('Produk dalam pesanan ini:')) {
      return _buildOrderProductsMessage(messageText, isMe);
    }

    // Cek apakah ini pesan produk tunggal (format lama)
    if (messageText.contains('<!--product_id:')) {
      return _buildSingleProductMessage(messageText, isMe);
    }

    // Jika bukan pesan khusus, tampilkan sebagai pesan biasa
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              messageText,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _formatTime(message['created_at']),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget untuk menampilkan pesan gabungan (detail pesanan + produk)
  Widget _buildCombinedOrderMessage(String messageText, bool isMe) {
    // Pisahkan bagian detail pesanan dan produk
    final parts = messageText.split('Produk dalam pesanan ini:');
    final orderDetailText = parts[0].trim();
    final productsText = 'Produk dalam pesanan ini:' + parts[1];

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bagian detail pesanan
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: orderDetailText.split('\n').map((line) {
                  return Text(
                    line,
                    style: TextStyle(
                      color: isMe ? Colors.white : Colors.black,
                      fontWeight: line.startsWith('Detail Pesanan:')
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  );
                }).toList(),
              ),
            ),

            // Garis pemisah
            Divider(color: isMe ? Colors.white30 : Colors.black12, height: 1),

            // Bagian produk
            _buildProductsSection(productsText, isMe),
          ],
        ),
      ),
    );
  }

  // Widget untuk menampilkan bagian produk dalam pesan gabungan
  Widget _buildProductsSection(String productsText, bool isMe) {
    // Pisahkan header dari konten produk
    final productParts = productsText.split('\n\n');
    final header = productParts[0]; // "Produk dalam pesanan ini:"

    // Pisahkan setiap produk berdasarkan pemisah "---"
    final productsContent = productParts.sublist(1).join('\n\n');
    final products = productsContent.split('\n---\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header produk
        Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            header,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : Colors.black,
            ),
          ),
        ),

        // Daftar produk
        ...products.map((productText) {
          final lines = productText.trim().split('\n');
          if (lines.length < 4) return SizedBox();

          final productName = lines[0];
          final productPrice = lines[1];
          final productIdLine = lines[2]; // <!--product_id:xxx-->
          final imageUrl = lines[3];

          // Ekstrak product_id dari line
          String productId = '';
          final idMatch =
              RegExp(r'<!--product_id:(.*?)-->').firstMatch(productIdLine);
          if (idMatch != null && idMatch.groupCount >= 1) {
            productId = idMatch.group(1) ?? '';
          }

          return Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: isMe ? Colors.white24 : Colors.black12, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar produk
                GestureDetector(
                  onTap: () {
                    if (productId.isNotEmpty) {
                      _navigateToProductDetail({'id': productId});
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                // Informasi produk
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isMe ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        productPrice,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // Widget untuk menampilkan pesan detail pesanan
  Widget _buildOrderDetailMessage(String messageText, bool isMe) {
    final lines = messageText.split('\n');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: lines.map((line) {
            return Text(
              line,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black,
                fontWeight: line.startsWith('Detail Pesanan:')
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Widget untuk menampilkan pesan dengan banyak produk
  Widget _buildOrderProductsMessage(String messageText, bool isMe) {
    // Pisahkan header dari konten produk
    final parts = messageText.split('\n\n');
    final header = parts[0]; // "Produk dalam pesanan ini:"

    // Pisahkan setiap produk berdasarkan pemisah "---"
    final productsText = parts.sublist(1).join('\n\n');
    final products = productsText.split('\n---\n');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        width: MediaQuery.of(context).size.width * 0.75,
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                header,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isMe ? Colors.white : Colors.black,
                ),
              ),
            ),

            // Daftar produk
            ...products.map((productText) {
              return _buildProductItem(productText.trim(), isMe);
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Widget untuk menampilkan item produk dalam pesan multi-produk
  Widget _buildProductItem(String productText, bool isMe) {
    final lines = productText.split('\n');
    if (lines.length < 4) return SizedBox(); // Skip jika format tidak sesuai

    final productName = lines[0];
    final productPrice = lines[1];
    final productIdLine = lines[2]; // <!--product_id:xxx-->
    final imageUrl = lines[3];

    // Ekstrak product_id dari line
    String productId = '';
    final idMatch =
        RegExp(r'<!--product_id:(.*?)-->').firstMatch(productIdLine);
    if (idMatch != null && idMatch.groupCount >= 1) {
      productId = idMatch.group(1) ?? '';
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
              color: isMe ? Colors.white24 : Colors.black12, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gambar produk
          GestureDetector(
            onTap: () {
              if (productId.isNotEmpty) {
                _navigateToProductDetail({'id': productId});
              }
            },
            child: Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Informasi produk
          Padding(
            padding: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isMe ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  productPrice,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget untuk menampilkan pesan produk tunggal (format lama)
  Widget _buildSingleProductMessage(String messageText, bool isMe) {
    final lines = messageText.split('\n');
    if (lines.length < 4) return SizedBox(); // Skip jika format tidak sesuai

    final productName = lines[0];
    final productPrice = lines[1];
    final productIdLine = lines[2]; // <!--product_id:xxx-->
    final imageUrl = lines[3];

    // Ekstrak product_id dari line
    String productId = '';
    final idMatch =
        RegExp(r'<!--product_id:(.*?)-->').firstMatch(productIdLine);
    if (idMatch != null && idMatch.groupCount >= 1) {
      productId = idMatch.group(1) ?? '';
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        width: 220,
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar produk
            GestureDetector(
              onTap: () {
                if (productId.isNotEmpty) {
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
                      child: Icon(Icons.image_not_supported),
                    );
                  },
                ),
              ),
            ),

            // Informasi produk
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMe ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    productPrice,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTime(DateTime.now().toIso8601String()),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMe ? Colors.white70 : Colors.grey,
                    ),
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
          'Tanyakan produk ini?',
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
              'Tanyakan produk ini ke penjual?',
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

  // Tambahkan fungsi untuk menampilkan dialog konfirmasi pesanan
  void _showOrderSendConfirmation(Map<String, dynamic> order) async {
    // Format total dengan aman
    String totalFormatted = '0';
    try {
      double totalAmount = 0;

      // Coba ambil total_amount
      if (order['total_amount'] != null) {
        totalAmount += double.tryParse(order['total_amount'].toString()) ?? 0;
      }

      // Coba ambil shipping_cost
      if (order['shipping_cost'] != null) {
        totalAmount += double.tryParse(order['shipping_cost'].toString()) ?? 0;
      }

      // Coba ambil admin_fee dari payment_group jika ada
      if (order['payment_group_id'] != null) {
        final paymentGroup = await supabase
            .from('payment_groups')
            .select()
            .eq('id', order['payment_group_id'])
            .maybeSingle();

        if (paymentGroup != null && paymentGroup['admin_fee'] != null) {
          totalAmount +=
              double.tryParse(paymentGroup['admin_fee'].toString()) ?? 0;
        }
      }

      // Format total
      totalFormatted = 'Rp ${NumberFormat('#,###').format(totalAmount)}';
    } catch (e) {
      print('Error calculating total payment: $e');
    }

    // Format tanggal dengan aman
    String dateFormatted = 'Tidak tersedia';
    try {
      if (order['created_at'] != null) {
        final date = DateTime.parse(order['created_at']);
        dateFormatted =
            '${date.day} ${_getMonthName(date.month)} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('Error formatting date: $e');
    }

    // Ambil informasi produk pertama untuk preview
    String productName = 'Produk';
    String productPrice = '';
    String productImage = '';

    try {
      if (order['order_items'] != null && order['order_items'].isNotEmpty) {
        final firstItem = order['order_items'][0];
        final product = firstItem['products'];

        if (product != null) {
          productName = product['name'] ?? 'Produk';

          // Ambil harga dari item order
          double price = 0;
          if (firstItem['price'] != null) {
            price = double.tryParse(firstItem['price'].toString()) ?? 0;
          } else if (product['price'] != null) {
            price = double.tryParse(product['price'].toString()) ?? 0;
          }

          productPrice = 'Rp ${NumberFormat('#,###').format(price)}';

          // Parse image URLs untuk mendapatkan gambar pertama
          if (product['image_url'] != null) {
            try {
              if (product['image_url'] is List) {
                productImage = product['image_url'][0];
              } else if (product['image_url'] is String) {
                final List<dynamic> urls = json.decode(product['image_url']);
                if (urls.isNotEmpty) {
                  productImage = urls.first;
                }
              }
            } catch (e) {
              print('Error parsing image URLs: $e');
            }
          }
        }
      }
    } catch (e) {
      print('Error getting product info: $e');
    }

    // Tampilkan dialog konfirmasi
    Get.dialog(
      AlertDialog(
        title: Text('Tanyakan Produk Ini?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detail Pesanan:'),
            Text('Order ID: ${_formatOrderId(order['id'])}'),
            Text('Status: ${order['status'] ?? 'Tidak tersedia'}'),
            Text('Total: $totalFormatted'),
            SizedBox(height: 12),
            Text('Produk dalam pesanan ini:'),
            SizedBox(height: 8),
            if (productImage.isNotEmpty)
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(productImage),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            SizedBox(height: 4),
            Text(productName,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            if (productPrice.isNotEmpty)
              Text(productPrice,
                  style: TextStyle(fontSize: 12, color: AppTheme.primary)),
            SizedBox(height: 8),
            Text(
              'Kirim dan tanyakan produk ini ke penjual?',
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
              _sendOrderMessage(order);
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

  // Helper function untuk format order ID
  String _formatOrderId(String id) {
    if (id.isEmpty) return 'Tidak tersedia';
    return '#${id.substring(0, math.min(id.length, 7))}';
  }

  // Helper function untuk mendapatkan nama bulan
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    return months[month - 1];
  }

  // Fungsi untuk mengirim pesan pesanan
  Future<void> _sendOrderMessage(Map<String, dynamic> order) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Format total dengan aman
      String totalFormatted = '0';
      try {
        double totalAmount = 0;

        // Coba ambil total_amount dan shipping_cost
        if (order['total_amount'] != null) {
          totalAmount += double.tryParse(order['total_amount'].toString()) ?? 0;
        }

        if (order['shipping_cost'] != null) {
          totalAmount +=
              double.tryParse(order['shipping_cost'].toString()) ?? 0;
        }

        // Coba ambil admin_fee dari payment_group jika ada
        if (order['payment_group_id'] != null) {
          final paymentGroup = await supabase
              .from('payment_groups')
              .select()
              .eq('id', order['payment_group_id'])
              .maybeSingle();

          if (paymentGroup != null && paymentGroup['admin_fee'] != null) {
            totalAmount +=
                double.tryParse(paymentGroup['admin_fee'].toString()) ?? 0;
          }
        }

        // Format total
        totalFormatted = 'Rp ${NumberFormat('#,###').format(totalAmount)}';
      } catch (e) {
        print('Error calculating total payment: $e');
      }

      // Format tanggal dengan aman
      String dateFormatted = 'Tidak tersedia';
      try {
        if (order['created_at'] != null) {
          final date = DateTime.parse(order['created_at']);
          dateFormatted =
              '${date.day} ${_getMonthName(date.month)} ${date.year}, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        }
      } catch (e) {
        print('Error formatting date: $e');
      }

      // Buat satu pesan yang berisi detail pesanan dan produk
      String completeMessage = "Detail Pesanan:\n";
      completeMessage += "Order ID: ${_formatOrderId(order['id'])}\n";
      completeMessage += "Status: ${order['status'] ?? 'Tidak tersedia'}\n";
      completeMessage += "Total: $totalFormatted\n";
      completeMessage += "Produk dalam pesanan ini:\n\n";

      // Ambil detail produk dari order
      final orderItems = order['order_items'] as List;

      // Untuk setiap item dalam pesanan, tambahkan ke pesan produk
      for (int i = 0; i < orderItems.length; i++) {
        final item = orderItems[i];
        final product = item['products'];

        // Parse image URLs untuk mendapatkan gambar pertama
        String firstImageUrl = '';
        if (product['image_url'] != null) {
          try {
            if (product['image_url'] is List) {
              firstImageUrl = product['image_url'][0];
            } else if (product['image_url'] is String) {
              final List<dynamic> urls = json.decode(product['image_url']);
              if (urls.isNotEmpty) {
                firstImageUrl = urls.first;
              }
            }
          } catch (e) {
            print('Error parsing image URLs: $e');
          }
        }

        // Ambil harga dari item order
        double price = 0;
        try {
          if (item['price'] != null) {
            price = double.tryParse(item['price'].toString()) ?? 0;
          } else if (product['price'] != null) {
            price = double.tryParse(product['price'].toString()) ?? 0;
          }
        } catch (e) {
          print('Error calculating price: $e');
        }

        // Format pesan produk
        String productInfo = '''
${product['name']}
Rp ${NumberFormat('#,###').format(price)}
<!--product_id:${product['id']}-->
$firstImageUrl
''';

        // Tambahkan ke pesan produk
        completeMessage += productInfo;

        // Tambahkan pemisah jika bukan produk terakhir
        if (i < orderItems.length - 1) {
          completeMessage += "\n---\n\n";
        }
      }

      // Kirim pesan lengkap dengan detail pesanan dan produk
      await supabase.from('chat_messages').insert({
        'room_id': widget.chatRoom['id'],
        'sender_id': userId,
        'message': completeMessage,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      _scrollToBottom();
    } catch (e) {
      print('Error sending order message: $e');
      Get.snackbar(
        'Gagal',
        'Tidak dapat mengirim detail pesanan: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    }
  }
}
