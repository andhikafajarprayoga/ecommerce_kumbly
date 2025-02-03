import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Bantuan',
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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.primary.withOpacity(0.1),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari bantuan...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            _buildFAQSection('Pesanan', [
              'Bagaimana cara membatalkan pesanan?',
              'Bagaimana cara melacak pesanan?',
              'Berapa lama waktu pengiriman?',
            ]),
            _buildFAQSection('Pembayaran', [
              'Metode pembayaran apa saja yang tersedia?',
              'Bagaimana cara memproses refund?',
              'Berapa lama proses refund?',
            ]),
            _buildFAQSection('Akun', [
              'Bagaimana cara mengubah password?',
              'Cara menambahkan alamat pengiriman',
              'Cara mengubah email',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection(String title, List<String> questions) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
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
      child: ExpansionTile(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        children: questions.map((question) {
          return ListTile(
            title: Text(question),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Implementasi navigasi ke detail bantuan
            },
          );
        }).toList(),
      ),
    );
  }
}
