import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/chatrooms_controller.dart';
import 'package:kumbly_ecommerce/pages/merchant/chats/chat_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'package:rxdart/rxdart.dart' as rx;

final supabase = Supabase.instance.client;

class ChatListScreen extends StatefulWidget {
  final String sellerId;

  const ChatListScreen({super.key, required this.sellerId});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _chatRoomsStream;

  @override
  void initState() {
    super.initState();
    _initializeChatRooms();
  }

  void _initializeChatRooms() {
    if (widget.sellerId.isEmpty) {
      Get.snackbar('Error', 'Invalid Seller ID');
      return;
    }

    _chatRoomsStream = rx.Rx.combineLatest2(
      supabase.from('chat_messages').stream(primaryKey: ['id']).execute(),
      supabase
          .from('chat_rooms')
          .stream(primaryKey: ['id'])
          .eq('seller_id', widget.sellerId)
          .execute(),
      (List<Map<String, dynamic>> messages,
          List<Map<String, dynamic>> rooms) async {
        List<Map<String, dynamic>> validRooms = [];

        for (var room in rooms) {
          try {
            final buyerData = await supabase
                .from('users')
                .select('full_name')
                .eq('id', room['buyer_id'])
                .maybeSingle();

            room['buyer_name'] = buyerData?['full_name'] ?? 'Unknown User';

            // Hitung unread messages
            final unreadCount = messages
                .where((msg) =>
                    msg['room_id'] == room['id'] &&
                    !msg['is_read'] &&
                    msg['sender_id'] == room['buyer_id'])
                .length;

            room['unread_count'] = unreadCount;

            // Ambil pesan terakhir dan waktunya
            final lastMessage = messages
                .where((msg) => msg['room_id'] == room['id'])
                .toList()
              ..sort((a, b) => b['created_at'].compareTo(a['created_at']));

            if (lastMessage.isNotEmpty) {
              room['last_message'] = lastMessage.first['message'];
              room['last_message_time'] = lastMessage.first['created_at'];
            }

            validRooms.add(room);
          } catch (e) {
            print('Error processing chat room: $e');
          }
        }

        return validRooms;
      },
    ).asyncMap((event) => event);
  }

  Future<void> _markAsRead(String roomId, String buyerId) async {
    try {
      final result = await supabase
          .from('chat_messages')
          .update({'is_read': true}).match(
              {'room_id': roomId, 'sender_id': buyerId, 'is_read': false});

      // Refresh stream untuk memperbarui unread count
      setState(() {
        _initializeChatRooms();
      });
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          'Pesan',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatRoomsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "Belum ada pesan",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final chat = snapshot.data![index];
              return _buildChatItem(chat);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    final unreadCount = chat["unread_count"] ?? 0;
    final fullName = chat["buyer_name"] ?? "Unknown User";
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : "?";

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.1),
          radius: 25,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                fullName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: unreadCount > 0 ? Colors.black : Colors.black87,
                ),
              ),
            ),
            Text(
              _formatTimestamp(chat["last_message_time"] ?? chat["created_at"]),
              style: TextStyle(
                fontSize: 12,
                color: unreadCount > 0 ? AppTheme.primary : Colors.grey[600],
                fontWeight:
                    unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                chat["last_message"] ?? "Belum ada pesan",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: unreadCount > 0 ? Colors.black87 : Colors.grey[600],
                  fontWeight:
                      unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
            if (unreadCount > 0)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        onTap: () async {
          if (unreadCount > 0) {
            await _markAsRead(chat["id"], chat["buyer_id"]);
          }
          Get.to(() => ChatDetailScreen(
                userName: fullName,
                roomId: chat["id"],
                currentUserId: widget.sellerId,
              ));
        },
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    final DateTime dateTime = DateTime.parse(timestamp).toLocal();
    final DateTime now = DateTime.now();
    final difference = now.difference(dateTime);

    // Jika lebih dari seminggu yang lalu
    if (difference.inDays >= 7) {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
    }

    // Jika hari ini
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }

    // Jika kemarin
    final yesterday = now.subtract(const Duration(days: 1));
    if (dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day) {
      return 'Kemarin';
    }

    // Jika dalam minggu ini (kurang dari 7 hari)
    final List<String> days = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
    return days[dateTime.weekday % 7];
  }
}
