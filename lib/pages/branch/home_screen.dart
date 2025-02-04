import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';

class BranchHomeScreen extends StatelessWidget {
  final AuthController authController = Get.find<AuthController>();

  BranchHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cabang Dashboard'),
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
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildMenuCard(
            icon: Icons.inventory,
            title: 'Kelola Stok',
            onTap: () => Get.toNamed('/branch/inventory'),
          ),
          _buildMenuCard(
            icon: Icons.local_shipping,
            title: 'Pengiriman',
            onTap: () => Get.toNamed('/branch/shipments'),
          ),
          _buildMenuCard(
            icon: Icons.people,
            title: 'Kelola Kurir',
            onTap: () => Get.toNamed('/branch/couriers'),
          ),
          _buildMenuCard(
            icon: Icons.assessment,
            title: 'Laporan Cabang',
            onTap: () => Get.toNamed('/branch/reports'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
