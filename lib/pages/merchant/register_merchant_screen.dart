import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kumbly_ecommerce/pages/merchant/home_screen.dart';
import '../../theme/app_theme.dart';

class RegisterMerchantScreen extends StatefulWidget {
  final String sellerId;

  const RegisterMerchantScreen({super.key, required this.sellerId});

  @override
  _RegisterMerchantScreenState createState() => _RegisterMerchantScreenState();
}

class _RegisterMerchantScreenState extends State<RegisterMerchantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeDescController = TextEditingController();
  final _storePhoneController = TextEditingController();

  // Tambahan controller untuk alamat terpisah
  final _streetController = TextEditingController();
  final _villageController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();

  final supabase = Supabase.instance.client;

  Future<void> _registerMerchant() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Cek dulu apakah merchant sudah ada
        final existingMerchant = await supabase
            .from('merchants')
            .select()
            .eq('id', widget.sellerId)
            .maybeSingle();

        if (existingMerchant != null) {
          // Jika sudah ada, lakukan update
          await supabase.from('merchants').update({
            'store_name': _storeNameController.text,
            'store_description': _storeDescController.text,
            'store_address': {
              "street": _streetController.text,
              "village": _villageController.text,
              "district": _districtController.text,
              "city": _cityController.text,
              "province": _provinceController.text,
              "postal_code": _postalCodeController.text
            },
            'store_phone': _storePhoneController.text,
          }).eq('id', widget.sellerId);
        } else {
          // Jika belum ada, lakukan insert
          await supabase.from('merchants').insert({
            'id': widget.sellerId,
            'store_name': _storeNameController.text,
            'store_description': _storeDescController.text,
            'store_address': {
              "street": _streetController.text,
              "village": _villageController.text,
              "district": _districtController.text,
              "city": _cityController.text,
              "province": _provinceController.text,
              "postal_code": _postalCodeController.text
            },
            'store_phone': _storePhoneController.text,
          });
        }

        // Update role user menjadi seller
        await supabase
            .from('users')
            .update({'role': 'seller'}).eq('id', widget.sellerId);

        Get.snackbar(
          'Sukses',
          'Selamat! Pendaftaran merchant berhasil.',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );

        Get.offAll(() => MerchantHomeScreen(sellerId: widget.sellerId));
      } catch (e) {
        Get.snackbar(
          'Error',
          'Gagal mendaftar merchant: $e',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
          snackPosition: SnackPosition.TOP,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informasi Toko'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informasi Dasar Toko
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informasi Dasar',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _storeNameController,
                        label: 'Nama Toko',
                        hint: 'Masukkan nama toko Anda',
                        icon: Icons.store,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Nama toko wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _storeDescController,
                        label: 'Deskripsi Toko',
                        hint: 'Ceritakan tentang toko Anda',
                        icon: Icons.description,
                        maxLines: 3,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Deskripsi toko wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _storePhoneController,
                        label: 'Nomor Telepon',
                        hint: 'Masukkan nomor telepon aktif',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Nomor telepon wajib diisi'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Alamat Toko
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alamat Toko',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _streetController,
                        label: 'Nama Jalan',
                        hint: 'Contoh: Jln Sigra No. 123',
                        icon: Icons.location_on,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Nama jalan wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _villageController,
                        label: 'Desa/Kelurahan',
                        hint: 'Contoh: Cisetu',
                        icon: Icons.location_city,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Desa/Kelurahan wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _districtController,
                        label: 'Kecamatan',
                        hint: 'Contoh: Rajagaluh',
                        icon: Icons.location_on,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Kecamatan wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _cityController,
                        label: 'Kota/Kabupaten',
                        hint: 'Contoh: Majalengka',
                        icon: Icons.location_city,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Kota/Kabupaten wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _provinceController,
                        label: 'Provinsi',
                        hint: 'Contoh: Jawa Barat',
                        icon: Icons.map,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Provinsi wajib diisi'
                            : null,
                      ),
                      SizedBox(height: 16),
                      _buildTextField(
                        controller: _postalCodeController,
                        label: 'Kode Pos',
                        hint: 'Contoh: 45471',
                        icon: Icons.local_post_office,
                        keyboardType: TextInputType.number,
                        validator: (value) => value?.isEmpty ?? true
                            ? 'Kode pos wajib diisi'
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Tombol Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _registerMerchant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Daftar Merchant',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: AppTheme.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppTheme.primary),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 14),
        ),
      ],
    );
  }
}
