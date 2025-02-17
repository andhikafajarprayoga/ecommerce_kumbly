import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'notification_service.dart';

class BuyerChatService {
  static final BuyerChatService _instance = BuyerChatService._internal();
  factory BuyerChatService() => _instance;
  BuyerChatService._internal();

  final supabase = Supabase.instance.client;
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _adminMessagesSubscription;

  void initializeMessageListener() {
    if (_messagesSubscription != null) return;

    // Regular chat messages
    _messagesSubscription = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('is_read', false)
        .order('created_at', ascending: false)
        .map((event) => event as List<Map<String, dynamic>>)
        .listen((newMessages) {
          _processNewMessages(newMessages, false);
        });

    // Admin messages to buyer
    _adminMessagesSubscription = supabase
        .from('admin_messages')
        .stream(primaryKey: ['id'])
        .eq('is_read', false)
        .order('created_at', ascending: false)
        .map((event) => event as List<Map<String, dynamic>>)
        .listen((newMessages) {
          _processNewMessages(newMessages, true);
        });
  }

  void _processNewMessages(
      List<Map<String, dynamic>> newMessages, bool isAdminMessage) async {
    for (var message in newMessages) {
      final messageTime = DateTime.parse(message['created_at']);
      final currentTime = DateTime.now();

      if (currentTime.difference(messageTime).inSeconds <= 30) {
        if (message['sender_id'] != supabase.auth.currentUser?.id) {
          await _showNotification(message, isAdminMessage);
        }
      }
    }
  }

  Future<void> _showNotification(
      Map<String, dynamic> message, bool isAdminMessage) async {
    try {
      String title;
      String body;

      if (isAdminMessage) {
        title = 'Pesan baru dari Admin';
        body = message['content'];
      } else {
        final seller = await supabase
            .from('merchants')
            .select('store_name')
            .eq('id', message['sender_id'])
            .single();

        title = 'Pesan baru dari ${seller['store_name']}';
        body = message['message'];
      }

      await NotificationService.showChatNotification(
        title: title,
        body: body,
        roomId: isAdminMessage ? message['chat_room_id'] : message['room_id'],
        senderId: message['sender_id'],
        messageId: message['id'],
      );
    } catch (e) {
      print('ERROR: Failed to show notification: $e');
    }
  }

  void dispose() {
    _messagesSubscription?.cancel();
    _adminMessagesSubscription?.cancel();
    _messagesSubscription = null;
    _adminMessagesSubscription = null;
  }
}
