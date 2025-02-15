import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class BackgroundNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final Set<String> _notifiedIds = {};

  static Future<void> initialize() async {
    // Inisialisasi notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'background_notification_channel',
      'Background Notifications',
      description: 'Notifikasi untuk pemberitahuan sistem',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    // Inisialisasi notification settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    // Buat channel
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Inisialisasi notifications
    await _notifications.initialize(initializationSettings);

    // Setup Supabase listener
    setupNotificationListener();
  }

  static void setupNotificationListener() {
    final supabase = Supabase.instance.client;

    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', supabase.auth.currentUser?.id ?? '')
        .listen((List<Map<String, dynamic>> notifications) {
          // Hanya proses notifikasi terbaru
          if (notifications.isNotEmpty) {
            final latestNotif = notifications.first;
            if (!_notifiedIds.contains(latestNotif['id']) &&
                latestNotif['is_read'] == false) {
              _showNotification(
                id: latestNotif['id'],
                title: latestNotif['title'],
                body: latestNotif['message'],
                type: latestNotif['type'],
              );
              _notifiedIds.add(latestNotif['id']);
            }
          }
        });
  }

  static Future<void> _showNotification({
    required String id,
    required String title,
    required String body,
    required String type,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'background_notification_channel',
      'Background Notifications',
      channelDescription: 'Notifikasi untuk pemberitahuan sistem',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    final payload = json.encode({
      'notification_id': id,
      'type': type,
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
