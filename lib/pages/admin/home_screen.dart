import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/stats_controller.dart';
import '../../pages/admin/feature/users_screen.dart';
import '../../pages/admin/feature/stores_screen.dart';
import 'pengiriman/shipments_screen.dart';
import 'laporan-pembayaran/reports_screen.dart';
import '../../pages/admin/feature/banners_screen.dart';
import '../../pages/admin/feature/payment_methods_screen.dart';
import '../../pages/admin/feature/shipping_rates_screen.dart';
import '../../pages/admin/feature/voucher_screen.dart';
import '../../pages/admin/feature/admin_chat_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();
  final StatsController statsController = Get.put(StatsController());

  AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Saraja OnlineShop',
          style: TextStyle(
            color: Colors.black87,
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
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildMenuListItem(
                            icon: Icons.people,
                            title: 'Kelola Users',
                            subtitle: 'Atur pengguna & hak akses',
                            color: Colors.blue,
                            onTap: () => Get.to(() => UsersScreen()),
                          ),
                          _buildMenuListItem(
                            icon: Icons.chat,
                            title: 'Chat',
                            subtitle: 'Buyer',
                            color: Colors.blue,
                            onTap: () => Get.to(() => AdminChatScreen()),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.store,
                            title: 'Kelola Toko',
                            subtitle: 'Kelola toko & produk',
                            color: Colors.green,
                            onTap: () => Get.to(() => StoresScreen()),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.local_shipping,
                            title: 'Pengiriman',
                            subtitle: 'Atur pengiriman & logistik',
                            color: Colors.orange,
                            onTap: () => Get.to(() => ShipmentsScreen()),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.assessment,
                            title: 'Laporan',
                            subtitle: 'Lihat statistik & analisis',
                            color: Colors.red,
                            onTap: () => Get.to(() => ReportsScreen()),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.campaign,
                            title: 'Promosi',
                            subtitle: 'Banner',
                            color: Colors.red,
                            onTap: () => Get.to(() => BannersScreen()),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.payments,
                            title: 'Pembayaran',
                            subtitle: 'Atur pembayaran',
                            color: const Color.fromARGB(255, 247, 0, 255),
                            onTap: () => Get.to(() => PaymentMethodsScreen()),
                          ),
                          _buildMenuListItem(
                            icon: Icons.discount,
                            title: 'Voucher',
                            subtitle: 'Atur voucher',
                            color: Colors.teal,
                            onTap: () => Get.to(() => VoucherScreen()),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.local_shipping_rounded,
                            title: 'Ongkir',
                            subtitle: 'Atur ongkir',
                            color: Colors.cyan,
                            onTap: () => Get.to(() => ShippingRatesScreen()),
                          ),
                        ],
                      ),
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
      padding: EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Obx(() => _buildStatCard(
                      'Total Pengguna',
                      '${statsController.totalUsers}',
                      Icons.people,
                      Colors.blue,
                    )),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Obx(() => _buildStatCard(
                      'Total Toko',
                      '${statsController.totalStores}',
                      Icons.store,
                      Colors.green,
                    )),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Pesanan Hari Ini',
                  '123',
                  Icons.shopping_cart,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuListItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.black54,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
    );
  }

  Widget _buildNotificationButton() {
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: Colors.black87),
          onPressed: () => Get.toNamed('/admin/notifications'),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: Text(
              '3',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileButton() {
    return PopupMenuButton(
      icon: CircleAvatar(
        backgroundColor: Colors.grey[200],
        child: Icon(Icons.person, color: Colors.black87),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.person_outline),
            title: Text('Profil'),
          ),
          onTap: () => Get.toNamed('/admin/profile'),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.settings_outlined),
            title: Text('Pengaturan'),
          ),
          onTap: () => Get.toNamed('/admin/settings'),
        ),
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.logout),
            title: Text('Keluar'),
          ),
          onTap: () async {
            await authController.signOut();
            Get.offAllNamed('/login');
          },
        ),
      ],
    );
  }
}
