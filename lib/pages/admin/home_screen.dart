import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/stats_controller.dart';
import '../../pages/admin/feature/users_screen.dart';
import 'kelola-toko/stores_screen.dart';
import 'pengiriman/shipments_screen.dart';
import 'laporan-pembayaran/reports_screen.dart';
import '../../pages/admin/feature/banners_screen.dart';
import '../../pages/admin/feature/payment_methods_screen.dart';
import '../../pages/admin/feature/shipping_rates_screen.dart';
import '../../pages/admin/feature/voucher_screen.dart';
import '../../pages/admin/feature/admin_chat_screen.dart';
import 'withdrawal/withdrawal_screen.dart';
import 'account/account_deletion_screen.dart';
import 'feature/branch_products_screen.dart';
import '../../pages/admin/branch/branch_orders_screen.dart';
import 'payment/payment_management_screen.dart';
import '../../pages/admin/hotel/hotel_management_screen.dart';
import '../../controllers/admin_notification_controller.dart';
import 'notification/admin_notifications_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();
  final StatsController statsController = Get.put(StatsController());
  final AdminNotificationController notificationController =
      Get.put(AdminNotificationController());

  AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: Text(
          'Saraja OnlineShop',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          _buildNotificationButton(),
          _buildProfileButton(),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderStats(),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Menu Utama',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 20),
                    GridView.count(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.5,
                      children: [
                        _buildMenuCard(
                          icon: Icons.people,
                          title: 'Kelola Users',
                          subtitle: 'Atur pengguna & hak akses',
                          color: Colors.blue,
                          onTap: () => Get.to(() => UsersScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.money,
                          title: 'Pembayaran',
                          subtitle: 'Rekap Pembayaran',
                          color: Colors.blue,
                          onTap: () => Get.to(() => PaymentManagementScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.payments,
                          title: 'Pencairan',
                          subtitle: 'Pencairan dana seller',
                          color: const Color.fromARGB(255, 14, 14, 15),
                          onTap: () => Get.to(() => WithdrawalScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.chat,
                          title: 'Chat',
                          subtitle: 'Buyer',
                          color: Colors.blue,
                          onTap: () => Get.to(() => AdminChatScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.store,
                          title: 'Kelola Toko',
                          subtitle: 'Kelola toko & produk',
                          color: Colors.green,
                          onTap: () => Get.to(() => StoresScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.hotel,
                          title: 'Hotel',
                          subtitle: 'Kelola Hotel',
                          color: Colors.green,
                          onTap: () => Get.to(() => HotelManagementScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.local_shipping,
                          title: 'Pengiriman',
                          subtitle: 'ACC Pengiriman',
                          color: Colors.orange,
                          onTap: () => Get.to(() => ShipmentsScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.campaign,
                          title: 'Promosi',
                          subtitle: 'Banner',
                          color: Colors.red,
                          onTap: () => Get.to(() => BannersScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.payments,
                          title: 'Metode Pembayaran',
                          subtitle: 'Atur metode pembayaran',
                          color: const Color.fromARGB(255, 247, 0, 255),
                          onTap: () => Get.to(() => PaymentMethodsScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.discount,
                          title: 'Voucher',
                          subtitle: 'Atur Voucher dan Diskon',
                          color: Colors.teal,
                          onTap: () => Get.to(() => VoucherScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.local_shipping_rounded,
                          title: 'Ongkir',
                          subtitle: 'Atur ongkir',
                          color: Colors.cyan,
                          onTap: () => Get.to(() => ShippingRatesScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.delete,
                          title: 'Hapus Akun',
                          subtitle: 'Seller & User',
                          color: Colors.cyan,
                          onTap: () => Get.to(() => AccountDeletionScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.store,
                          title: 'Kelola Cabang',
                          subtitle: 'Kelola Barang yang dikirim',
                          color: Colors.cyan,
                          onTap: () => Get.to(() => BranchProductsScreen()),
                        ),
                        _buildMenuCard(
                          icon: Icons.receipt_long,
                          title: 'Pesanan Branch',
                          subtitle: 'Kelola pesanan manual cabang',
                          color: Colors.deepPurple,
                          onTap: () => Get.to(() => BranchOrdersScreen()),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStats() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.normal,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Obx(() => _buildStatCard(
                      'Total Pengguna',
                      '${statsController.totalUsers}',
                      Icons.people,
                      Colors.white,
                      'Aktif ',
                    )),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Obx(() => _buildStatCard(
                      'Total Toko',
                      '${statsController.totalStores}',
                      Icons.store,
                      Colors.white,
                      'Toko terverifikasi',
                    )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () => Get.to(() => AdminNotificationsScreen()),
        ),
        Obx(() {
          if (notificationController.unreadCount.value > 0) {
            return Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${notificationController.unreadCount}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ),
            );
          }
          return SizedBox();
        }),
      ],
    );
  }

  Widget _buildProfileButton() {
    return IconButton(
      icon: Icon(Icons.logout, color: Colors.white),
      onPressed: () {
        Get.defaultDialog(
          title: 'Konfirmasi',
          middleText: 'Apakah Anda yakin ingin keluar?',
          textConfirm: 'Ya',
          textCancel: 'Tidak',
          confirmTextColor: Colors.white,
          onConfirm: () async {
            await authController.signOut();
            Get.offAllNamed('/login');
          },
        );
      },
    );
  }
}
