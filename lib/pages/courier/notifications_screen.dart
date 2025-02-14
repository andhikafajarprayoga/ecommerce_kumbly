import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_theme.dart';
import '../../services/courier_notification_service.dart';

class CourierNotificationsScreen extends StatefulWidget {
  @override
  _CourierNotificationsScreenState createState() =>
      _CourierNotificationsScreenState();
}

class _CourierNotificationsScreenState
    extends State<CourierNotificationsScreen> {
  final CourierNotificationService _notificationService =
      CourierNotificationService();

  @override
  void initState() {
    super.initState();
    _notificationService.initializeNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifikasi Kurir', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
        actions: [
          Obx(() => _notificationService.notifications.isNotEmpty
              ? TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: Icon(Icons.done_all, color: Colors.white),
                  label: Text(
                    'Baca Semua',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : SizedBox()),
        ],
      ),
      body: Obx(() {
        if (_notificationService.isLoading) {
          return Center(child: CircularProgressIndicator());
        }

        if (_notificationService.notifications.isEmpty) {
          return Center(child: Text('Tidak ada notifikasi'));
        }

        return ListView.builder(
          itemCount: _notificationService.notifications.length,
          itemBuilder: (context, index) {
            final notification = _notificationService.notifications[index];
            return _buildNotificationItem(notification);
          },
        );
      }),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: Icon(Icons.local_shipping, color: Colors.blue),
        ),
        title: Text(notification['message'] ?? ''),
        subtitle: Text(
          timeago.format(DateTime.parse(notification['created_at'])),
          style: TextStyle(fontSize: 12),
        ),
        tileColor: notification['status'] == 'unread'
            ? Colors.blue.withOpacity(0.1)
            : null,
        onTap: () {
          _notificationService.markAsRead(notification['id']);
          if (notification['order_id'] != null) {
            // Navigate to order details
            // Get.toNamed('/courier/orders/${notification['order_id']}');
          }
        },
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.client
          .from('notification_courier')
          .update({'status': 'read'}).eq('status', 'unread');

      await _notificationService.initializeNotifications();

      Get.snackbar(
        'Sukses',
        'Semua notifikasi telah ditandai sebagai dibaca',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error marking all as read: $e');
      Get.snackbar(
        'Error',
        'Gagal menandai semua notifikasi',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
