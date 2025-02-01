import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AlamatScreen extends StatelessWidget {
  AlamatScreen({super.key});

  final List<String> addresses = [
    'Alamat 1: Jl. Contoh No. 1, Jakarta',
    'Alamat 2: Jl. Contoh No. 2, Jakarta',
    'Alamat 3: Jl. Contoh No. 3, Jakarta',
  ]; // Contoh daftar alamat

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alamat Saya'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller:
                                TextEditingController(text: addresses[index]),
                            enabled: false, // Tidak dapat diubah
                            style: const TextStyle(
                                color: Colors
                                    .black), // Mengatur warna teks menjadi hitam
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Alamat ${index + 1}',
                              labelStyle: const TextStyle(
                                  color: Colors
                                      .black), // Mengatur warna label menjadi hitam
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Logika untuk mengubah alamat
                              // Misalnya, navigasi ke halaman edit alamat
                              Get.to(() =>
                                  EditAddressScreen(address: addresses[index]));
                            },
                            child: const Text('Update'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Logika untuk menambah alamat baru
              },
              child: const Text('Tambah Alamat'),
            ),
          ],
        ),
      ),
    );
  }
}

// Contoh halaman untuk mengedit alamat
class EditAddressScreen extends StatelessWidget {
  final String address;

  EditAddressScreen({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    final TextEditingController addressController =
        TextEditingController(text: address);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Alamat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Alamat',
                labelStyle: TextStyle(
                    color: Colors.black), // Mengatur warna label menjadi hitam
              ),
              style: const TextStyle(
                  color: Colors.black), // Mengatur warna teks menjadi hitam
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Logika untuk menyimpan perubahan alamat
                Get.back(); // Kembali ke halaman sebelumnya
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
