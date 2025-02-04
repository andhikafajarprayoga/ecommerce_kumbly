import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/auth_controller.dart';

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
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildMenuCard(
            icon: Icons.local_shipping,
            title: 'Pengiriman Aktif',
            onTap: () => Get.toNamed('/courier/active-deliveries'),
          ),
          _buildMenuCard(
            icon: Icons.history,
            title: 'Riwayat Pengiriman',
            onTap: () => Get.toNamed('/courier/delivery-history'),
          ),
          _buildMenuCard(
            icon: Icons.location_on,
            title: 'Update Lokasi',
            onTap: () => Get.toNamed('/courier/update-location'),
          ),
          _buildMenuCard(
            icon: Icons.assessment,
            title: 'Performa',
            onTap: () => Get.toNamed('/courier/performance'),
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
