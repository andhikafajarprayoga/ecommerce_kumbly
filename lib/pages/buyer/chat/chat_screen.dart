import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _chatRoomsStream;
  Map<String, Map<String, dynamic>> sellers = {};

  @override
  void initState() {
    super.initState();
    _initializeChatRooms();
  }

  void _initializeChatRooms() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _chatRoomsStream = supabase
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .eq('buyer_id', userId)
        .order('created_at', ascending: false)
        .execute()
        .asyncMap((rooms) async {
          for (var room in rooms) {
            final lastMessage = await supabase
                .from('chat_messages')
                .select('message')
                .eq('room_id', room['id'])
                .order('created_at', ascending: false)
                .limit(1)
                .single();
            room['last_message'] = lastMessage['message'];
          }
          return rooms;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatRoomsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_outlined, size: 44, color: AppTheme.textHint),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada chat',
                    style: TextStyle(color: AppTheme.textHint),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final room = snapshot.data![index];
              // Load seller info
              _loadSellerInfo(room['seller_id']);

              return _buildChatItem(
                chatRoom: room,
                seller: sellers[room['seller_id']] ??
                    {
                      'name': 'Loading...',
                      'image': 'https://via.placeholder.com/50'
                    },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _loadSellerInfo(String sellerId) async {
    if (!sellers.containsKey(sellerId)) {
      final seller = await _getUserInfo(sellerId);
      setState(() {
        sellers[sellerId] = seller;
      });
    }
  }

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    // Cek dulu di merchants
    final merchantResponse = await supabase
        .from('merchants')
        .select('id, store_name')
        .eq('id', userId)
        .maybeSingle();

    if (merchantResponse != null) {
      return {
        'name': merchantResponse['store_name'],
        'image': 'https://via.placeholder.com/50',
        'is_merchant': true
      };
    }

    // Kalau bukan merchant, ambil dari profiles
    final userResponse = await supabase
        .from('profiles')
        .select('id, full_name, avatar_url')
        .eq('id', userId)
        .single();

    return {
      'name': userResponse['full_name'],
      'image': userResponse['avatar_url'],
      'is_merchant': false
    };
  }

  Widget _buildChatItem({
    required Map<String, dynamic> chatRoom,
    required Map<String, dynamic> seller,
  }) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: () => Get.to(() => ChatDetailScreen(
              chatRoom: chatRoom,
              seller: seller,
            )),
        leading: CircleAvatar(
          backgroundImage:
              NetworkImage(seller['image'] ?? 'https://via.placeholder.com/50'),
          radius: 25,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                seller['name'] ?? 'User',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              _formatTime(chatRoom['last_message_time']),
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textHint,
              ),
            ),
          ],
        ),
        trailing:
            chatRoom['unread_count'] != null && chatRoom['unread_count'] > 0
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      chatRoom['unread_count'].toString(),
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  )
                : null,
      ),
    );
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    if (date.day == now.day) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }

  Future<int> _getUnreadCount(String roomId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await supabase.rpc('get_unread_count', params: {
      'room_id': roomId,
      'user_id': userId,
    });

    final count = response as int? ?? 0;
    return count;
  }
}
