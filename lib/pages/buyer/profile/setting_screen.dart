import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SettingScreen extends StatelessWidget {
  SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('Notifikasi'),
              trailing: Switch(
                value: true, // Ganti dengan status notifikasi
                onChanged: (value) {
                  // Logika untuk mengubah status notifikasi
                },
              ),
            ),
            ListTile(
              title: const Text('Ubah Kata Sandi'),
              onTap: () {
                // Logika untuk mengubah kata sandi
              },
            ),
            ListTile(
              title: const Text('Keluar'),
              onTap: () {
                // Logika untuk keluar dari akun
              },
            ),
          ],
        ),
      ),
    );
  }
}
