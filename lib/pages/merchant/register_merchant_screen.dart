import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';

class RegisterMerchantScreen extends StatefulWidget {
  @override
  _RegisterMerchantScreenState createState() => _RegisterMerchantScreenState();
}

class _RegisterMerchantScreenState extends State<RegisterMerchantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeDescController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final supabase = Supabase.instance.client;

  Future<void> _registerMerchant() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Update role user menjadi buyer_seller terlebih dahulu
        await supabase
            .from('users')
            .update({'role': 'seller'}).eq('id', supabase.auth.currentUser!.id);

        // Kemudian daftar merchant
        await supabase.from('merchants').insert({
          'id': supabase.auth.currentUser!.id,
          'store_name': _storeNameController.text,
          'store_description': _storeDescController.text,
          'store_address': _storeAddressController.text,
          'store_phone': _storePhoneController.text,
        });

        Get.snackbar('Sukses', 'Pendaftaran merchant berhasil!');
        Get.offAll(() => MerchantHomeScreen());
      } catch (e) {
        Get.snackbar('Error', 'Gagal mendaftar merchant: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Merchant'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Toko',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama toko wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storeDescController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Toko',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storeAddressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Toko',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Alamat toko wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _storePhoneController,
                decoration: const InputDecoration(
                  labelText: 'Nomor Telepon Toko',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nomor telepon wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _registerMerchant,
                  child: const Text('Daftar Merchant'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
