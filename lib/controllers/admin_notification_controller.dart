import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/local_notification_service.dart';

class AdminNotificationController extends GetxController {
  final supabase = Supabase.instance.client;
  RxList<Map<String, dynamic>> notifications = <Map<String, dynamic>>[].obs;
  RxInt unreadCount = 0.obs;
  final LocalNotificationService _notificationService =
      LocalNotificationService();

  @override
  void onInit() async {
    super.onInit();
    await _notificationService.initNotification();
    fetchNotifications();
    setupNotificationListener();
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await supabase
          .from('admin_notifications')
          .select()
          .order('created_at', ascending: false)
          .limit(50);

      notifications.value = List<Map<String, dynamic>>.from(response);
      updateUnreadCount();
    } catch (e) {
      print('Error fetching notifications: $e');
    }
  }

  void updateUnreadCount() {
    unreadCount.value = notifications
        .where((notification) => notification['status'] == 'unread')
        .length;
  }

  void setupNotificationListener() {
    supabase
        .channel('public:admin_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'admin_notifications',
          callback: (payload) async {
            print('New notification received: $payload');

            // Show local notification
            await _notificationService.showNotification(
              title: 'Notifikasi Baru',
              body: payload.newRecord['message'] as String,
              payload: '/admin/notifications',
            );

            fetchNotifications();
          },
        )
        .subscribe();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('admin_notifications')
          .update({'status': 'read'}).eq('id', notificationId);
      await fetchNotifications();
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
}
