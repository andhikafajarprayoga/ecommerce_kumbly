import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/buyer/profile/alamat_screen.dart';
import 'package:kumbly_ecommerce/pages/buyer/profile/pesanan_saya.dart';
import 'package:kumbly_ecommerce/pages/buyer/profile/setting_screen.dart';
import '../../../controllers/auth_controller.dart';
import '../../../screens/home_screen.dart';
import '../../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/merchant/merchant_agreement_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:kumbly_ecommerce/pages/buyer/profile/delete_account_screen.dart';
import 'package:kumbly_ecommerce/auth/login_page.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthController authController = Get.find<AuthController>();
  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> _updateProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final String fileName =
          '${supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File(image.path);

      await supabase.storage.from('profile_images').upload(fileName, file);

      final imageUrl =
          supabase.storage.from('profile_images').getPublicUrl(fileName);

      await supabase.from('users').update({'image_url': imageUrl}).eq(
          'id', supabase.auth.currentUser!.id);

      await authController.refreshUser();
      setState(() {}); // Refresh UI

      Get.back();
      Get.snackbar(
        'Sukses',
        'Foto profil berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Gagal memperbarui foto profil: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _deleteProfileImage() async {
    try {
      Get.dialog(
        AlertDialog(
          title: const Text('Hapus Foto Profil'),
          content: const Text('Apakah Anda yakin ingin menghapus foto profil?'),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text(
                'Batal',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () async {
                Get.back();
                Get.dialog(
                  const Center(child: CircularProgressIndicator()),
                  barrierDismissible: false,
                );

                // Dapatkan current image_url
                final userData = await supabase
                    .from('users')
                    .select('image_url')
                    .eq('id', supabase.auth.currentUser!.id)
                    .single();

                if (userData['image_url'] != null) {
                  // Extract filename dari URL
                  final uri = Uri.parse(userData['image_url']);
                  final fileName = uri.pathSegments.last;

                  // Hapus file dari storage
                  await supabase.storage
                      .from('profile_images')
                      .remove([fileName]);

                  // Update users table
                  await supabase.from('users').update({'image_url': null}).eq(
                      'id', supabase.auth.currentUser!.id);

                  await authController.refreshUser();
                  setState(() {}); // Refresh UI

                  Get.back();
                  Get.snackbar(
                    'Sukses',
                    'Foto profil berhasil dihapus',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                }
              },
              child: const Text(
                'Hapus',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Gagal menghapus foto profil: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      return Scaffold(
        body: Container(
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primary.withOpacity(0.9),
                AppTheme.primary.withOpacity(0.6),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_circle,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Silakan login untuk melihat profil',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Get.to(() => LoginPage()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Login',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final sellerId = authController.currentUser.value?.id ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(
                  top: 50, bottom: 20, left: 86, right: 86),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primary,
                    AppTheme.primary.withOpacity(0.8),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      Get.bottomSheet(
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 40,
                                height: 4,
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Ubah Foto Profil'),
                                onTap: () {
                                  Get.back();
                                  _updateProfileImage();
                                },
                              ),
                              ListTile(
                                leading:
                                    const Icon(Icons.delete, color: Colors.red),
                                title: const Text(
                                  'Hapus Foto Profil',
                                  style: TextStyle(color: Colors.red),
                                ),
                                onTap: () {
                                  Get.back();
                                  _deleteProfileImage();
                                },
                              ),
                            ],
                          ),
                        ),
                        backgroundColor: Colors.transparent,
                      );
                    },
                    child: Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: StreamBuilder(
                            stream: supabase
                                .from('users')
                                .stream(primaryKey: ['id']).eq(
                                    'id', supabase.auth.currentUser!.id),
                            builder: (context, snapshot) {
                              if (snapshot.hasData &&
                                  snapshot.data!.isNotEmpty) {
                                final imageUrl = snapshot.data![0]['image_url'];
                                return CircleAvatar(
                                  radius: 50,
                                  backgroundColor: Colors.white,
                                  backgroundImage: imageUrl != null
                                      ? NetworkImage(imageUrl)
                                      : null,
                                  child: imageUrl == null
                                      ? Icon(Icons.person,
                                          size: 50, color: AppTheme.primary)
                                      : null,
                                );
                              }
                              return CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.person,
                                    size: 50, color: AppTheme.primary),
                              );
                            },
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 20, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authController.currentUser.value?.email ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Buyer Account',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                children: [
                  _buildMenuCard(
                    icon: Icons.store_rounded,
                    title: 'Buka Toko',
                    subtitle: 'Mulai berjualan di Saraja',
                    onTap: () async {
                      final userData = await supabase
                          .from('users')
                          .select('role')
                          .eq('id', supabase.auth.currentUser!.id)
                          .single();

                      if (userData['role'] == 'seller') {
                        authController.isMerchant.value = true;
                        Get.offAll(
                            () => MerchantHomeScreen(sellerId: sellerId));
                      } else {
                        Get.to(() => MerchantAgreementScreen());
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildMenuCard(
                    icon: Icons.shopping_bag_rounded,
                    title: 'Pesanan Saya',
                    subtitle: 'Lihat status pesanan Anda',
                    onTap: () => Get.to(() => PesananSayaScreen()),
                    badge: StreamBuilder(
                      stream: supabase
                          .from('orders')
                          .stream(primaryKey: ['id']).eq(
                              'buyer_id', supabase.auth.currentUser!.id),
                      builder: (context, ordersSnapshot) {
                        return StreamBuilder(
                          stream: supabase
                              .from('hotel_bookings')
                              .stream(primaryKey: ['id']).eq(
                                  'user_id', supabase.auth.currentUser!.id),
                          builder: (context, hotelsSnapshot) {
                            int totalOrders = 0;

                            if (ordersSnapshot.hasData &&
                                ordersSnapshot.data != null) {
                              final activeOrders =
                                  ordersSnapshot.data!.where((order) {
                                final status =
                                    order['status'].toString().toLowerCase();
                                return status != 'completed' &&
                                    status != 'cancelled' &&
                                    status != 'delivered';
                              });
                              totalOrders += activeOrders.length;
                            }

                            if (hotelsSnapshot.hasData &&
                                hotelsSnapshot.data != null) {
                              final activeBookings =
                                  hotelsSnapshot.data!.where((booking) {
                                final status =
                                    booking['status'].toString().toLowerCase();
                                return status != 'completed' &&
                                    status != 'cancelled';
                              });
                              totalOrders += activeBookings.length;
                            }

                            return totalOrders > 0
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      totalOrders.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink();
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.location_on_rounded,
                    title: 'Alamat',
                    subtitle: 'Kelola alamat pengiriman',
                    onTap: () => Get.to(() => AlamatScreen()),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.settings_rounded,
                    title: 'Pengaturan',
                    subtitle: 'Atur preferensi akun',
                    onTap: () => Get.to(() => SettingScreen()),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.account_circle_rounded,
                    title: 'Hapus akun',
                    subtitle: 'Ajukan penghapusan akun',
                    onTap: () => Get.to(() => const DeleteAccountScreen()),
                  ),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.logout_rounded,
                    title: 'Keluar',
                    subtitle: 'Keluar dari akun Anda',
                    isLogout: true,
                    onTap: () {
                      Get.dialog(
                        AlertDialog(
                          title: const Text('Konfirmasi'),
                          content:
                              const Text('Apakah Anda yakin ingin keluar?'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: Text(
                                'Batal',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await authController.signOut();
                                Get.offAllNamed('/buyer/home_screen');
                              },
                              child: const Text(
                                'Ya',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isLogout = false,
    Widget? badge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isLogout
                        ? Colors.red.withOpacity(0.1)
                        : AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: isLogout ? Colors.red : AppTheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isLogout ? Colors.red : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badge != null) badge,
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey[400],
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
