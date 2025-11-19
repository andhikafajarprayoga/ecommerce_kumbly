import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/auth/login_page.dart';
import 'package:kumbly_ecommerce/pages/buyer/home_screen.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../controllers/auth_controller.dart';
import '../../../screens/home_screen.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final AuthController authController = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header with Gradient
            Container(
              padding: const EdgeInsets.only(
                  top: 50, bottom: 20, left: 86, right: 86),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerRight,
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
                  // Profile Image
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
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Email
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
                    'Merchant Account',
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
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Tambahkan switch untuk buka/tutup toko
                  _StoreActiveSwitch(),
                  const SizedBox(height: 16),
                  _buildMenuCard(
                    icon: Icons.shopping_bag_outlined,
                    title: 'Beralih ke Pembeli',
                    subtitle: 'Lihat toko dari sisi pembeli',
                    onTap: () {
                      authController.isMerchant.value = false;
                      Get.offAll(() => BuyerHomeScreen());
                    },
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
                              child: const Text(
                                'Batal',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await authController.signOut();
                                Get.offAll(() => const LoginPage());
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
                          color: isLogout ? Colors.red : Colors.black87,
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

// Tambahkan widget switch status toko
class _StoreActiveSwitch extends StatefulWidget {
  @override
  State<_StoreActiveSwitch> createState() => _StoreActiveSwitchState();
}

class _StoreActiveSwitchState extends State<_StoreActiveSwitch> {
  bool? _isActive;
  bool _loading = true;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    final merchant = await supabase
        .from('merchants')
        .select('is_active')
        .eq('id', userId)
        .single();
    setState(() {
      _isActive = merchant['is_active'] != false;
      _loading = false;
    });
  }

  Future<void> _updateStatus(bool value) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _loading = true);
    await supabase
        .from('merchants')
        .update({'is_active': value})
        .eq('id', userId);
    setState(() {
      _isActive = value;
      _loading = false;
    });
    Get.snackbar(
      'Status Toko',
      value ? 'Toko dibuka' : 'Toko ditutup',
      backgroundColor: value ? Colors.green : Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          _isActive == true ? Icons.store : Icons.store_mall_directory,
          color: AppTheme.primary,
        ),
        title: Text(
          'Status Toko',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _isActive == true ? 'Buka' : 'Tutup',
          style: TextStyle(
            color: _isActive == true ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Switch(
          value: _isActive ?? true,
          activeColor: Colors.green,
          inactiveThumbColor: Colors.red,
          onChanged: (val) => _updateStatus(val),
        ),
      ),
    );
  }
}
