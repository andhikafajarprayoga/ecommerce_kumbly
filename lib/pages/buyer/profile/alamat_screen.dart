import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/address_controller.dart'; // Pastikan Anda memiliki controller untuk alamat

class AlamatScreen extends StatelessWidget {
  AlamatScreen({super.key});

  final AddressController addressController =
      Get.put(AddressController()); // Inisialisasi AddressController

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alamat Saya'),
      ),
      body: Obx(() {
        if (addressController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (addressController.addresses.isEmpty) {
          return const Center(child: Text('Tidak ada alamat tersedia'));
        }

        return ListView.builder(
          itemCount: addressController.addresses.length,
          itemBuilder: (context, index) {
            final address = addressController.addresses[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(address['address'],
                        style:
                            const TextStyle(fontSize: 16)), // Tampilkan alamat
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Logika untuk mengedit alamat
                      },
                      child: const Text('Edit'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
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
