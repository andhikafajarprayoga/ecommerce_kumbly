import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'package:kumbly_ecommerce/services/notification_service.dart';
import 'dart:math' as math;
import 'dart:convert' as json;
import 'package:intl/intl.dart';
import 'dart:convert';

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
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _isActive = true;
    _fetchMessages();
    _listenForNewMessages();

    // Tandai semua pesan sebagai telah dibaca saat membuka chat
    _markMessagesAsRead();
  }

  @override
  void dispose() {
    _isActive = false;
    super.dispose();
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
        .listen((data) async {
          _messages.assignAll(data);

          // Cek pesan baru yang belum dibaca
          final newMessages = data.where((msg) =>
              msg['sender_id'] != widget.currentUserId &&
              msg['is_read'] == false);

          // Tampilkan notifikasi hanya jika screen tidak aktif
          if (!_isActive) {
            for (var msg in newMessages) {
              final sender = await _supabase
                  .from('users')
                  .select('full_name')
                  .eq('id', msg['sender_id'])
                  .single();

              await NotificationService.showChatNotification(
                title: sender['full_name'] ?? 'Unknown User',
                body: msg['message'],
                roomId: widget.roomId,
                senderId: msg['sender_id'],
                messageId: msg['id'],
              );
            }
          }

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
    bool containsImageUrl = message.contains('http') &&
        (message.contains('.jpg') ||
            message.contains('.jpeg') ||
            message.contains('.png') ||
            message.contains('.gif'));

    String displayText = message;
    List<String> imageUrls = [];
    List<String> productIds = [];
    bool isOrderMessage = message.contains('Detail Pesanan:') &&
        message.contains('Produk dalam pesanan ini:');

    // Jika ini adalah pesan pesanan, ekstrak gambar dan ID produk
    if (isOrderMessage) {
      // Ambil bagian setelah "Produk dalam pesanan ini:"
      final parts = message.split('Produk dalam pesanan ini:');
      if (parts.length > 1) {
        final productsText = parts[1].trim();

        // Pisahkan masing-masing produk (dipisahkan oleh ---)
        final productSections = productsText.split('---');

        for (var section in productSections) {
          // Ekstrak URL gambar
          final urlMatch = RegExp(r'(https?:\/\/[^\s]+\.(jpg|jpeg|png|gif))')
              .firstMatch(section);
          if (urlMatch != null) {
            imageUrls.add(urlMatch.group(0)!);
          }

          // Ekstrak ID produk
          final productIdMatch =
              RegExp(r'<!--product_id:(.*?)-->').firstMatch(section);
          if (productIdMatch != null) {
            productIds.add(productIdMatch.group(1)!);
          }
        }
      }
    } else if (containsImageUrl) {
      // Untuk pesan biasa dengan gambar
      final urlMatch = RegExp(r'(https?:\/\/[^\s]+)').firstMatch(message);
      if (urlMatch != null) {
        imageUrls.add(urlMatch.group(0)!);
        displayText = displayText.replaceAll(urlMatch.group(0)!, '').trim();
      }

      // Extract product ID jika ada
      final productIdMatch =
          RegExp(r'<!--product_id:(.*?)-->').firstMatch(message);
      if (productIdMatch != null) {
        productIds.add(productIdMatch.group(1)!);
        displayText =
            displayText.replaceAll(productIdMatch.group(0)!, '').trim();
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
            // Tampilkan pesan teks
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOrderMessage) ...[
                    // Tampilkan detail pesanan
                    Text(
                      displayText.split('Produk dalam pesanan ini:')[0].trim(),
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Produk dalam pesanan ini:',
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ] else ...[
                    Text(
                      displayText.trim(),
                      style: TextStyle(
                        color: isMine ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Tampilkan gambar-gambar produk
            if (imageUrls.isNotEmpty && isOrderMessage) ...[
              for (int i = 0; i < imageUrls.length; i++) ...[
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(imageUrls[i]),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Ambil teks produk dari bagian pesan
                Builder(
                  builder: (context) {
                    final parts = message.split('Produk dalam pesanan ini:');
                    if (parts.length > 1) {
                      final productsText = parts[1].trim();
                      final productSections = productsText.split('---');

                      if (i < productSections.length) {
                        final section = productSections[i].trim();
                        final lines = section.split('\n');

                        // Filter baris yang berisi nama produk dan harga
                        final productInfo = lines
                            .where((line) =>
                                !line.contains('<!--product_id:') &&
                                !line.contains('http') &&
                                line.trim().isNotEmpty)
                            .toList();

                        return Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...productInfo
                                  .map((line) => Text(
                                        line.trim(),
                                        style: TextStyle(
                                          color: isMine
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 14,
                                          fontWeight: line.contains('Rp')
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ))
                                  .toList(),

                              // Tambahkan divider jika bukan produk terakhir
                              if (i < imageUrls.length - 1)
                                Divider(
                                    color: isMine
                                        ? Colors.white30
                                        : Colors.grey.shade300),
                            ],
                          ),
                        );
                      }
                    }
                    return SizedBox();
                  },
                ),
              ],
            ] else if (imageUrls.isNotEmpty) ...[
              // Untuk pesan biasa dengan gambar
              Container(
                width: double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(imageUrls[0]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],

            // Tampilkan waktu dan status baca
            Padding(
              padding: EdgeInsets.all(12),
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
        final paymentGroup = await _supabase
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

    // Siapkan list untuk menyimpan informasi produk
    List<Map<String, dynamic>> productInfoList = [];

    try {
      if (order['order_items'] != null && order['order_items'].isNotEmpty) {
        // Ambil maksimal 3 produk untuk ditampilkan
        final itemsToShow = order['order_items'].length > 3
            ? order['order_items'].sublist(0, 3)
            : order['order_items'];

        for (var item in itemsToShow) {
          final product = item['products'];
          if (product != null) {
            String productName = product['name'] ?? 'Produk';

            // Ambil harga dari item order
            double price = 0;
            if (item['price'] != null) {
              price = double.tryParse(item['price'].toString()) ?? 0;
            } else if (product['price'] != null) {
              price = double.tryParse(product['price'].toString()) ?? 0;
            }

            String productPrice = 'Rp ${NumberFormat('#,###').format(price)}';

            // Parse image URLs untuk mendapatkan gambar pertama
            String productImage = '';
            if (product['image_url'] != null) {
              try {
                final List<dynamic> urls = jsonDecode(product['image_url']);
                if (urls.isNotEmpty) {
                  productImage = urls.first;
                }
              } catch (e) {
                print('Error parsing image URLs: $e');
              }
            }

            productInfoList.add({
              'name': productName,
              'price': productPrice,
              'image': productImage,
            });
          }
        }
      }
    } catch (e) {
      print('Error getting product info: $e');
    }

    // Tampilkan dialog konfirmasi
    Get.dialog(
      AlertDialog(
        title: Text('Kirim Detail Pesanan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Detail Pesanan:'),
              Text('Order ID: ${_formatOrderId(order['id'])}'),
              Text('Status: ${order['status'] ?? 'Tidak tersedia'}'),
              Text('Total: $totalFormatted'),
              Text('Tanggal: $dateFormatted'),
              SizedBox(height: 12),
              Text('Produk dalam pesanan ini:'),
              SizedBox(height: 8),

              // Tampilkan semua produk yang sudah diambil
              ...productInfoList
                  .map((product) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product['image'].isNotEmpty)
                            Container(
                              height: 80,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(product['image']),
                                  fit: BoxFit.cover,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          SizedBox(height: 4),
                          Text(product['name'],
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(product['price'],
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.primary)),
                          SizedBox(height: 8),
                          if (productInfoList.last != product) Divider(),
                        ],
                      ))
                  .toList(),

              SizedBox(height: 8),
              if (order['order_items'].length > 3)
                Text(
                  '...dan ${order['order_items'].length - 3} produk lainnya',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              SizedBox(height: 12),
              Text(
                'Kirim detail pesanan ini ke penjual?',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
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
    try {
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
          totalAmount +=
              double.tryParse(order['shipping_cost'].toString()) ?? 0;
        }

        // Coba ambil admin_fee dari payment_group jika ada
        if (order['payment_group_id'] != null) {
          final paymentGroup = await _supabase
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
      completeMessage += "Tanggal: $dateFormatted\n\n";
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
            final List<dynamic> urls = jsonDecode(product['image_url']);
            if (urls.isNotEmpty) {
              firstImageUrl = urls.first;
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
      await _supabase.from('chat_messages').insert({
        'room_id': widget.roomId,
        'sender_id': widget.currentUserId,
        'message': completeMessage,
        'is_read': false,
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

  Future<void> _markMessagesAsRead() async {
    try {
      // Perbarui status is_read untuk semua pesan di room ini yang bukan dari pengguna saat ini
      await _supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('room_id', widget.roomId)
          .neq('sender_id', widget.currentUserId);

      print('Messages marked as read in room: ${widget.roomId}');
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
}
