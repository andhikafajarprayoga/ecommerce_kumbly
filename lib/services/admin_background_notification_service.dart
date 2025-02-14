import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'local_notification_service.dart';

class AdminBackgroundNotificationService {
  final supabase = Supabase.instance.client;
  final LocalNotificationService _localNotificationService =
      LocalNotificationService();
  RealtimeChannel? _subscription;

  Future<void> initialize() async {
    await _localNotificationService.initNotification();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _subscription = supabase
        .channel('admin_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'admin_notifications',
          callback: (payload) {
            final notification = payload.newRecord;
            _showBackgroundNotification(notification);
          },
        )
        .subscribe();
  }

  void _showBackgroundNotification(Map<String, dynamic> notification) {
    _localNotificationService.showNotification(
      title: 'Notifikasi Admin Baru',
      body: notification['message'] ?? 'Ada notifikasi baru',
      payload: '/admin/notifications',
    );
  }

  void dispose() {
    _subscription?.unsubscribe();
  }
}
