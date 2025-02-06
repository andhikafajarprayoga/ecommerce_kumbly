import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'chat_detail_screen.dart';
import 'package:rxdart/rxdart.dart' as rx;

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _chatRoomsStream;
  Map<String, Map<String, dynamic>> sellers = {};

  @override
  void initState() {
    super.initState();
    _initializeChatRooms();
  }

  void _initializeChatRooms() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _chatRoomsStream = rx.Rx.combineLatest2(
      // Stream untuk chat dengan seller
      supabase
          .from('chat_rooms')
          .stream(primaryKey: ['id'])
          .eq('buyer_id', userId)
          .order('created_at', ascending: false)
          .execute()
          .asyncMap((rooms) async {
            List<Map<String, dynamic>> validRooms = [];
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

                final lastMessageResponse = await supabase
                    .from('chat_messages')
                    .select('message, created_at')
                    .eq('room_id', room['id'])
                    .order('created_at', ascending: false)
                    .limit(1)
                    .maybeSingle();

                if (lastMessageResponse != null) {
                  room['last_message'] = lastMessageResponse['message'];
                  room['last_message_time'] = lastMessageResponse['created_at'];
                } else {
                  room['last_message'] = 'Belum ada pesan';
                  room['last_message_time'] = room['created_at'];
                }

                room['unread_count'] = await _getUnreadCount(room['id'], false);
                validRooms.add(room);
              } catch (e) {
                print('Error processing seller chat room: $e');
              }
            }
            return validRooms;
          }),

      // Stream untuk chat admin
      supabase
          .from('admin_chat_rooms')
          .stream(primaryKey: ['id'])
          .eq('buyer_id', userId)
          .order('created_at', ascending: false)
          .execute()
          .asyncMap((rooms) async {
            List<Map<String, dynamic>> validRooms = [];
            for (var room in rooms) {
              try {
                room['store_name'] = 'Admin Kumbly';
                room['is_admin_room'] = true;

                final lastMessageResponse = await supabase
                    .from('admin_messages')
                    .select('content, created_at')
                    .eq('chat_room_id', room['id'])
                    .order('created_at', ascending: false)
                    .limit(1)
                    .maybeSingle();

                if (lastMessageResponse != null) {
                  room['last_message'] = lastMessageResponse['content'];
                  room['last_message_time'] = lastMessageResponse['created_at'];
                } else {
                  room['last_message'] = 'Belum ada pesan';
                  room['last_message_time'] = room['created_at'];
                }

                room['unread_count'] = await _getUnreadCount(room['id'], true);
                validRooms.add(room);
              } catch (e) {
                print('Error processing admin chat room: $e');
              }
            }
            return validRooms;
          }),

      // Gabungkan hasil kedua stream
      (sellerRooms, adminRooms) {
        List<Map<String, dynamic>> allRooms = [...sellerRooms, ...adminRooms];
        allRooms.sort((a, b) => (b['last_message_time'] ?? b['created_at'])
            .compareTo(a['last_message_time'] ?? a['created_at']));
        return allRooms;
      },
    ).asyncMap((event) => event);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Pesan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
          onTap: () {
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
          child: Padding(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              room['store_name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.normal,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            _formatTimestamp(
                                room['last_message_time'] ?? room['created_at'],
                                room['is_admin_room'] ?? false),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        room['last_message'] ?? 'Belum ada pesan',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  String _formatTimestamp(String? timestamp, bool isAdminRoom) {
    if (timestamp == null) return '';

    // Parse timestamp sebagai UTC
    final DateTime dateTimeUtc = DateTime.parse(timestamp);
    final DateTime now =
        DateTime.now().toUtc(); // Gunakan UTC untuk perbandingan

    // Untuk admin chat, selalu tampilkan format jam UTC
    if (isAdminRoom) {
      return '${dateTimeUtc.hour.toString().padLeft(2, '0')}:${dateTimeUtc.minute.toString().padLeft(2, '0')}';
    }

    // Format untuk chat biasa
    if (dateTimeUtc.year == now.year &&
        dateTimeUtc.month == now.month &&
        dateTimeUtc.day == now.day) {
      return '${dateTimeUtc.hour.toString().padLeft(2, '0')}:${dateTimeUtc.minute.toString().padLeft(2, '0')}';
    }

    if (now.difference(dateTimeUtc).inDays == 1) {
      return 'Kemarin';
    }

    if (now.difference(dateTimeUtc).inDays < 7) {
      return _getDayName(dateTimeUtc.weekday);
    }

    return '${dateTimeUtc.day.toString().padLeft(2, '0')}/${dateTimeUtc.month.toString().padLeft(2, '0')}';
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return '';
    }
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

  Future<void> _markMessagesAsRead(String roomId, bool isAdminRoom) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    if (isAdminRoom) {
      await supabase
          .from('admin_messages')
          .update({'is_read': true})
          .eq('chat_room_id', roomId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } else {
      await supabase
          .from('chat_messages')
          .update({'is_read': true})
          .eq('room_id', roomId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    }
  }
}
