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

  // Tambah controller untuk nama dan telepon
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
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
    _loadBranchProfile();
  }

  Future<void> _loadBranchProfile() async {
    try {
      final branch = await supabase
          .from('branches')
          .select()
          .eq('user_id', authController.currentUser.value?.id ?? '')
          .single();

      setState(() {
        nameController.text = branch['name'] ?? '';
        phoneController.text = branch['phone'] ?? '';

        if (branch['address'] != null) {
          address = branch['address'];
          streetController.text = address['street'] ?? '';
          villageController.text = address['village'] ?? '';
          districtController.text = address['district'] ?? '';
          cityController.text = address['city'] ?? '';
          provinceController.text = address['province'] ?? '';
          postalCodeController.text = address['postal_code'] ?? '';
        }
      });
    } catch (e) {
      print('Error loading branch profile: $e');
    }
  }

  Future<void> _updateBranchProfile() async {
    try {
      final newAddress = {
        'street': streetController.text,
        'village': villageController.text,
        'district': districtController.text,
        'city': cityController.text,
        'province': provinceController.text,
        'postal_code': postalCodeController.text,
      };

      await supabase.from('branches').update({
        'name': nameController.text,
        'phone': phoneController.text,
        'address': newAddress,
      }).eq('user_id', authController.currentUser.value?.id ?? '');

      setState(() {
        address = newAddress;
      });

      Get.snackbar(
        'Sukses',
        'Profil cabang berhasil diperbarui',
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
        title: const Text('Profil Cabang'),
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
                  'Informasi Cabang',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Cabang',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Telepon',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updateBranchProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Simpan Perubahan',
                        style: TextStyle(color: Colors.white)),
                  ),
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
    nameController.dispose();
    phoneController.dispose();
    streetController.dispose();
    villageController.dispose();
    districtController.dispose();
    cityController.dispose();
    provinceController.dispose();
    postalCodeController.dispose();
    super.dispose();
  }
}
