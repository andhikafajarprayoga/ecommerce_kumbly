import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'active_deliveries_screen.dart';
import 'pickup_orders_screen.dart';
import 'my_packages_screen.dart';
import 'pickup_branch_orders_screen.dart';
import 'branch_products_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';
import '../../services/notification_service.dart';
import 'package:rxdart/rxdart.dart';

class CourierHomeScreen extends StatefulWidget {
  const CourierHomeScreen({super.key});

  @override
  State<CourierHomeScreen> createState() => _CourierHomeScreenState();
}

class _CourierHomeScreenState extends State<CourierHomeScreen> {
  final AuthController authController = Get.find<AuthController>();
  final supabase = Supabase.instance.client;
  final RxInt _unreadNotificationsCount = 0.obs;
  final RxInt _activeDeliveriesCount = 0.obs;
  final RxInt _pickupOrdersCount = 0.obs;
  final RxInt _sellerPackagesCount = 0.obs;
  final RxInt _branchPickupCount = 0.obs;
  final RxInt _branchPackagesCount = 0.obs;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationsStream();
    _setupCountsStream();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  void _setupNotificationsStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _notificationSubscription = supabase
        .from('notification_courier')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          final unreadCount =
              data.where((notif) => notif['status'] == 'unread').length;

          if (unreadCount > _unreadNotificationsCount.value) {
            final latestNotif =
                data.firstWhere((notif) => notif['status'] == 'unread');
            NotificationService.showNotification(
              title: 'Notifikasi Baru',
              body: latestNotif['message'] ?? 'Ada pesanan baru',
            );
          }

          _unreadNotificationsCount.value = unreadCount;
        });
  }

  void _setupCountsStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    print('DEBUG: Current user ID: $userId');

    _ordersSubscription = supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((data) async {
          if (mounted) {
            // Hitung pengiriman aktif (pending)
            _activeDeliveriesCount.value = data
                .where((order) =>
                    order['courier_id'] == userId &&
                    order['status'] == 'pending')
                .length;

            // Hitung jemput paket (processing)
            _pickupOrdersCount.value = data
                .where((order) =>
                    order['courier_id'] == null && // Belum ada kurir
                    order['status'] == 'processing' &&
                    order['keterangan'] ==
                        'ready') // Sesuaikan dengan pickup screen
                .length;

            // Filter dan hitung seperti sebelumnya
            var courierOrders = data
                .where((order) =>
                    order['courier_id'] == userId ||
                    order['courier_id'] == null)
                .toList();
            print('DEBUG: Orders for this courier: ${courierOrders.length}');

            // Hitung paket dari seller (ready_to_ship)
            _sellerPackagesCount.value = data
                .where((order) =>
                    order['courier_id'] == userId &&
                    order['status'] == 'ready_to_ship')
                .length;

            // Hitung jemput paket cabang (branch_pickup)
            _branchPickupCount.value = data
                .where((order) =>
                    order['courier_id'] == userId &&
                    order['status'] == 'branch_pickup')
                .length;

            // Hitung paket dari cabang (branch_delivery)
            _branchPackagesCount.value = data
                .where((order) =>
                    order['courier_id'] == userId &&
                    order['status'] == 'branch_delivery')
                .length;
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kurir Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
        elevation: 2,
        actions: [
          // Tambahkan icon notifikasi dengan badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () => Get.to(() => CourierNotificationsScreen()),
              ),
              Obx(() => _unreadNotificationsCount.value > 0
                  ? Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${_unreadNotificationsCount.value}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SizedBox()),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await authController.signOut();
              Get.offAllNamed('/login');
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() => _buildMenuListItem(
                    icon: Icons.local_shipping,
                    title: 'Pengiriman Aktif',
                    subtitle: 'Lihat pengiriman yang sedang berlangsung',
                    color: Colors.blue,
                    onTap: () => Get.to(() => ActiveDeliveriesScreen()),
                    badgeCount: _activeDeliveriesCount.value,
                  )),
              Obx(() => _buildMenuListItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Jemput Paket',
                    subtitle: 'Jemput paket dari Seller',
                    color: Colors.blue,
                    onTap: () => Get.to(() => PickupOrdersScreen()),
                    badgeCount: _pickupOrdersCount.value,
                  )),
              Obx(() => _buildMenuListItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Paket dari seller',
                    subtitle: 'paket siap dikirim',
                    color: Colors.blue,
                    onTap: () => Get.to(() => const MyPackagesScreen()),
                    badgeCount: _sellerPackagesCount.value,
                  )),
              Obx(() => _buildMenuListItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Jemput Paket Cabang',
                    subtitle: 'Jemput paket dari cabang',
                    color: Colors.blue,
                    onTap: () => Get.to(() => const PickupBranchOrdersScreen()),
                    badgeCount: _branchPickupCount.value,
                  )),
              Obx(() => _buildMenuListItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'Paket dari cabang',
                    subtitle: 'Paket dibawa dari cabang',
                    color: Colors.blue,
                    onTap: () => Get.to(() => const BranchProductsScreen()),
                    badgeCount: _branchPackagesCount.value,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuListItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    print('DEBUG: Building menu item: $title with badge count: $badgeCount');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Card(
            elevation: 3,
            shadowColor: Colors.blue.withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(15),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.blue.shade50],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 32, color: color),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: color.withOpacity(0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              right: 8,
              top: -8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
