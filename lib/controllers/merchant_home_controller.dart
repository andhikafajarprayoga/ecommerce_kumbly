import 'package:get/get.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:kumbly_ecommerce/pages/merchant/profile/edit_store_screen.dart';

class MerchantHomeController extends GetxController {
  final supabase = Supabase.instance.client;
  final storeName = ''.obs;
  final needToShip = '0'.obs;
  final shipping = '0'.obs;
  final cancelled = '0'.obs;
  final completed = '0'.obs;
  final RxInt hotelBookingsCount = 0.obs;
  final RxInt pendingShipmentCount = 0.obs;
  final RxInt pendingCancellationCount = 0.obs;
  final RxInt unreadNotificationsCount = 0.obs;
  final RxInt unreadChatsCount = 0.obs;
  final RxInt selectedIndex = 0.obs;
  StreamSubscription? chatSubscription;

  @override
  void onInit() {
    super.onInit();
    setupStreams();
    fetchMerchantData();
  }

  @override
  void onClose() {
    chatSubscription?.cancel();
    super.onClose();
  }

  void setupStreams() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Stream untuk notifikasi seller
    supabase
        .from('notifikasi_seller')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', userId)
        .order('created_at', ascending: false)
        .execute()
        .handleError((error) {
          print('Notifikasi stream error: $error');
          Future.delayed(Duration(seconds: 3), () => setupStreams());
        })
        .listen(
          (data) {
            try {
              print('DEBUG: Received ${data.length} notifications');
              final unreadCount =
                  data.where((notif) => notif['is_read'] == false).length;
              print('DEBUG: Unread count: $unreadCount');
              unreadNotificationsCount.value = unreadCount;
            } catch (e) {
              print('Error processing notifications: $e');
            }
          },
          onError: (error) {
            print('Notification listen error: $error');
            Future.delayed(Duration(seconds: 3), () => setupStreams());
          },
        );

    // Stream untuk chat
    setupChatStream();

    // Stream untuk orders
    setupOrdersStream();

    // Stream untuk hotel bookings
    setupHotelBookingsStream();
  }

  void setupChatStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    chatSubscription?.cancel();
    chatSubscription = supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .order('created_at', ascending: false)
        .execute()
        .handleError((error) {
          print('Chat stream error: $error');
          // Reconnect after delay
          Future.delayed(Duration(seconds: 3), () => setupChatStream());
        })
        .listen(
          (data) {
            try {
              print('DEBUG: Received ${data.length} chat messages');
              final unreadChats =
                  data.where((msg) => msg['is_read'] == false).toList();
              print('DEBUG: Unread chats: ${unreadChats.length}');
              unreadChatsCount.value = unreadChats.length;
            } catch (e) {
              print('Error processing chat messages: $e');
            }
          },
          onError: (error) {
            print('Chat listen error: $error');
            Future.delayed(Duration(seconds: 3), () => setupChatStream());
          },
          cancelOnError: false,
        );
  }

  void setupOrdersStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', userId)
        .listen((orders) {
          int needToShipCount = 0;
          int shippingCount = 0;
          int cancelledCount = 0;
          int completedCount = 0;

          for (var order in orders) {
            switch (order['status']) {
              case 'pending':
              case 'processing':
                needToShipCount++;
                break;
              case 'shipping':
                shippingCount++;
                break;
              case 'cancelled':
                cancelledCount++;
                break;
              case 'completed':
                completedCount++;
                break;
            }
          }

          needToShip.value = needToShipCount.toString();
          shipping.value = shippingCount.toString();
          cancelled.value = cancelledCount.toString();
          completed.value = completedCount.toString();

          pendingShipmentCount.value = needToShipCount;
          pendingCancellationCount.value = orders
              .where((order) => order['status'] == 'pending_cancellation')
              .length;
        });
  }

  void setupHotelBookingsStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    supabase
        .from('hotels')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', userId)
        .execute()
        .handleError((error) {
          print('Hotel stream error: $error');
          Future.delayed(
              Duration(seconds: 3), () => setupHotelBookingsStream());
        })
        .listen(
          (hotels) {
            try {
              final hotelIds =
                  hotels.map((h) => h['id']).toList().cast<Object>();

              if (hotelIds.isNotEmpty) {
                supabase
                    .from('hotel_bookings')
                    .stream(primaryKey: ['id'])
                    .inFilter('hotel_id', hotelIds)
                    .execute()
                    .handleError((error) {
                      print('Bookings stream error: $error');
                    })
                    .listen(
                      (bookings) {
                        try {
                          final pendingBookings = bookings
                              .where((b) => b['status'] == 'pending')
                              .toList();
                          hotelBookingsCount.value = pendingBookings.length;
                        } catch (e) {
                          print('Error processing bookings: $e');
                        }
                      },
                      onError: (error) {
                        print('Bookings listen error: $error');
                      },
                      cancelOnError: false,
                    );
              }
            } catch (e) {
              print('Error processing hotels: $e');
            }
          },
          onError: (error) {
            print('Hotel listen error: $error');
          },
          cancelOnError: false,
        );
  }

  Future<void> fetchMerchantData() async {
    try {
      final response = await supabase
          .from('merchants')
          .select('store_name')
          .eq('id', supabase.auth.currentUser!.id)
          .single();

      if (response != null) {
        storeName.value = response['store_name'];
      }
    } catch (e) {
      print('Error fetching merchant data: $e');
    }
  }

  void changeIndex(int index) {
    selectedIndex.value = index;
  }

  void checkMerchantAddress() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final merchantData = await supabase
          .from('merchants')
          .select('store_address')
          .eq('id', userId)
          .single();

      if (merchantData['store_address'] == null ||
          merchantData['store_address'].toString().isEmpty) {
        Get.dialog(
          AlertDialog(
            title: const Text('Perhatian'),
            content: const Text(
                'Anda belum mengatur alamat toko. Silakan lengkapi data alamat toko Anda terlebih dahulu.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Get.back();
                  Get.to(() => EditStoreScreen());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Atur Alamat Sekarang'),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      }
    } catch (e) {
      print('Error checking merchant address: $e');
    }
  }
}
