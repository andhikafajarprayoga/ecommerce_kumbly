import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../pages/buyer/chat/chat_detail_screen.dart';

class AdminChatScreen extends StatefulWidget {
  @override
  _AdminChatScreenState createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<AdminChatScreen> {
  final supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _chatRoomsStream;

  @override
  void initState() {
    super.initState();
    _initializeChatRooms();
  }

  void _initializeChatRooms() {
    _chatRoomsStream = supabase
        .from('admin_chat_rooms')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .map((rooms) async {
          List<Map<String, dynamic>> enrichedRooms = [];

          for (var room in rooms) {
            // Ambil data buyer
            final buyerData = await supabase
                .from('users')
                .select('email, full_name')
                .eq('id', room['buyer_id'])
                .single();

            // Ambil pesan terakhir
            final lastMessage = await supabase
                .from('admin_messages')
                .select('content, created_at, sender_id, is_read')
                .eq('chat_room_id', room['id'])
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            // Hitung pesan yang belum dibaca
            final unreadCount = await _getUnreadCount(room['id']);

            room['buyer_name'] = buyerData['full_name'] ?? buyerData['email'];
            room['last_message'] = lastMessage?['content'] ?? 'Belum ada pesan';
            room['last_message_time'] =
                lastMessage?['created_at'] ?? room['created_at'];
            room['unread_count'] = unreadCount;

            enrichedRooms.add(room);
          }
          return enrichedRooms;
        })
        .asyncMap((event) => event);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat dengan Buyer'),
        backgroundColor: AppTheme.primary,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatRoomsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final rooms = snapshot.data!;

          if (rooms.isEmpty) {
            return Center(child: Text('Belum ada chat'));
          }

          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      room['buyer_name'][0].toUpperCase(),
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(room['buyer_name']),
                  subtitle: Text(
                    room['last_message'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _formatTime(room['last_message_time']),
                        style: TextStyle(fontSize: 12),
                      ),
                      if (room['unread_count'] > 0)
                        Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            room['unread_count'].toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onTap: () => Get.to(() => ChatDetailScreen(
                        chatRoom: room,
                        seller: {'store_name': room['buyer_name']},
                        isAdminRoom: true,
                      )),
                ),
              );
            },
          );
        },
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
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    // Jika kemarin
    if (difference.inDays == 1) {
      return 'Kemarin';
    }

    // Jika dalam minggu ini (7 hari terakhir)
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

    // Jika lebih dari seminggu
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
