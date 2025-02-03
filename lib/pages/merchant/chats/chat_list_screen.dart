import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/chatrooms_controller.dart';
import 'package:kumbly_ecommerce/pages/merchant/chats/chat_detail_screen.dart';

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

            return Card(
              elevation: 0,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  radius: 25,
                  child: Text(
                    chat["buyer_id"].toString().substring(0, 1).toUpperCase(),
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
                        chat["buyer_id"] ?? "Unknown Buyer",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      _formatTimestamp(chat["last_message_time"]),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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
                          color: Colors.grey[600],
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
                          ),
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  Get.to(() => ChatDetailScreen(
                      userName: chat["buyer_id"],
                      roomId: chat["id"],
                      currentUserId: widget.sellerId));
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
