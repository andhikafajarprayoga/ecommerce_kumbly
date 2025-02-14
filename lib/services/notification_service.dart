import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/merchant/chats/chat_detail_screen.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool isAppInForeground = true; // Tambahkan flag untuk status aplikasi
  static final Set<String> _notifiedMessageIds =
      {}; // Tambahkan tracking untuk message IDs

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Setup notification channel untuk background
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_channel',
      'Chat Notifications',
      description: 'Notifications for new chat messages',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) async {
        try {
          if (details.payload != null) {
            final data = json.decode(details.payload!);
            if (data['type'] == 'chat') {
              final supabase = Supabase.instance.client;

              // Pastikan user sudah login
              final currentUser = supabase.auth.currentUser;
              if (currentUser == null) {
                print('DEBUG: User not logged in');
                return;
              }

              // Ambil nama pengirim
              final senderData = await supabase
                  .from('users')
                  .select('full_name')
                  .eq('id', data['sender_id'])
                  .single();

              // Navigasi ke chat detail
              await Get.to(
                () => ChatDetailScreen(
                  roomId: data['room_id'],
                  currentUserId: currentUser.id,
                  userName: senderData['full_name'] ?? 'Unknown User',
                ),
                preventDuplicates: true,
              );
            }
          }
        } catch (e) {
          print('ERROR: Failed to handle notification tap: $e');
        }
      },
      onDidReceiveBackgroundNotificationResponse: _handleBackgroundNotification,
    );
  }

  // Handler untuk notifikasi background
  @pragma('vm:entry-point')
  static void _handleBackgroundNotification(NotificationResponse details) {
    // Implementasi handling notifikasi background jika diperlukan
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'courier_notifications',
      'Notifikasi Kurir',
      channelDescription: 'Notifikasi untuk kurir',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
    );
  }

  static Future<void> showChatNotification({
    required String title,
    required String body,
    required String roomId,
    required String senderId,
    required String messageId, // Tambahkan parameter messageId
  }) async {
    // Cek apakah pesan sudah dinotifikasi
    if (_notifiedMessageIds.contains(messageId)) {
      return;
    }

    // Tambahkan message ID ke set
    _notifiedMessageIds.add(messageId);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel',
      'Chat Notifications',
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      ongoing: false,
      autoCancel: true,
      channelShowBadge: true,
      visibility: NotificationVisibility.public,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    final payload = json.encode({
      'type': 'chat',
      'room_id': roomId,
      'sender_id': senderId,
    });

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }
}
