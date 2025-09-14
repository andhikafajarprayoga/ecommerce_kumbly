import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/courier/completed_deliveries_screen.dart';
import '../../controllers/auth_controller.dart';
import 'active_deliveries_screen.dart';
import 'pickup_orders_screen.dart';
import 'my_packages_screen.dart';
import 'pickup_branch_orders_screen.dart';
import 'branch_products_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'notifications_screen.dart';
import '../../services/notification_service.dart';
import 'shipping_request.dart';
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
  final RxInt _completedDeliveriesCount = 0.obs;
  final RxInt _courierRequestBadgeCount = 0.obs;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _setupNotificationsStream();
    _setupCountsStream();
    _fetchCourierRequestBadgeCount();
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

            // Hitung paket dari seller (processing)
            _sellerPackagesCount.value = data
                .where((order) =>
                    order['courier_id'] == userId &&
                    order['status'] == 'processing')
                .length;

            // Ambil data branch_products untuk badge count jemput paket
            final branchPickupResponse = await supabase
                .from('branch_products')
                .select()
                .eq('status', 'received')
                .filter('courier_id', 'is', null);

            // Update badge count untuk jemput paket cabang
            _branchPickupCount.value = branchPickupResponse.length;

            print('DEBUG: Branch pickup count: ${_branchPickupCount.value}');

            // Ambil data branch_products untuk badge count paket dari cabang
            final branchDeliveryResponse = await supabase
                .from('branch_products')
                .select()
                .eq('courier_id', userId)
                .eq('status', 'received')
                .isFilter('shipping_status', null); // Belum dikirim

            // Update badge count untuk paket dari cabang
            _branchPackagesCount.value = branchDeliveryResponse.length;

            print(
                'DEBUG: Branch delivery count: ${_branchPackagesCount.value}');

            // Tambahkan perhitungan untuk pengiriman selesai
            _completedDeliveriesCount.value = data
                .where((order) =>
                    order['courier_id'] == userId &&
                    order['status'] == 'completed')
                .length;
          }
        });
  }

  Future<void> _fetchCourierRequestBadgeCount() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      final userResponse = await supabase
          .from('users')
          .select('full_name')
          .eq('id', user.id)
          .single();
      final courierName = userResponse['full_name'];
      final available = await supabase
          .from('shipping_requests')
          .select('id, status')
          .eq('courier_status', 'waiting');
      final my = await supabase
          .from('shipping_requests')
          .select('id, status')
          .eq('courier_name', courierName)
          .not('status', 'in', ['delivered', 'cancelled', 'completed']);
      final availableCount = (available as List)
          .where((r) => r['status'] != 'pending')
          .length;
      _courierRequestBadgeCount.value = availableCount + (my.length ?? 0);
    } catch (e) {
      _courierRequestBadgeCount.value = 0;
    }
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
            onPressed: () {
              Get.defaultDialog(
                title: 'Konfirmasi Keluar',
                titleStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                middleText: 'Apakah Anda yakin ingin keluar dari aplikasi?',
                contentPadding: const EdgeInsets.all(20),
                confirm: ElevatedButton(
                  onPressed: () async {
                    await authController.signOut();
                    Get.offAllNamed('/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text(
                    'Ya, Keluar',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                cancel: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  child: const Text('Batal'),
                ),
              );
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
              Obx(() => _buildMenuListItem(
                    icon: Icons.check_circle_outline,
                    title: 'Pengiriman Selesai',
                    subtitle: 'Riwayat pengiriman yang telah selesai',
                    color: Colors.green,
                    onTap: () => Get.to(() => CompletedDeliveriesScreen()),
                    badgeCount: _completedDeliveriesCount.value,
                  )),
              Obx(() => _buildMenuListItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Paket Kurir',
                    subtitle: 'Daftar semua paket instant',
                    color: Colors.orange,
                    onTap: () async {
                      await Get.to(() => ShippingRequestScreen());
                      _fetchCourierRequestBadgeCount();
                    },
                    badgeCount: _courierRequestBadgeCount.value,
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
