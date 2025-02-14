import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'chat_detail_screen.dart';
import 'package:rxdart/rxdart.dart' as rx;
import 'package:kumbly_ecommerce/auth/login_page.dart';
import 'package:kumbly_ecommerce/auth/register_page.dart';
import 'package:intl/intl.dart';
import '../../../utils/date_formatter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _chatRoomsStream;
  Map<String, Map<String, dynamic>> sellers = {};
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    if (supabase.auth.currentUser != null) {
      _initializeChatRooms();

      // Initialize notification tap handler
      flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (details) {
          _handleNotificationTap(details.payload);
        },
      );
    }
  }

  void _initializeChatRooms() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _chatRoomsStream = rx.Rx.combineLatest3(
      // Stream untuk chat dengan seller
      supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .order('created_at')
          .execute(),

      // Stream untuk chat rooms
      supabase
          .from('chat_rooms')
          .stream(primaryKey: ['id'])
          .eq('buyer_id', userId)
          .order('created_at', ascending: false)
          .execute(),

      // Stream untuk admin chat
      supabase
          .from('admin_chat_rooms')
          .stream(primaryKey: ['id'])
          .eq('buyer_id', userId)
          .order('created_at', ascending: false)
          .execute(),

      // Combine semua stream
      (List<Map<String, dynamic>> messages, List<Map<String, dynamic>> rooms,
          List<Map<String, dynamic>> adminRooms) async {
        List<Map<String, dynamic>> validRooms = [];

        // Proses chat rooms biasa
        for (var room in rooms) {
          try {
            final merchantData = await supabase
                .from('merchants')
                .select('store_name')
                .eq('id', room['seller_id'])
                .maybeSingle();

            room['store_name'] =
                merchantData?['store_name'] ?? 'Toko tidak ditemukan';
            room['is_admin_room'] = false;

            // Ambil pesan terakhir dari stream messages
            final lastMessage = messages
                .where((msg) => msg['room_id'] == room['id'])
                .toList()
              ..sort((a, b) => b['created_at'].compareTo(a['created_at']));

            if (lastMessage.isNotEmpty) {
              room['last_message'] = lastMessage.first['message'];
              room['last_message_time'] = lastMessage.first['created_at'];

              // Tampilkan notifikasi jika ada pesan baru dan bukan dari user saat ini
              if (!lastMessage.first['is_read'] &&
                  lastMessage.first['sender_id'] != userId &&
                  ModalRoute.of(context)?.settings.name !=
                      ChatDetailScreen(
                          chatRoom: room,
                          seller: {
                            'store_name': room['store_name'],
                            'image': 'https://via.placeholder.com/50'
                          },
                          isAdminRoom: true)) {
                _showNotification(
                  'Pesan baru dari ${room['store_name']}',
                  lastMessage.first['message'],
                );
              }
            }

            room['unread_count'] = messages
                .where((msg) =>
                    msg['room_id'] == room['id'] &&
                    !msg['is_read'] &&
                    msg['sender_id'] != userId)
                .length;

            validRooms.add(room);
          } catch (e) {
            print('Error processing seller chat room: $e');
          }
        }

        // Proses admin chat rooms
        for (var room in adminRooms) {
          try {
            room['store_name'] = 'Admin Kumbly';
            room['is_admin_room'] = true;

            final lastMessageResponse = await supabase
                .from('admin_messages')
                .select('content, created_at, sender_id, is_read')
                .eq('chat_room_id', room['id'])
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

            if (lastMessageResponse != null) {
              room['last_message'] = lastMessageResponse['content'];
              room['last_message_time'] = lastMessageResponse['created_at'];

              // Tampilkan notifikasi untuk pesan admin yang belum dibaca
              if (!lastMessageResponse['is_read'] &&
                  lastMessageResponse['sender_id'] != userId &&
                  ModalRoute.of(context)?.settings.name !=
                      ChatDetailScreen(
                          chatRoom: room,
                          seller: {
                            'store_name': room['store_name'],
                            'image': 'https://via.placeholder.com/50'
                          },
                          isAdminRoom: true)) {
                _showNotification(
                  'Pesan baru dari Admin',
                  lastMessageResponse['content'],
                );
              }
            }

            room['unread_count'] = await _getUnreadCount(room['id'], true);
            validRooms.add(room);
          } catch (e) {
            print('Error processing admin chat room: $e');
          }
        }

        validRooms.sort((a, b) => (b['last_message_time'] ?? b['created_at'])
            .compareTo(a['last_message_time'] ?? a['created_at']));

        return validRooms;
      },
    ).asyncMap((event) => event);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primary.withOpacity(0.9),
                AppTheme.primary.withOpacity(0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),
                // Icon dan Animasi
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 120,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                // Teks Selamat Datang
                const Text(
                  'Mulai Percakapan',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Login untuk mulai chat dengan penjual dan lihat riwayat percakapan Anda',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                // Tombol Login
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () => Get.to(() => LoginPage()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        'Login',
                        style: TextStyle(
                          color: AppTheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Tombol Register
                TextButton(
                  onPressed: () => Get.to(() => RegisterPage()),
                  child: RichText(
                    text: TextSpan(
                      text: 'Belum punya akun? ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Daftar',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text(
          'Pesan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
            fontSize: 20,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _chatRoomsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Terjadi kesalahan',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Belum ada percakapan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mulai chat dengan penjual',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final room = snapshot.data![index];
              return _buildChatItem(room);
            },
          );
        },
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> room) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            // Mark messages as read before navigating
            final userId = supabase.auth.currentUser?.id;
            if (userId != null) {
              if (room['is_admin_room'] ?? false) {
                await supabase
                    .from('admin_messages')
                    .update({'is_read': true})
                    .eq('chat_room_id', room['id'])
                    .neq('sender_id', userId)
                    .eq('is_read', false);
              } else {
                await supabase
                    .from('chat_messages')
                    .update({'is_read': true})
                    .eq('room_id', room['id'])
                    .neq('sender_id', userId)
                    .eq('is_read', false);
              }
            }

            // Reset unread count in local state
            setState(() {
              room['unread_count'] = 0;
            });

            Get.to(() => ChatDetailScreen(
                  chatRoom: room,
                  seller: {
                    'store_name': room['is_admin_room']
                        ? 'Admin Kumbly'
                        : room['store_name'],
                    'image': 'https://via.placeholder.com/50'
                  },
                  isAdminRoom: room['is_admin_room'] ?? false,
                ));
          },
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary.withOpacity(0.8),
                            AppTheme.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          (room['store_name'] as String)
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room['store_name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            room['last_message'] ?? 'Belum ada pesan',
                            style: TextStyle(
                              color: room['unread_count'] > 0
                                  ? Colors.black
                                  : Colors.grey[600],
                              fontWeight: room['unread_count'] > 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          DateFormatter.formatChatTime(
                              room['last_message_time'] ?? room['created_at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: room['unread_count'] > 0
                                ? AppTheme.primary
                                : Colors.grey[600],
                          ),
                        ),
                        if (room['unread_count'] > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${room['unread_count']}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadSellerInfo(String sellerId) async {
    if (!sellers.containsKey(sellerId)) {
      try {
        final seller = await _getUserInfo(sellerId);
        if (mounted) {
          setState(() {
            sellers[sellerId] = seller;
          });
        }
      } catch (e) {
        print('Error loading seller info: $e');
        if (mounted) {
          setState(() {
            sellers[sellerId] = {
              'name': 'User tidak ditemukan',
              'image': 'https://via.placeholder.com/50',
              'is_merchant': false
            };
          });
        }
      }
    }
  }

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    try {
      final merchantData = await supabase
          .from('merchants')
          .select('id, store_name')
          .eq('id', userId)
          .maybeSingle();

      if (merchantData != null) {
        return {
          'name': merchantData['store_name'],
          'image': 'https://via.placeholder.com/50',
          'is_merchant': true
        };
      }

      final userData = await supabase
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null) {
        return {
          'name': userData['full_name'],
          'image': userData['avatar_url'] ?? 'https://via.placeholder.com/50',
          'is_merchant': false
        };
      }

      throw Exception('User not found');
    } catch (e) {
      print('Error getting user info: $e');
      return {
        'name': 'User tidak ditemukan',
        'image': 'https://via.placeholder.com/50',
        'is_merchant': false
      };
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';

    final DateTime dateTime = DateTime.parse(timestamp).toLocal();
    final DateTime now = DateTime.now();
    final difference = now.difference(dateTime);

    // Hari ini
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return DateFormat('HH:mm').format(dateTime);
    }

    // Kemarin
    if (difference.inDays == 1) {
      return 'Kemarin';
    }

    // Minggu ini
    if (difference.inDays < 7) {
      final List<String> days = [
        'Sen',
        'Sel',
        'Rab',
        'Kam',
        'Jum',
        'Sab',
        'Min'
      ];
      return days[dateTime.weekday - 1];
    }

    // Format tanggal
    return DateFormat('dd/MM').format(dateTime);
  }

  Future<int> _getUnreadCount(String roomId, bool isAdminRoom) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    if (isAdminRoom) {
      final response = await supabase
          .from('admin_messages')
          .select('id')
          .eq('chat_room_id', roomId)
          .eq('is_read', false)
          .count();
      return response.count ?? 0;
    } else {
      final response = await supabase
          .from('chat_messages')
          .select('id')
          .eq('room_id', roomId)
          .eq('is_read', false)
          .count();
      return response.count ?? 0;
    }
  }

  Future<void> _markMessagesAsRead(String roomId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase
        .from('chat_messages')
        .update({'is_read': true})
        .eq('room_id', roomId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  void _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'chat_channel', // channel id
      'Chat Notifications', // channel name
      channelDescription: 'Notifications for new chat messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(''),
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    // Buat payload JSON yang valid
    final payload = jsonEncode({
      'type': 'chat',
      'route': '/chat',
      'data': {
        'title': title,
        'message': body,
      }
    });

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
      payload: payload,
    );
  }

  // Tambahkan fungsi ini untuk handle notification tap
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    try {
      final data = jsonDecode(payload);
      if (data['type'] == 'chat') {
        Get.toNamed(data['route']);
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }
}
