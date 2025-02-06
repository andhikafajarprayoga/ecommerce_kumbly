import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  final RxBool isLoading = false.obs;
  final RxList<Map<String, dynamic>> chatList = <Map<String, dynamic>>[].obs;

  Future<void> fetchChatRooms(String sellerId) async {
    try {
      isLoading(true);

      final response = await _supabase
          .from('chat_rooms')
          .select('''
            id,
            seller_id,
            buyer_id,
            created_at,
            last_message_time
          ''')
          .eq('seller_id', sellerId)
          .order('last_message_time', ascending: false);

      final transformedResponse = await Future.wait(
        response.map((room) async {
          try {
            final buyerProfile = await _supabase
                .from('users')
                .select('full_name, email')
                .eq('id', room['buyer_id'])
                .single();

            // Ambil pesan terakhir dan hitung unread messages
            final lastMessage = await _supabase
                .from('chat_messages')
                .select('message')
                .eq('room_id', room['id'])
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            // Hitung jumlah pesan yang belum dibaca
            final unreadCountResponse = await _supabase
                .from('chat_messages')
                .count()
                .eq('room_id', room['id'])
                .eq('sender_id', room['buyer_id'])
                .eq('is_read', false);

            // Debug print untuk melihat struktur response
            print('Debug unreadCountResponse: $unreadCountResponse');

            return {
              ...room,
              'buyer_name': buyerProfile['full_name'] ??
                  buyerProfile['email'] ??
                  'Unknown User',
              'last_message': lastMessage?['message'] ?? 'Belum ada pesan',
              'unread_count': unreadCountResponse,
            };
          } catch (e) {
            print('Error fetching additional data: $e');
            return {
              ...room,
              'buyer_name': 'Unknown User',
              'last_message': 'Error loading message',
              'unread_count': 0,
            };
          }
        }),
      );

      chatList.assignAll(transformedResponse);
    } catch (e) {
      print('Error fetching chat rooms: $e');
    } finally {
      isLoading(false);
    }
  }

  void listenForChatRoomUpdates(String sellerId) {
    _supabase
        .from('chat_rooms')
        .stream(primaryKey: ['id'])
        .eq('seller_id', sellerId)
        .listen((List<Map<String, dynamic>> data) {
          fetchChatRooms(sellerId);
        });
  }

  void listenForNewMessages(String sellerId) {
    _supabase.from('chat_messages').stream(primaryKey: ['id']).listen(
        (List<Map<String, dynamic>> messages) async {
      if (messages.isNotEmpty) {
        fetchChatRooms(sellerId);
      }
    });
  }

  void updateChatRooms(List<Map<String, dynamic>> newData) {
    chatList.assignAll(newData);
  }
}
