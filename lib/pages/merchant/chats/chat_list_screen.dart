import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/chatrooms_controller.dart';
import 'package:kumbly_ecommerce/pages/merchant/chats/chat_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ChatListScreen extends StatefulWidget {
  final String sellerId;

  const ChatListScreen({super.key, required this.sellerId});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatController chatController = Get.put(ChatController());

  @override
  void initState() {
    super.initState();
    if (widget.sellerId.isNotEmpty) {
      chatController.fetchChatRooms(widget.sellerId);
      _listenForChatRoomUpdates();
      _listenForNewMessages();
    } else {
      Get.snackbar('Error', 'Invalid Seller ID');
    }
  }

  void _listenForChatRoomUpdates() {
    chatController.listenForChatRoomUpdates(widget.sellerId);
  }

  void _listenForNewMessages() {
    chatController.listenForNewMessages(widget.sellerId);
  }

  // Fungsi untuk menandai pesan sebagai telah dibaca
  Future<void> _markAsRead(String roomId) async {
    try {
      await supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('room_id', roomId)
          .eq('sender_id', widget.sellerId)
          .eq('is_read', false);

      // Refresh data chat
      chatController.fetchChatRooms(widget.sellerId);
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
      body: Obx(() {
        if (chatController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (chatController.chatList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  "Belum ada pesan",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: chatController.chatList.length,
          itemBuilder: (context, index) {
            var chat = chatController.chatList[index];
            final unreadCount = chat["unread_count"] ?? 0;
            final fullName = chat["buyer_name"] ?? "Unknown User";
            final initial =
                fullName.isNotEmpty ? fullName[0].toUpperCase() : "?";

            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  radius: 25,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
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
                          color:
                              unreadCount > 0 ? Colors.black : Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      _formatTimestamp(chat["last_message_time"]),
                      style: TextStyle(
                        fontSize: 12,
                        color: unreadCount > 0 ? Colors.blue : Colors.grey[600],
                        fontWeight: unreadCount > 0
                            ? FontWeight.bold
                            : FontWeight.normal,
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
                          color: unreadCount > 0
                              ? Colors.black87
                              : Colors.grey[600],
                          fontWeight: unreadCount > 0
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
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
                  // Tandai pesan sebagai telah dibaca saat chat dibuka
                  if (unreadCount > 0) {
                    await _markAsRead(chat["id"]);
                  }

                  Get.to(() => ChatDetailScreen(
                        userName: fullName,
                        roomId: chat["id"],
                        currentUserId: widget.sellerId,
                      ));
                },
              ),
            );
          },
        );
      }),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    final DateTime dateTime = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();

    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}';
  }
}
