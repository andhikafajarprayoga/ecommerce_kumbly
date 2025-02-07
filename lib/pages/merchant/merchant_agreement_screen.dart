import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_merchant_screen.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';
import '../../theme/app_theme.dart';

class MerchantAgreementScreen extends StatefulWidget {
  MerchantAgreementScreen({super.key});

  @override
  State<MerchantAgreementScreen> createState() =>
      _MerchantAgreementScreenState();
}

class _MerchantAgreementScreenState extends State<MerchantAgreementScreen> {
  final supabase = Supabase.instance.client;
  bool isAgreed = false;

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    size: 40,
                    color: AppTheme.primary,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Konfirmasi Pendaftaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Apakah Anda yakin ingin mendaftar sebagai merchant? Pastikan Anda telah membaca dan menyetujui semua syarat dan ketentuan yang berlaku.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: AppTheme.primary),
                          ),
                        ),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _processMerchantRegistration();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Ya, Lanjutkan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _processMerchantRegistration() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        Get.snackbar('Error', 'User ID tidak ditemukan');
        return;
      }

      // Cek role user saat ini
      final userData =
          await supabase.from('users').select('role').eq('id', userId).single();

      if (userData['role'] == 'buyer') {
        // Update role ke seller
        await supabase
            .from('users')
            .update({'role': 'seller'}).eq('id', userId);

        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Cek apakah user sudah terdaftar sebagai merchant
      final merchant = await supabase
          .from('merchants')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (merchant == null) {
        await supabase.from('merchants').insert({
          'id': userId,
          'store_name': '',
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendaftaran Merchant'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Syarat dan Ketentuan Merchant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTermItem(
                      '1',
                      'Merchant wajib menyediakan informasi yang akurat tentang produk',
                    ),
                    _buildTermItem(
                      '2',
                      'Merchant bertanggung jawab atas kualitas produk',
                    ),
                    _buildTermItem(
                      '3',
                      'Merchant wajib merespon pesanan dalam 1x24 jam',
                    ),
                    _buildTermItem(
                      '4',
                      'Merchant wajib mengikuti kebijakan platform',
                    ),
                    _buildTermItem(
                      '5',
                      'Platform berhak menonaktifkan akun merchant yang melanggar ketentuan',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keuntungan Menjadi Merchant',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildBenefitItem(
                      Icons.people_outline,
                      'Akses ke jutaan pembeli potensial',
                    ),
                    _buildBenefitItem(
                      Icons.store_outlined,
                      'Tools manajemen toko yang lengkap',
                    ),
                    _buildBenefitItem(
                      Icons.campaign_outlined,
                      'Dukungan promosi dari platform',
                    ),
                    _buildBenefitItem(
                      Icons.security_outlined,
                      'Sistem pembayaran yang aman',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Checkbox(
                  value: isAgreed,
                  onChanged: (value) {
                    setState(() {
                      isAgreed = value ?? false;
                    });
                  },
                  activeColor: AppTheme.primary,
                ),
                Expanded(
                  child: Text(
                    'Saya menyetujui semua syarat dan ketentuan yang berlaku',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                onPressed: isAgreed ? _showConfirmationDialog : null,
                child: const Text(
                  'Lanjutkan Pendaftaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppTheme.primary,
              size: 24,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
