import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/buyer/home_screen.dart';
import 'package:kumbly_ecommerce/pages/buyer/profile/alamat_screen.dart';
import 'package:kumbly_ecommerce/pages/buyer/profile/pesanan_saya.dart';
import 'package:kumbly_ecommerce/pages/buyer/profile/setting_screen.dart';
import '../../../controllers/auth_controller.dart';
import '../../../screens/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/merchant/merchant_agreement_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final AuthController authController = Get.find<AuthController>();
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              authController.currentUser.value?.email ?? '',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 16),
          // Switch untuk beralih antara Buyer dan Merchant
          Center(
              child: Obx(() => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Buyer'),
                      Switch(
                        value: authController.isMerchant.value,
                        onChanged: (value) async {
                          if (value) {
                            // Cek role user saat ini
                            final userData = await supabase
                                .from('users')
                                .select('role')
                                .eq('id', supabase.auth.currentUser!.id)
                                .single();

                            if (userData['role'] == 'seller') {
                              // Jika sudah seller, langsung ke merchant home
                              authController.isMerchant.value = value;
                              Get.offAll(() => MerchantHomeScreen());
                            } else {
                              // Jika belum seller, ke halaman agreement
                              Get.to(() => MerchantAgreementScreen());
                            }
                          } else {
                            authController.isMerchant.value = value;
                            Get.offAll(() => BuyerHomeScreen());
                          }
                        },
                      ),
                      const Text('Merchant'),
                    ],
                  ))),

          const SizedBox(height: 32),

          // Menu Merchant
          ListTile(
            leading: const Icon(Icons.store),
            title: const Text('Merchant'),
            onTap: () async {
              // Cek role user saat ini
              final userData = await supabase
                  .from('users')
                  .select('role')
                  .eq('id', supabase.auth.currentUser!.id)
                  .single();

              if (userData['role'] == 'seller') {
                // Jika sudah seller, langsung ke merchant home
                authController.isMerchant.value = true;
                Get.offAll(() => MerchantHomeScreen());
              } else {
                // Jika belum seller, ke halaman agreement
                Get.to(() => MerchantAgreementScreen());
              }
            },
          ),

          // Menu Items
          ListTile(
            leading: const Icon(Icons.shopping_bag),
            title: const Text('Pesanan Saya'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => PesananSayaScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Alamat'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => AlamatScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Pengaturan'),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SettingScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Keluar'),
            onTap: () {
              Get.dialog(
                AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await authController.signOut();
                        Get.offAll(() => const HomeScreen());
                      },
                      child: const Text('Ya'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
