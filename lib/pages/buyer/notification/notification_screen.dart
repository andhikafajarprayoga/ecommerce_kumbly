import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  RxInt unreadCount = 0.obs;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
    listenToNotifications();
  }

  Future<void> fetchNotifications() async {
    try {
      final response = await supabase
          .from('notifications')
          .select()
          .eq('user_id', supabase.auth.currentUser!.id)
          .order('created_at', ascending: false);

      setState(() {
        notifications = List<Map<String, dynamic>>.from(response);
        isLoading = false;
        updateUnreadCount();
      });
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() => isLoading = false);
    }
  }

  void listenToNotifications() {
    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', supabase.auth.currentUser!.id)
        .listen((List<Map<String, dynamic>> data) {
          setState(() {
            notifications = data;
            updateUnreadCount();
          });
        });
  }

  void updateUnreadCount() {
    unreadCount.value =
        notifications.where((notif) => notif['is_read'] == false).length;
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true}).eq('id', notificationId);

      setState(() {
        final index =
            notifications.indexWhere((notif) => notif['id'] == notificationId);
        if (index != -1) {
          notifications[index]['is_read'] = true;
          updateUnreadCount();
        }
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await supabase
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', supabase.auth.currentUser!.id)
          .eq('is_read', false);

      setState(() {
        notifications = notifications.map((notif) {
          notif['is_read'] = true;
          return notif;
        }).toList();
        updateUnreadCount();
      });
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifikasi', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          if (unreadCount.value > 0)
            TextButton(
              onPressed: markAllAsRead,
              child: Text(
                'Tandai Semua Dibaca',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? Center(child: Text('Tidak ada notifikasi'))
              : ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return InkWell(
                      onTap: () => markAsRead(notification['id']),
                      child: Container(
                        color: notification['is_read'] == false
                            ? Colors.blue.withOpacity(0.1)
                            : null,
                        child: ListTile(
                          leading: _getNotificationIcon(notification['type']),
                          title: Text(notification['title']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notification['message']),
                              SizedBox(height: 4),
                              Text(
                                timeago.format(
                                  DateTime.parse(notification['created_at']),
                                  locale: 'id',
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _getNotificationIcon(String type) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case 'order':
        iconData = Icons.shopping_bag;
        iconColor = Colors.blue;
        break;
      case 'chat':
        iconData = Icons.chat;
        iconColor = Colors.green;
        break;
      case 'promo':
        iconData = Icons.local_offer;
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
}
