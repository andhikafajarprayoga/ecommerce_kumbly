import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';
import 'active_deliveries_screen.dart';
import 'pickup_orders_screen.dart';
import 'my_packages_screen.dart';
import 'pickup_branch_orders_screen.dart';
import 'branch_products_screen.dart';

class CourierHomeScreen extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();

  CourierHomeScreen({super.key});

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
              _buildMenuListItem(
                icon: Icons.local_shipping,
                title: 'Pengiriman Aktif',
                subtitle: 'Lihat pengiriman yang sedang berlangsung',
                color: Colors.blue,
                onTap: () => Get.to(() => ActiveDeliveriesScreen()),
              ),
              _buildMenuListItem(
                icon: Icons.local_shipping_outlined,
                title: 'Jemput Paket',
                subtitle: 'Jemput paket dari Seller',
                color: Colors.blue,
                onTap: () => Get.to(() => PickupOrdersScreen()),
              ),
              _buildMenuListItem(
                icon: Icons.receipt_long_rounded,
                title: 'Paket dari seller',
                subtitle: 'paket siap dikirim',
                color: Colors.blue,
                onTap: () => Get.to(() => const MyPackagesScreen()),
              ),
              _buildMenuListItem(
                icon: Icons.local_shipping_outlined,
                title: 'Jemput Paket Cabang',
                subtitle: 'Jemput paket dari cabang',
                color: Colors.blue,
                onTap: () => Get.to(() => const PickupBranchOrdersScreen()),
              ),
              _buildMenuListItem(
                icon: Icons.local_shipping_outlined,
                title: 'Paket dari cabang',
                subtitle: 'Paket dibawa dari cabang',
                color: Colors.blue,
                onTap: () => Get.to(() => const BranchProductsScreen()),
              ),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
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
    );
  }
}
