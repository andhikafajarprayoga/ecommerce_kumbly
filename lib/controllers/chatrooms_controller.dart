import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;

  var chatList = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs;

  Future<void> fetchChatRooms(String sellerId) async {
    try {
      isLoading.value = true;
      final chatRoomsResponse = await _supabase
          .from('chat_rooms')
          .select('id, buyer_id, seller_id')
          .eq('seller_id', sellerId);

      List<Map<String, dynamic>> chatRooms =
          List<Map<String, dynamic>>.from(chatRoomsResponse);

      for (var chatRoom in chatRooms) {
        final lastMessageResponse = await _supabase
            .from('chat_messages')
            .select('message, created_at')
            .eq('room_id', chatRoom['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .single();

        chatRoom['last_message'] =
            lastMessageResponse['message'] ?? "Belum ada pesan";
        chatRoom['last_message_time'] = lastMessageResponse['created_at'];
      }

      chatList.assignAll(chatRooms);
    } catch (e) {
      print("Error fetching chat rooms: $e");
    } finally {
      isLoading.value = false;
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
}
