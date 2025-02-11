import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../controllers/admin_notification_controller.dart';
import '../../../theme/app_theme.dart';
import '../../../services/local_notification_service.dart';

class AdminNotificationsScreen extends StatefulWidget {
  @override
  _AdminNotificationsScreenState createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final controller = Get.find<AdminNotificationController>();
  final LocalNotificationService _notificationService =
      LocalNotificationService();
  int lastNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _setupNotificationListener();
  }

  Future<void> _initializeNotifications() async {
    await _notificationService.initNotification();
    lastNotificationCount = controller.notifications.length;
  }

  void _setupNotificationListener() {
    ever(controller.notifications, (notifications) {
      if (notifications.length > lastNotificationCount) {
        // Ada notifikasi baru
        final newNotification = notifications.first;
        _showLocalNotification(newNotification);
      }
      lastNotificationCount = notifications.length;
    });
  }

  void _showLocalNotification(Map<String, dynamic> notification) {
    _notificationService.showNotification(
      title: 'Notifikasi Admin Baru',
      body: notification['message'] ?? 'Ada notifikasi baru',
      payload: '/admin/notifications',
    );
  }

  Future<void> _markAllAsRead() async {
    try {
      await controller.supabase
          .from('admin_notifications')
          .update({'status': 'read'}).eq('status', 'unread');

      await controller.fetchNotifications();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifikasi Admin', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        actions: [
          Obx(() => controller.notifications.isNotEmpty
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
      body: Obx(
        () => controller.notifications.isEmpty
            ? Center(
                child: Text('Tidak ada notifikasi'),
              )
            : ListView.builder(
                itemCount: controller.notifications.length,
                itemBuilder: (context, index) {
                  final notification = controller.notifications[index];
                  return _buildNotificationItem(notification);
                },
              ),
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _getNotificationIcon(notification['notification_type']),
        title: Text(notification['message']),
        subtitle: Text(
          timeago.format(DateTime.parse(notification['created_at'])),
          style: TextStyle(fontSize: 12),
        ),
        tileColor: notification['status'] == 'unread'
            ? Colors.blue.withOpacity(0.1)
            : null,
        onTap: () {
          controller.markAsRead(notification['id']);
          _handleNotificationTap(notification);
        },
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'order':
        iconData = Icons.shopping_cart;
        iconColor = Colors.blue;
        break;
      case 'user':
        iconData = Icons.person;
        iconColor = Colors.green;
        break;
      case 'payment':
        iconData = Icons.payment;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.notifications;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.1),
      child: Icon(iconData, color: iconColor),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    // Handle navigation based on notification type
    switch (notification['notification_type']) {
      case 'order':
        // Navigate to order details
        break;
      case 'user':
        // Navigate to user details
        break;
      case 'payment':
        // Navigate to payment details
        break;
    }
  }
}
