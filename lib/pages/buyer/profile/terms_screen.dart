import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Syarat dan Ketentuan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTermsSection(
              'Ketentuan Umum',
              'Dengan menggunakan aplikasi ini, Anda menyetujui semua syarat dan ketentuan yang berlaku.',
            ),
            _buildTermsSection(
              'Penggunaan Aplikasi',
              'Pengguna wajib memberikan informasi yang akurat dan bertanggung jawab atas aktivitas dalam akun mereka.',
            ),
            _buildTermsSection(
              'Transaksi',
              'Semua transaksi harus mengikuti prosedur yang telah ditetapkan. Pembeli dan penjual wajib mematuhi ketentuan transaksi.',
            ),
            _buildTermsSection(
              'Pembayaran',
              'Pembayaran dilakukan melalui metode yang telah disediakan. Pengembalian dana mengikuti kebijakan yang berlaku.',
            ),
            _buildTermsSection(
              'Pengiriman',
              'Pengiriman dilakukan sesuai dengan estimasi yang diberikan. Risiko pengiriman ditanggung sesuai ketentuan yang berlaku.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textHint,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
