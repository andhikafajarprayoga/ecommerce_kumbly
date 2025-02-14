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
            ], [
              'Untuk membatalkan pesanan:\n1. Buka halaman detail pesanan\n2. Tekan tombol "Batalkan Pesanan"\n3. Pilih alasan pembatalan\n4. Konfirmasi pembatalan',
              'Untuk melacak pesanan:\n1. Buka menu "Pesanan Saya"\n2. Pilih pesanan yang ingin dilacak\n3. Lihat status pengiriman dan lokasi terkini',
              'Waktu pengiriman tergantung pada:\n- Lokasi tujuan (1-3 hari dalam kota)\n- Metode pengiriman yang dipilih\n- Jam operasional (Senin-Sabtu)',
            ]),
            _buildFAQSection('Akun', [
              'Bagaimana cara mengubah password?',
              'Cara menambahkan alamat pengiriman',
              'Cara mengubah email',
            ], [
              'Untuk mengubah password:\n1. Buka menu "Profil"\n2. Pilih "Pengaturan Akun"\n3. Pilih "Ubah Password"\n4. Masukkan password lama\n5. Masukkan password baru\n6. Konfirmasi password baru\n7. Tekan tombol "Simpan"',
              'Untuk menambah alamat pengiriman:\n1. Buka menu "Profil"\n2. Pilih "Alamat Saya"\n3. Tekan tombol "+" atau "Tambah Alamat"\n4. Isi detail alamat (nama, nomor telepon, alamat lengkap)\n5. Pilih lokasi di peta\n6. Tekan tombol "Simpan Alamat"',
              'Untuk mengubah email:\n1. Buka menu "Profil"\n2. Pilih "Pengaturan Akun"\n3. Pilih "Ubah Email"\n4. Masukkan email baru\n5. Verifikasi email baru melalui link yang dikirim\n6. Masukkan password untuk konfirmasi\n7. Tekan tombol "Simpan"',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQSection(String title, List<String> questions,
      [List<String>? answers]) {
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
        children: questions.asMap().entries.map((entry) {
          final int idx = entry.key;
          final String question = entry.value;
          return ExpansionTile(
            title: Text(question),
            children: [
              if (answers != null && idx < answers.length)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    answers[idx],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
