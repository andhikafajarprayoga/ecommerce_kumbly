import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';
import 'package:realtime_client/realtime_client.dart';

import './courier_local_notification_service.dart';

class CourierNotificationService {
  final _notifications = RxList<Map<String, dynamic>>([]);
  final _isLoading = false.obs;
  late RealtimeChannel _subscription;
  final client = Supabase.instance.client;
  final CourierLocalNotificationService _localNotificationService =
      CourierLocalNotificationService();

  RxList<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading.value;

  Future<void> initializeNotifications() async {
    _isLoading.value = true;
    try {
      await _localNotificationService.initNotification();

      final response = await client
          .from('notification_courier')
          .select()
          .order('created_at', ascending: false);

      if (response != null) {
        _notifications.assignAll(response as List<Map<String, dynamic>>);
      }

      _subscription =
          client.channel('public:notification_courier').onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'notification_courier',
                callback: (payload) {
                  if (payload.newRecord != null) {
                    final newNotification =
                        payload.newRecord as Map<String, dynamic>;
                    _notifications.insert(0, newNotification);
                  }
                },
              );

      await _subscription.subscribe();
    } catch (e) {
      print('Error initializing notifications: $e');
    } finally {
      _isLoading.value = false;
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await client
          .from('notification_courier')
          .update({'status': 'read'}).eq('id', notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index] = {..._notifications[index], 'status': 'read'};
      }
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  void dispose() {
    _subscription.unsubscribe();
  }
}
