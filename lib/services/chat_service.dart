import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'notification_service.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final supabase = Supabase.instance.client;
  StreamSubscription? _messagesSubscription;

  void initializeMessageListener() {
    if (_messagesSubscription != null) return;

    _messagesSubscription = supabase
        .from('admin_messages')
        .stream(primaryKey: ['id'])
        .eq('is_read', false)
        .order('created_at', ascending: false)
        .map((event) => event as List<Map<String, dynamic>>)
        .listen((newMessages) {
          _processNewMessages(newMessages);
        });
  }

  void _processNewMessages(List<Map<String, dynamic>> newMessages) async {
    for (var message in newMessages) {
      final messageTime = DateTime.parse(message['created_at']);
      final currentTime = DateTime.now();

      if (currentTime.difference(messageTime).inSeconds <= 30) {
        if (message['sender_id'] != supabase.auth.currentUser!.id) {
          await _showNotification(message);
        }
      }
    }
  }

  Future<void> _showNotification(Map<String, dynamic> message) async {
    try {
      final sender = await supabase
          .from('merchants')
          .select('store_name')
          .eq('id', message['sender_id'])
          .single();

      await NotificationService.showChatNotification(
        title: sender['store_name'] ?? 'Unknown Merchant',
        body: message['content'],
        roomId: message['chat_room_id'],
        senderId: message['sender_id'],
        messageId: message['id'],
      );
    } catch (e) {
      print('ERROR: Failed to show notification: $e');
    }
  }

  void dispose() {
    _messagesSubscription?.cancel();
    _messagesSubscription = null;
  }
}
