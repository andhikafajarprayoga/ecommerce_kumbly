import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'active_deliveries_screen.dart';
import 'pickup_orders_screen.dart';
import 'my_packages_screen.dart';

class CourierHomeScreen extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();

  CourierHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kurir Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authController.signOut();
              Get.offAllNamed('/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMenuListItem(
              icon: Icons.local_shipping,
              title: 'Pengiriman Aktif',
              subtitle: 'Lihat pengiriman yang sedang berlangsung',
              color: Colors.blue,
              onTap: () => Get.to(() => ActiveDeliveriesScreen()),
            ),
            _buildMenuListItem(
              icon: Icons.shopping_bag_sharp,
              title: 'Jemput Paket',
              subtitle: 'Jemput paket dari Seller',
              color: Colors.blue,
              onTap: () => Get.to(() => PickupOrdersScreen()),
            ),
            _buildMenuListItem(
              icon: Icons.shopping_bag_sharp,
              title: 'Paket yang dibawa',
              subtitle: 'paket siap dikirim',
              color: Colors.blue,
              onTap: () => Get.to(() => const MyPackagesScreen()),
            ),
          ],
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
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
