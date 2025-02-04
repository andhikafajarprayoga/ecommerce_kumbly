import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';

class AdminHomeScreen extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();

  AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          'Dashboard Admin',
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
                            title: 'Kelola Pengguna',
                            subtitle: 'Atur pengguna & hak akses',
                            color: Colors.blue,
                            onTap: () => Get.toNamed('/admin/users'),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.store,
                            title: 'Kelola Toko',
                            subtitle: 'Kelola toko & produk',
                            color: Colors.green,
                            onTap: () => Get.toNamed('/admin/stores'),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.local_shipping,
                            title: 'Pengiriman',
                            subtitle: 'Atur pengiriman & logistik',
                            color: Colors.orange,
                            onTap: () => Get.toNamed('/admin/shipments'),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.assessment,
                            title: 'Laporan',
                            subtitle: 'Lihat statistik & analisis',
                            color: Colors.purple,
                            onTap: () => Get.toNamed('/admin/reports'),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.campaign,
                            title: 'Promosi',
                            subtitle: 'Atur voucher & diskon',
                            color: Colors.red,
                            onTap: () => Get.toNamed('/admin/promotions'),
                          ),
                          _buildDivider(),
                          _buildMenuListItem(
                            icon: Icons.support_agent,
                            title: 'Layanan Pelanggan',
                            subtitle: 'Kelola tiket bantuan',
                            color: Colors.teal,
                            onTap: () => Get.toNamed('/admin/support'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    _buildRecentActivities(),
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
                child: _buildStatCard(
                  'Total Pengguna',
                  '12,345',
                  Icons.people,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Total Toko',
                  '1,234',
                  Icons.store,
                  Colors.green,
                ),
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

  Widget _buildRecentActivities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aktivitas Terbaru',
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
          child: ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (context, index) => Divider(),
            itemBuilder: (context, index) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors
                      .primaries[index % Colors.primaries.length]
                      .withOpacity(0.2),
                  child: Icon(
                    Icons.notification_important,
                    color: Colors.primaries[index % Colors.primaries.length],
                  ),
                ),
                title: Text('Aktivitas ${5 - index}'),
                subtitle: Text('Deskripsi aktivitas terbaru ${5 - index}'),
                trailing: Text(
                  '${index + 1}m yang lalu',
                  style: TextStyle(color: Colors.black54),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
