import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:convert';

class EditStoreScreen extends StatefulWidget {
  @override
  _EditStoreScreenState createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _storeNameController = TextEditingController();
  final _storeDescriptionController = TextEditingController();
  final _storePhoneController = TextEditingController();

  // Tambahkan controller baru untuk alamat terstruktur
  final _streetController = TextEditingController();
  final _villageController = TextEditingController();
  final _districtController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeDescriptionController.dispose();
    _storePhoneController.dispose();
    _streetController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadStoreData() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final storeData =
          await supabase.from('merchants').select().eq('id', userId).single();

      // Parse alamat dari JSON string
      Map<String, dynamic> addressData = {};
      try {
        if (storeData['store_address'] != null) {
          addressData =
              Map<String, dynamic>.from(jsonDecode(storeData['store_address']));
        }
      } catch (e) {
        print('Error parsing address: $e');
      }

      setState(() {
        _storeNameController.text = storeData['store_name'] ?? '';
        _storeDescriptionController.text = storeData['store_description'] ?? '';
        _storePhoneController.text = storeData['store_phone'] ?? '';

        // Set nilai untuk field alamat
        _streetController.text = addressData['street'] ?? '';
        _villageController.text = addressData['village'] ?? '';
        _districtController.text = addressData['district'] ?? '';
        _cityController.text = addressData['city'] ?? '';
        _provinceController.text = addressData['province'] ?? '';
        _postalCodeController.text = addressData['postal_code'] ?? '';

        _isLoading = false;
      });
    } catch (e) {
      print('Error loading store data: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data toko',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _updateStore() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      setState(() => _isLoading = true);

      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Buat objek alamat terstruktur
      final addressData = {
        'street': _streetController.text,
        'village': _villageController.text,
        'district': _districtController.text,
        'city': _cityController.text,
        'province': _provinceController.text,
        'postal_code': _postalCodeController.text,
      };

      await supabase.from('merchants').update({
        'store_name': _storeNameController.text,
        'store_description': _storeDescriptionController.text,
        'store_phone': _storePhoneController.text,
        'store_address': jsonEncode(addressData), // Simpan sebagai JSON string
      }).eq('id', userId);

      Get.snackbar(
        'Sukses',
        'Data toko berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.back();
    } catch (e) {
      print('Error updating store: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui data toko',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Toko', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      controller: _storeNameController,
                      label: 'Nama Toko',
                      hint: 'Masukkan nama toko',
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Nama toko tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _storeDescriptionController,
                      label: 'Deskripsi Toko',
                      hint: 'Masukkan deskripsi toko',
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                    // Field alamat terstruktur
                    Text(
                      'Alamat Toko',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildTextField(
                      controller: _streetController,
                      label: 'Alamat Lengkap',
                      hint: 'Contoh: Jl. Sudirman No. 123',
                      maxLines: 2,
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _villageController,
                      label: 'Kelurahan/Desa',
                      hint: 'Masukkan kelurahan/desa',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _districtController,
                      label: 'Kecamatan',
                      hint: 'Masukkan kecamatan',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _cityController,
                      label: 'Kota/Kabupaten',
                      hint: 'Masukkan kota/kabupaten',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _provinceController,
                      label: 'Provinsi',
                      hint: 'Masukkan provinsi',
                    ),
                    SizedBox(height: 12),
                    _buildTextField(
                      controller: _postalCodeController,
                      label: 'Kode Pos',
                      hint: 'Masukkan kode pos',
                      keyboardType: TextInputType.number,
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      controller: _storePhoneController,
                      label: 'Nomor Telepon',
                      hint: 'Masukkan nomor telepon',
                      keyboardType: TextInputType.phone,
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _updateStore,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                        style: TextStyle(fontSize: 16),
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
    String? Function(String?)? validator,
    int? maxLines,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: validator,
          maxLines: maxLines ?? 1,
          keyboardType: keyboardType,
        ),
      ],
    );
  }
}
