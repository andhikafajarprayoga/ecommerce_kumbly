import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'package:kumbly_ecommerce/pages/merchant/chats/chat_list_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/finance/bank_accounts_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/product/product_list_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/profile/profile_screen.dart';
import '../../controllers/product_controller.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/buyer/home_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/order/order_list_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/order/finance_summary_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/order/performance_screenn.dart';
import 'package:kumbly_ecommerce/pages/merchant/order/shipping_management_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/order/cancellation_requests_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/profile/edit_store_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/hotel/hotel_management_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/hotel/hotel_bookings_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/notification/notification_seller_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

class MerchantHomeScreen extends StatefulWidget {
  final String sellerId;
  const MerchantHomeScreen({super.key, required this.sellerId});

  @override
  _MerchantHomeScreenState createState() => _MerchantHomeScreenState();
}

class _MerchantHomeScreenState extends State<MerchantHomeScreen> {
  final ProductController productController = Get.put(ProductController());
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  int _selectedIndex = 0;
  PageController _pageController = PageController();
  int _currentBannerIndex = 0;
  int unreadNotifications = 0; // Ganti dengan logika notifikasi yang sebenarnya
  final RxInt _unreadChatsCount = 0.obs;
  late Stream<int> _unreadChatsStream;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        // Handle tap notification
        if (details.payload != null) {
          final data = jsonDecode(details.payload!);
          if (data['type'] == 'notification') {
            Get.to(() => NotificationSellerScreen());
          }
        }
      },
    );
    _setupUnreadChatsStream();
    _setupNotificationListeners();
  }

  void _setupUnreadChatsStream() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Stream untuk chat_messages dengan realtime updates
    _unreadChatsStream = Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .execute()
        .map((messages) {
          // Filter pesan yang belum dibaca dan bukan dari user saat ini
          final unreadMessages = messages
              .where((msg) => !msg['is_read'] && msg['sender_id'] != userId);

          // Hitung jumlah room unik dengan pesan belum dibaca
          final unreadRooms =
              unreadMessages.map((msg) => msg['room_id']).toSet();

          return unreadRooms.length;
        })
        .asBroadcastStream(); // Memastikan stream bisa didengarkan oleh multiple listeners

    // Subscribe ke stream untuk update badge
    _unreadChatsStream.listen(
      (count) => _unreadChatsCount.value = count,
      onError: (error) => print('Error in chat stream: $error'),
    );
  }

  void _setupNotificationListeners() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    print('Setting up notification listener for merchant: $userId');

    try {
      supabase
          .from('notifikasi_seller')
          .stream(primaryKey: ['id'])
          .order('created_at',
              ascending: false) // Urutkan notifikasi terbaru dulu
          .listen(
            (List<Map<String, dynamic>> notifications) {
              try {
                print('Processing notifications: ${notifications.length}');
                if (notifications.isEmpty) return;

                // Filter hanya notifikasi yang belum dibaca
                final newNotifications = notifications
                    .where((notif) => notif['is_read'] == false)
                    .toList();

                if (newNotifications.isEmpty) return;

                // Ambil notifikasi terbaru
                final latestNotif = newNotifications.first;
                print('Latest notification: $latestNotif');

                final now = DateTime.now().toUtc();
                final notifTime =
                    DateTime.tryParse(latestNotif['created_at'] ?? '');

                if (notifTime == null) {
                  print('Invalid notification time');
                  return;
                }

                final difference = now.difference(notifTime).inSeconds.abs();
                print('Time difference: $difference seconds');

                // Tentukan judul berdasarkan jenis notifikasi
                String title = 'Notifikasi Baru';
                if (latestNotif['order_id'] != null) {
                  title = 'Pesanan Baru';
                } else if (latestNotif['booking_id'] != null) {
                  title = 'Booking Baru';
                }

                print(
                    'Showing notification: $title - ${latestNotif['message']}');
                _showNotification(
                  title,
                  latestNotif['message'] ?? 'Ada notifikasi baru',
                );

                // Update is_read setelah menampilkan notifikasi
                supabase
                    .from('notifikasi_seller')
                    .update({'is_read': true})
                    .eq('id', latestNotif['id'])
                    .then((_) => print('Notification marked as read'));
              } catch (e) {
                print('Error processing notification: $e');
              }
            },
            onError: (error) {
              print('Listen error: $error');
            },
            cancelOnError: false,
          );
    } catch (e) {
      print('Setup error: $e');
    }
  }

  void _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'notifications_seller_channel',
      'Seller Notifications',
      channelDescription: 'Channel for seller notifications',
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

    // Gunakan timestamp sebagai ID notifikasi
    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.show(
      notificationId, // Gunakan notificationId yang valid
      title,
      body,
      platformDetails,
      payload: jsonEncode({
        'type': 'notification',
        'data': {
          'title': title,
          'message': body,
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _screens = [
      _HomeMenu(),
      ChatListScreen(sellerId: widget.sellerId),
      ProfileScreen(),
    ];

    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                children: [
                  const Icon(Icons.chat_bubble_rounded),
                  Obx(() => _unreadChatsCount.value > 0
                      ? Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: Text(
                              _unreadChatsCount.value.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : const SizedBox()),
                ],
              ),
              label: 'Chat',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: Colors.grey[400],
          backgroundColor: Colors.white,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
        ),
      ),
    );
  }
}

class _HomeMenu extends StatefulWidget {
  @override
  _HomeMenuState createState() => _HomeMenuState();
}

class _HomeMenuState extends State<_HomeMenu> {
  final supabase = Supabase.instance.client;
  final storeName = ''.obs;
  final needToShip = '0'.obs;
  final shipping = '0'.obs;
  final cancelled = '0'.obs;
  final completed = '0'.obs;
  final RxInt hotelBookingsCount = 0.obs;
  StreamSubscription? hotelStreamSubscription;
  StreamSubscription? bookingStreamSubscription;
  final RxInt pendingShipmentCount = 0.obs;
  final RxInt pendingCancellationCount = 0.obs;

  PageController _pageController = PageController();
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkMerchantAddress();
    _setupMerchantData();
    _setupOrdersCount();
    _setupHotelBookingsStream();
    _setupOrdersStream();
  }

  @override
  void dispose() {
    hotelStreamSubscription?.cancel();
    bookingStreamSubscription?.cancel();
    super.dispose();
  }

  void _setupMerchantData() {
    _fetchMerchantData();
  }

  void _setupOrdersCount() {
    _fetchOrdersCount();
  }

  void _setupHotelBookingsStream() {
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return;

    try {
      hotelStreamSubscription?.cancel();
      hotelStreamSubscription = supabase
          .from('hotels')
          .stream(primaryKey: ['id'])
          .eq('merchant_id', userId)
          .execute()
          .listen((hotels) {
            final hotelIds = hotels.map((h) => h['id']).toList();

            bookingStreamSubscription?.cancel();
            bookingStreamSubscription = supabase
                .from('hotel_bookings')
                .stream(primaryKey: ['id'])
                .execute()
                .listen((bookings) {
                  final pendingBookings = bookings
                      .where((booking) =>
                          hotelIds.contains(booking['hotel_id']) &&
                          booking['status'] == 'pending')
                      .toList();

                  hotelBookingsCount.value = pendingBookings.length;
                });
          });
    } catch (e) {
      print('Debug: Error: $e');
    }
  }

  void _setupOrdersStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Listen to orders changes
    supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('merchant_id', userId)
        .execute()
        .listen((orders) {
          // Count pending shipments
          final pendingShipments =
              orders.where((order) => order['status'] == 'pending').length;

          // Count pending cancellations - Diperbarui untuk menghitung status pending_cancellation
          final pendingCancellations = orders
              .where((order) => order['status'] == 'pending_cancellation')
              .length;

          pendingShipmentCount.value = pendingShipments;
          pendingCancellationCount.value = pendingCancellations;

          // Update cancelled count untuk status card
          cancelled.value = pendingCancellations.toString();
        });
  }

  Future<void> _checkMerchantAddress() async {
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

  @override
  Widget build(BuildContext context) {
    _fetchMerchantData();
    _fetchOrdersCount();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header Profile Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.store,
                        color: AppTheme.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(() => Text(
                                storeName.value.isEmpty
                                    ? 'Memuat...'
                                    : storeName.value,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              )),
                          Text(
                            'sarajaonlineshop.com',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.notifications_outlined,
                            color: Colors.red,
                            size: 24,
                          ),
                          onPressed: () =>
                              Get.to(() => NotificationSellerScreen()),
                        ),
                        StreamBuilder<List<Map<String, dynamic>>>(
                          stream: supabase
                              .from('notifikasi_seller')
                              .select()
                              .eq('merchant_id',
                                  supabase.auth.currentUser?.id ?? '')
                              .eq('is_read', false)
                              .order('created_at', ascending: false)
                              .asStream(),
                          builder: (context, snapshot) {
                            final unreadCount =
                                (snapshot.data as List?)?.length ?? 0;
                            if (unreadCount == 0) return SizedBox();

                            return Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.swap_horiz,
                          size: 14, color: Colors.white),
                      label: const Text('Jadi Pembeli?'),
                      onPressed: () {
                        Get.dialog(
                          AlertDialog(
                            title: const Text('Konfirmasi'),
                            content: const Text(
                                'Apakah Anda ingin beralih ke mode pembeli?'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: const Text('Batal'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Get.back();
                                  Get.offAll(() =>
                                      BuyerHomeScreen()); // Pastikan import HomeScreen
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Ya, Lanjutkan'),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),

              // Banner Section dengan Indicator
              Container(
                height: 150,
                margin:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Status Pesanan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => Get.to(() => OrderListScreen(
                              sellerId: Supabase
                                  .instance.client.auth.currentUser!.id)),
                          icon: const Icon(Icons.arrow_forward,
                              size: 13, color: AppTheme.primary),
                          label: const Text('Lihat Semua'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                const Color.fromARGB(255, 143, 136, 138),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildOrderStatusItem(
                          icon: Icons.inventory_2,
                          label: 'Belum Dikirim',
                          count: needToShip,
                          onTap: () {},
                          color: Colors.orange,
                        ),
                        _buildOrderStatusItem(
                          icon: Icons.local_shipping,
                          label: 'Sedang Dikirim',
                          count: shipping,
                          onTap: () {},
                          color: Colors.blue,
                        ),
                        _buildOrderStatusItem(
                          icon: Icons.cancel,
                          label: 'Pembatalan',
                          count: cancelled,
                          onTap: () {},
                          color: Colors.red,
                        ),
                        _buildOrderStatusItem(
                          icon: Icons.check_circle,
                          label: 'Selesai',
                          count: completed,
                          onTap: () {},
                          color: Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Menu Grid Section
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menu Toko',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 4,
                      mainAxisSpacing: 11,
                      crossAxisSpacing: 11,
                      children: [
                        _buildMenuItem(
                          context: context,
                          icon: Icons.inventory_2,
                          label: 'Produk',
                          onTap: () => Get.to(() => ProductListScreen()),
                        ),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.account_balance_wallet,
                          label: 'Keuangan',
                          onTap: () => Get.to(() => FinanceSummaryScreen()),
                        ),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.analytics,
                          label: 'Performa',
                          onTap: () => Get.to(() => PerformanceScreen()),
                        ),
                        Obx(() => _buildMenuItem(
                              context: context,
                              icon: Icons.local_shipping,
                              label: 'Pengiriman',
                              onTap: () => Get.to(
                                  () => const ShippingManagementScreen()),
                              badgeCount: pendingShipmentCount.value,
                            )),
                        Obx(() => _buildMenuItem(
                              context: context,
                              icon: Icons.cancel,
                              label: 'Pembatalan',
                              onTap: () => Get.to(
                                  () => const CancellationRequestsScreen()),
                              badgeCount: pendingCancellationCount.value,
                            )),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.store,
                          label: 'Edit Toko',
                          onTap: () => Get.to(() => EditStoreScreen()),
                        ),
                        Obx(() => _buildMenuItem(
                              context: context,
                              icon: Icons.hotel,
                              label: 'Hotel',
                              onTap: () =>
                                  Get.to(() => HotelManagementScreen()),
                              badgeCount: hotelBookingsCount.value,
                            )),
                        _buildMenuItem(
                          context: context,
                          icon: Icons.account_balance,
                          label: 'Rekening',
                          onTap: () {
                            Get.to(() => BankAccountsScreen());
                          },
                        ),
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

  Future<void> _fetchMerchantData() async {
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

  Future<void> _fetchOrdersCount() async {
    try {
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        print('Error: User belum login atau ID tidak ditemukan.');
        return;
      }

      final currentUserId = currentUser.id;

      // Coba ambil semua orders terlebih dahulu

      final allOrders = await supabase.from('orders').select('*');

      // Kemudian ambil orders untuk merchant specific

      final response = await supabase
          .from('orders')
          .select('*')
          .eq('merchant_id', currentUserId)
          .order('created_at', ascending: false);

      if (response == null || response.isEmpty) {
        print('Tidak ada data orders yang ditemukan untuk merchant ini.');
        return;
      }

      int needToShipCount = 0;
      int shippingCount = 0;
      int cancelledCount = 0;
      int completedCount = 0;

      for (var order in response) {
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
    } catch (e, stackTrace) {
      print('Error fetching orders count:');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
    }
  }

  Widget _buildOrderStatusItem({
    required IconData icon,
    required String label,
    required RxString count,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        // Tambahkan navigasi ke CancellationRequestsScreen saat status pembatalan diklik
        if (label == 'Pembatalan') {
          Get.to(() => const CancellationRequestsScreen());
        } else {
          onTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Obx(() => Text(
                  count.value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                )),
            const SizedBox(height: 4),
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ),
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  right: -8,
                  top: -8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final dynamic product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProductCard({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                      product.imageUrl ?? 'https://via.placeholder.com/150'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Product Info
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp ${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: onEdit,
                      child: const Text('Edit'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
