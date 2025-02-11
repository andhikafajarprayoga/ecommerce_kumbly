import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class CourierNotificationsScreen extends StatefulWidget {
  @override
  _CourierNotificationsScreenState createState() =>
      _CourierNotificationsScreenState();
}

class _CourierNotificationsScreenState
    extends State<CourierNotificationsScreen> {
  final supabase = Supabase.instance.client;
  final RxList<Map<String, dynamic>> notifications =
      <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('notification_courier')
          .select()
          .order('created_at', ascending: false);

      notifications.assignAll(response);

      await supabase
          .from('notification_courier')
          .update({'status': 'read'}).eq('status', 'unread');
    } catch (e) {
      print('Error fetching notifications: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifikasi', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: Obx(() {
        if (isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (notifications.isEmpty) {
          return Center(child: Text('Tidak ada notifikasi'));
        }

        return ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notification = notifications[index];
            return Card(
              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: Icon(
                  Icons.notifications,
                  color: notification['status'] == 'read'
                      ? Colors.grey
                      : Colors.blue,
                ),
                title: Text(notification['message'] ?? ''),
                subtitle: Text(
                  DateFormat('dd MMM yyyy HH:mm').format(
                    DateTime.parse(notification['created_at']),
                  ),
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
