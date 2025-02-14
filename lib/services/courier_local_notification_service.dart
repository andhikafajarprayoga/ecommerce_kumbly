import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

class CourierLocalNotificationService {
  // Singleton pattern
  static final CourierLocalNotificationService _instance =
      CourierLocalNotificationService._internal();
  factory CourierLocalNotificationService() => _instance;
  CourierLocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  final Set<int> _processedIds = {}; // Untuk mencegah duplikasi

  Future<void> initNotification() async {
    if (_isInitialized) return; // Hindari multiple initialization

    AndroidInitializationSettings initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    var initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
        if (notificationResponse.payload != null) {
          Get.toNamed(notificationResponse.payload!);
        }
      },
    );

    _isInitialized = true;
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    // Cek apakah notifikasi dengan ID ini sudah ditampilkan
    if (_processedIds.contains(id)) return;
    _processedIds.add(id);

    const androidNotificationDetails = AndroidNotificationDetails(
      'courier_channel',
      'Courier Notifications',
      channelDescription: 'Channel for courier notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iOSNotificationDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSNotificationDetails,
    );

    await notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Method untuk membersihkan processed IDs jika diperlukan
  void clearProcessedIds() {
    _processedIds.clear();
  }
}
