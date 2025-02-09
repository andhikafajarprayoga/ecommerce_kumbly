import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../pages/buyer/chat/chat_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'package:get/get.dart';

class AdminChatScreen extends StatefulWidget {
  @override
  _AdminChatScreenState createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final supabase = Supabase.instance.client;
  final RxList<Map<String, dynamic>> chatRooms = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _initializeChatRooms();
  }

  void _initializeChatRooms() {
    // Stream untuk chat rooms
    supabase
        .from('admin_chat_rooms')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .listen((List<Map<String, dynamic>> data) async {
          List<Map<String, dynamic>> enrichedRooms = [];

          for (var room in data) {
            try {
              // Ambil data buyer
              final buyerData = await supabase
                  .from('users')
                  .select('email, full_name')
                  .eq('id', room['buyer_id'])
                  .single();

              // Ambil pesan terakhir
              final lastMessage = await supabase
                  .from('admin_messages')
                  .select()
                  .eq('chat_room_id', room['id'])
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();

              // Hitung pesan yang belum dibaca
              final unreadCount = await _getUnreadCount(room['id']);

              room['buyer_name'] = buyerData['full_name'] ?? buyerData['email'];
              room['last_message'] =
                  lastMessage?['content'] ?? 'Belum ada pesan';
              room['last_message_time'] =
                  lastMessage?['created_at'] ?? room['created_at'];
              room['unread_count'] = unreadCount;

              enrichedRooms.add(room);
            } catch (e) {
              print('Error processing chat room: $e');
            }
          }

          // Update chatRooms list
          chatRooms.assignAll(enrichedRooms);
          isLoading.value = false;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat dengan Buyer'),
        backgroundColor: AppTheme.primary,
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
            setState(() {
              room['unread_count'] = 0;
            });

            Get.to(() => ChatDetailScreen(
                  chatRoom: room,
                  seller: {'store_name': room['buyer_name']},
                  isAdminRoom: true,
                ));
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                _buildAvatar(room['buyer_name']),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room['buyer_name'],
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
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('HH:mm').format(date);
    }

    if (difference.inDays == 1) {
      return 'Kemarin';
    }

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
      return days[date.weekday - 1];
    }

    return DateFormat('dd/MM').format(date);
  }
}
