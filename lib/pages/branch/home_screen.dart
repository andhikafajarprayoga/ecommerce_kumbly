import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/branch/products_screen.dart';
import 'package:kumbly_ecommerce/pages/branch/receive_package_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:kumbly_ecommerce/pages/branch/address_screen.dart';
import 'package:kumbly_ecommerce/pages/branch/manual_order_screen.dart';

class BranchHomeScreen extends StatefulWidget {
  const BranchHomeScreen({super.key});

  @override
  State<BranchHomeScreen> createState() => _BranchHomeScreenState();
}

class _BranchHomeScreenState extends State<BranchHomeScreen> {
  final AuthController authController = Get.find<AuthController>();
  final supabase = Supabase.instance.client;

  // Data Streams
  late Stream<List<Map<String, dynamic>>> pendingOrdersStream;

  @override
  void initState() {
    super.initState();
    _initializeStreams();
  }

  void _initializeStreams() {
    // Stream untuk pesanan yang pending
    pendingOrdersStream = supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'shipping')
        .execute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Dashboard Cabang'),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () => _showNotifications(),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () => _showLogoutDialog(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _initializeStreams();
        });
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeCard(),
            const SizedBox(height: 24),
            _buildStatisticsSection(),
            const SizedBox(height: 24),
            _buildMenuGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return StreamBuilder(
      stream: supabase
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', authController.currentUser.value?.id ?? '')
          .execute(),
      builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        final branchName =
            snapshot.data?.firstOrNull?['full_name'] ?? 'Loading...';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primary.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Datang',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                branchName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistik Hari Ini',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Paket Diterima',
                _getDeliveredOrdersStream(),
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Dalam Pengiriman',
                _getInTransitOrdersStream(),
                Icons.local_shipping,
                Colors.blue,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    Stream<List<Map<String, dynamic>>> stream,
    IconData icon,
    Color color, {
    int Function(List<Map<String, dynamic>>)? filter,
  }) {
    return StreamBuilder(
      stream: stream,
      builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count =
              filter != null ? filter(snapshot.data!) : snapshot.data!.length;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildMenuCard(
          title: 'Daftar Produk',
          icon: Icons.inventory_2,
          onTap: () => Get.to(() => const BranchProductsScreen()),
        ),
        _buildMenuCard(
          title: 'Menerima Paket',
          icon: Icons.local_shipping,
          onTap: () => Get.to(() => const ReceivePackageScreen()),
        ),
        _buildMenuCard(
          title: 'Kelola Alamat',
          icon: Icons.location_on,
          onTap: () => Get.to(() => const AddressScreen()),
        ),
        _buildMenuCard(
          title: 'Buat Pesanan',
          icon: Icons.add_shopping_cart,
          onTap: () => Get.to(() => const ManualOrderScreen()),
        ),
      ],
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
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
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications() {
    // TODO: Implement notifications
    Get.snackbar(
      'Notifikasi',
      'Fitur notifikasi akan segera hadir',
      backgroundColor: Colors.grey[800],
      colorText: Colors.white,
    );
  }

  void _showLogoutDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await authController.signOut();
              Get.offAllNamed('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showReceivePackageDialog() {
    final orderId = TextEditingController();
    final courierHandoverPhoto = Rx<File?>(null);

    Get.dialog(
      AlertDialog(
        title: const Text('Terima Paket dari Kurir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: orderId,
              decoration: const InputDecoration(
                labelText: 'Order ID',
                hintText: 'Masukkan ID pesanan',
              ),
            ),
            const SizedBox(height: 16),
            Obx(() => courierHandoverPhoto.value == null
                ? ElevatedButton(
                    onPressed: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1024,
                        imageQuality: 75,
                      );
                      if (image != null) {
                        courierHandoverPhoto.value = File(image.path);
                      }
                    },
                    child: const Text('Ambil Foto Serah Terima'),
                  )
                : Column(
                    children: [
                      Image.file(
                        courierHandoverPhoto.value!,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                      TextButton(
                        onPressed: () => courierHandoverPhoto.value = null,
                        child: const Text('Hapus Foto'),
                      ),
                    ],
                  )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => _processPackageReceival(
              orderId.text,
              courierHandoverPhoto.value,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Terima Paket'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPackageReceival(String orderId, File? photo) async {
    try {
      if (orderId.isEmpty) {
        throw 'Order ID tidak boleh kosong';
      }
      if (photo == null) {
        throw 'Foto serah terima harus diambil';
      }

      // Validasi order
      final order =
          await supabase.from('orders').select().eq('id', orderId).single();

      if (order == null) {
        throw 'Order tidak ditemukan';
      }
      if (order['status'] != 'shipping') {
        throw 'Status order harus shipping';
      }

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // Upload foto
      final String fileName =
          'handover_${orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('handover_photos').upload(fileName, photo);
      final photoUrl =
          supabase.storage.from('handover_photos').getPublicUrl(fileName);

      // Update order
      await supabase.from('orders').update({
        'status': 'delivered',
        'courier_handover_photo': photoUrl,
      }).eq('id', orderId);

      Get.back(); // Tutup loading dialog
      Get.back(); // Tutup form dialog

      Get.snackbar(
        'Sukses',
        'Paket berhasil diterima',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back(); // Tutup loading dialog jika error
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Stream<List<Map<String, dynamic>>> _getDeliveredOrdersStream() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'delivered')
        .execute();
  }

  Stream<List<Map<String, dynamic>>> _getInTransitOrdersStream() {
    return supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('status', 'shipping')
        .execute();
  }
}
