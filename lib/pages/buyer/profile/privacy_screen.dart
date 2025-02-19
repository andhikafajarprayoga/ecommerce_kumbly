import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Privasi',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
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
            _buildPrivacySection(
              'Kebijakan Privasi',
              'Kami menghargai privasi Anda dan berkomitmen untuk melindungi informasi pribadi Anda.',
            ),
            const SizedBox(height: 20),
            _buildPrivacySection(
              'Data yang Kami Kumpulkan',
              'Informasi yang kami kumpulkan meliputi nama, email, alamat, dan riwayat pembelian.',
            ),
            const SizedBox(height: 20),
            _buildPrivacySection(
              'Penggunaan Data',
              'Data Anda digunakan untuk memproses pesanan, memberikan layanan pelanggan, dan meningkatkan pengalaman pengguna.',
            ),
            const SizedBox(height: 20),
            _buildPrivacySection(
              'Keamanan Data',
              'Kami menggunakan enkripsi dan tindakan keamanan lainnya untuk melindungi data Anda.',
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                children: [
                  Text(
                    'Untuk informasi lebih lengkap, silakan kunjungi:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => launch(
                        'https://sarajaprivacypolicy.blogspot.com/p/kebijakan-privasi-terakhir-diperbarui.html'),
                    child: Text(
                      'Kebijakan Privasi Saraja',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.primary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivacySection(String title, String content) {
    return Container(
      padding: const EdgeInsets.all(16),
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
