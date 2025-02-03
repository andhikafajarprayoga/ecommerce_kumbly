import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_merchant_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';

class MerchantAgreementScreen extends StatelessWidget {
  MerchantAgreementScreen({super.key});

  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menjadi Merchant'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Syarat dan Ketentuan Merchant',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Merchant wajib menyediakan informasi yang akurat tentang produk\n'
              '2. Merchant bertanggung jawab atas kualitas produk\n'
              '3. Merchant wajib merespon pesanan dalam 1x24 jam\n'
              '4. Merchant wajib mengikuti kebijakan platform\n'
              '5. Platform berhak menonaktifkan akun merchant yang melanggar ketentuan',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),
            const Text(
              'Keuntungan Menjadi Merchant:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '• Akses ke jutaan pembeli potensial\n'
              '• Tools manajemen toko yang lengkap\n'
              '• Dukungan promosi dari platform\n'
              '• Sistem pembayaran yang aman',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () async {
                  try {
                    final userId = supabase.auth.currentUser?.id;
                    if (userId == null) {
                      Get.snackbar('Error', 'User ID tidak ditemukan');
                      return;
                    }

                    // Cek role user saat ini
                    final userData = await supabase
                        .from('users')
                        .select('role')
                        .eq('id', userId)
                        .single();

                    if (userData['role'] == 'buyer') {
                      // Update role ke seller (sesuai constraint di database)
                      await supabase
                          .from('users')
                          .update({'role': 'seller'}).eq('id', userId);

                      // Tunggu sebentar untuk memastikan update role selesai
                      await Future.delayed(const Duration(milliseconds: 500));
                    }

                    // Cek apakah user sudah terdaftar sebagai merchant
                    final merchant = await supabase
                        .from('merchants')
                        .select()
                        .eq('id', userId)
                        .maybeSingle();

                    if (merchant == null) {
                      // Tambahkan data kosong ke tabel merchants terlebih dahulu
                      await supabase.from('merchants').insert({
                        'id': userId,
                        'store_name':
                            '', // Akan diisi nanti di RegisterMerchantScreen
                        'store_description': '',
                        'store_address': '',
                        'store_phone': '',
                      });

                      Get.to(() => RegisterMerchantScreen(sellerId: userId));
                    } else {
                      Get.offAll(() => MerchantHomeScreen(sellerId: userId));
                    }
                  } catch (e) {
                    Get.snackbar(
                      'Error',
                      'Gagal memproses pendaftaran: $e',
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    print('Error detail: $e');
                  }
                },
                child: const Text(
                  'Lanjutkan Pendaftaran',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
