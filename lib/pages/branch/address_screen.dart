import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import '../../theme/app_theme.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  final supabase = Supabase.instance.client;
  final AuthController authController = Get.find<AuthController>();
  final streetController = TextEditingController();
  final villageController = TextEditingController();
  final districtController = TextEditingController();
  final cityController = TextEditingController();
  final provinceController = TextEditingController();
  final postalCodeController = TextEditingController();
  Map<String, dynamic> address = {};

  @override
  void initState() {
    super.initState();
    _loadAddress();
  }

  Future<void> _loadAddress() async {
    try {
      final user = await supabase
          .from('users')
          .select()
          .eq('id', authController.currentUser.value!.id)
          .single();

      setState(() {
        if (user['address'] != null) {
          address = user['address'];
          streetController.text = address['street'] ?? '';
          villageController.text = address['village'] ?? '';
          districtController.text = address['district'] ?? '';
          cityController.text = address['city'] ?? '';
          provinceController.text = address['province'] ?? '';
          postalCodeController.text = address['postal_code'] ?? '';
        }
      });
    } catch (e) {
      print('Error loading address: $e');
    }
  }

  Future<void> _updateAddress() async {
    try {
      final newAddress = {
        'street': streetController.text,
        'village': villageController.text,
        'district': districtController.text,
        'city': cityController.text,
        'province': provinceController.text,
        'postal_code': postalCodeController.text,
      };

      await supabase.from('users').update({
        'address': newAddress,
      }).eq('id', authController.currentUser.value!.id);

      setState(() {
        address = newAddress;
      });

      Get.snackbar(
        'Sukses',
        'Alamat berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Alamat'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alamat Cabang',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: streetController,
                  decoration: const InputDecoration(
                    labelText: 'Jalan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: villageController,
                  decoration: const InputDecoration(
                    labelText: 'Desa/Kelurahan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: districtController,
                  decoration: const InputDecoration(
                    labelText: 'Kecamatan',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'Kota/Kabupaten',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: provinceController,
                  decoration: const InputDecoration(
                    labelText: 'Provinsi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: postalCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Kode Pos',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        streetController.clear();
                        villageController.clear();
                        districtController.clear();
                        cityController.clear();
                        provinceController.clear();
                        postalCodeController.clear();
                        _updateAddress();
                      },
                      child: const Text('Hapus'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _updateAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('Simpan',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    streetController.dispose();
    villageController.dispose();
    districtController.dispose();
    cityController.dispose();
    provinceController.dispose();
    postalCodeController.dispose();
    super.dispose();
  }
}
