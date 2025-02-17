import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/admin/feature/admin_chat_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../pages/buyer/chat/chat_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'package:get/get.dart';
import 'dart:async';
import '../../../services/notification_service.dart';
import '../../../services/chat_service.dart';

class AdminChatScreen extends StatefulWidget {
  @override
  _AdminChatScreenState createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final supabase = Supabase.instance.client;
  final RxList<Map<String, dynamic>> chatRooms = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  StreamSubscription? _roomsSubscription;
  final _chatService = ChatService();

  @override
  void initState() {
    super.initState();
    _initializeChatRooms();
    _chatService.initializeMessageListener();
  }

  @override
  void dispose() {
    _roomsSubscription?.cancel();
    super.dispose();
  }

  void _initializeChatRooms() async {
    // Initial fetch
    final data = await supabase
        .from('admin_chat_rooms')
        .select()
        .order('updated_at', ascending: false);

    await _enrichRooms(data);

    // Listen to room updates
    _roomsSubscription = supabase
        .from('admin_chat_rooms')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .listen(
          (data) async {
            print(
                'DEBUG: Room stream update received with ${data.length} rooms');
            await _enrichRooms(data);
          },
          onError: (error) {
            print('ERROR: Room stream error: $error');
          },
        );
  }

  Future<void> _enrichRooms(List<Map<String, dynamic>> rooms) async {
    List<Map<String, dynamic>> enrichedRooms = [];

    for (var room in rooms) {
      try {
        // Get buyer data
        final buyerData = await supabase
            .from('users')
            .select('email, full_name')
            .eq('id', room['buyer_id'])
            .single();

        // Get last message dengan query yang sama seperti di chat detail
        final lastMessages = await supabase
            .from('admin_messages')
            .select()
            .eq('chat_room_id', room['id'])
            .order('created_at',
                ascending: true); // Ubah ke true untuk konsistensi

        final lastMessage = lastMessages.isNotEmpty
            ? lastMessages.last
            : null; // Gunakan last karena ascending
        final unreadCount = await _getUnreadCount(room['id']);

        enrichedRooms.add({
          ...room,
          'buyer_name': buyerData['full_name'] ?? buyerData['email'],
          'last_message': lastMessage?['content'] ?? 'Belum ada pesan',
          'last_message_time': lastMessage?['created_at'] ?? room['created_at'],
          'unread_count': unreadCount,
        });
      } catch (e) {
        print('ERROR processing room ${room['id']}: $e');
      }
    }

    chatRooms.assignAll(enrichedRooms);
    isLoading.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chat',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (isLoading.value) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
            ),
          );
        }

        if (chatRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Belum ada percakapan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: chatRooms.length,
          itemBuilder: (context, index) {
            final room = chatRooms[index];
            return _buildChatItem(room);
          },
        );
      }),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> room) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Mark messages as read
            await supabase
                .from('admin_messages')
                .update({'is_read': true})
                .eq('chat_room_id', room['id'])
                .neq('sender_id', supabase.auth.currentUser!.id)
                .eq('is_read', false);

            // Reset unread count
            final updatedRoom = {...room, 'unread_count': 0};
            final index = chatRooms.indexWhere((r) => r['id'] == room['id']);
            if (index != -1) {
              chatRooms[index] = updatedRoom;
              chatRooms.refresh();
            }

            // Navigate to chat detail
            await Get.to(() => AdminChatDetailScreen(
                  chatRoom: updatedRoom,
                  buyer: room['buyer_name'] ?? 'Chat',
                ));

            // Refresh data setelah kembali dari chat detail
            final lastMessage = await supabase
                .from('admin_messages')
                .select()
                .eq('chat_room_id', room['id'])
                .order('created_at', ascending: false)
                .limit(1)
                .single();

            if (index != -1) {
              chatRooms[index] = {
                ...chatRooms[index],
                'last_message': lastMessage['content'],
                'last_message_time': lastMessage['created_at'],
                'unread_count': 0,
              };
              chatRooms.refresh();
            }
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(room['buyer_name'] ?? 'Unknown'),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room['buyer_name'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        room['last_message'] ?? 'Belum ada pesan',
                        style: TextStyle(
                          color: room['unread_count'] > 0
                              ? Colors.black
                              : Colors.grey[600],
                          fontWeight: room['unread_count'] > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(
                          room['last_message_time'] ?? room['created_at']),
                      style: TextStyle(
                        fontSize: 12,
                        color: room['unread_count'] > 0
                            ? AppTheme.primary
                            : Colors.grey[600],
                      ),
                    ),
                    if (room['unread_count'] > 0) ...[
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${room['unread_count']}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String name) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withOpacity(0.8),
            AppTheme.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          name.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<int> _getUnreadCount(String roomId) async {
    final response = await supabase
        .from('admin_messages')
        .select()
        .eq('chat_room_id', roomId)
        .eq('is_read', false)
        .neq('sender_id', supabase.auth.currentUser!.id);

    return response.length;
  }

  String _formatTime(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(date.year, date.month, date.day);

      if (messageDate == today) {
        return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      }

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return DateFormat('HH:mm').format(date);
      }

      if (date.difference(now).inDays == 1) {
        return 'Kemarin';
      }

      if (date.difference(now).inDays < 7) {
        final List<String> days = [
          'Sen',
          'Sel',
          'Rab',
          'Kam',
          'Jum',
          'Sab',
          'Min'
        ];
        return days[date.weekday - 1];
      }

      return DateFormat('dd/MM').format(date);
    } catch (e) {
      print('ERROR: Failed to format time: $e');
      return '';
    }
  }
}
