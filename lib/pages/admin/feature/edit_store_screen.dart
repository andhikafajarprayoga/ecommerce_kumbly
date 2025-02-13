import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'dart:convert';

class EditStoreScreen extends StatefulWidget {
  final Map<String, dynamic> store;
  final Map<String, dynamic> user;

  EditStoreScreen({required this.store, required this.user});

  @override
  _EditStoreScreenState createState() => _EditStoreScreenState();
}

class _EditStoreScreenState extends State<EditStoreScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  late TextEditingController storeNameController;
  late TextEditingController storeDescriptionController;
  late TextEditingController storeAddressController;
  late TextEditingController storePhoneController;
  late TextEditingController ownerNameController;
  late TextEditingController ownerPhoneController;

  @override
  void initState() {
    super.initState();
    // Parse alamat dari JSON string jika dalam format JSON
    String formattedAddress = '';
    if (widget.store['store_address'] != null) {
      try {
        Map<String, dynamic> addressMap =
            widget.store['store_address'] is String
                ? Map<String, dynamic>.from(
                    jsonDecode(widget.store['store_address']))
                : widget.store['store_address'];

        formattedAddress = [
          addressMap['street'],
          addressMap['village'],
          addressMap['district'],
          addressMap['city'],
          addressMap['province'],
          addressMap['postal_code'],
        ].where((element) => element != null && element.isNotEmpty).join(', ');
      } catch (e) {
        formattedAddress = widget.store['store_address'].toString();
      }
    }

    storeNameController =
        TextEditingController(text: widget.store['store_name']);
    storeDescriptionController =
        TextEditingController(text: widget.store['store_description']);
    storeAddressController = TextEditingController(text: formattedAddress);
    storePhoneController =
        TextEditingController(text: widget.store['store_phone']);
    ownerNameController = TextEditingController(text: widget.user['full_name']);
    ownerPhoneController = TextEditingController(text: widget.user['phone']);
  }

  @override
  void dispose() {
    storeNameController.dispose();
    storeDescriptionController.dispose();
    storeAddressController.dispose();
    storePhoneController.dispose();
    ownerNameController.dispose();
    ownerPhoneController.dispose();
    super.dispose();
  }

  Future<void> updateStore() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      // Buat objek alamat
      Map<String, dynamic> addressMap = {
        "street": storeAddressController.text,
        "village": "",
        "district": "",
        "city": "",
        "province": "",
        "postal_code": "",
        "latitude": "",
        "longitude": ""
      };

      // Update merchant data
      await supabase.from('merchants').update({
        'store_name': storeNameController.text,
        'store_description': storeDescriptionController.text,
        'store_address': addressMap,
        'store_phone': storePhoneController.text,
      }).eq('id', widget.store['id']);

      // Update user data
      await supabase.from('users').update({
        'full_name': ownerNameController.text,
        'phone': ownerPhoneController.text,
      }).eq('id', widget.store['id']);

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Data toko berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error updating store: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui data toko',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Toko', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text(
              'Informasi Toko',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: storeNameController,
              decoration: InputDecoration(
                labelText: 'Nama Toko',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama toko tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: storeDescriptionController,
              decoration: InputDecoration(
                labelText: 'Deskripsi Toko',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: storeAddressController,
              decoration: InputDecoration(
                labelText: 'Alamat Toko',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Alamat toko tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: storePhoneController,
              decoration: InputDecoration(
                labelText: 'Nomor Telepon Toko',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 24),
            Text(
              'Informasi Pemilik',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: ownerNameController,
              decoration: InputDecoration(
                labelText: 'Nama Pemilik',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama pemilik tidak boleh kosong';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: ownerPhoneController,
              decoration: InputDecoration(
                labelText: 'Nomor Telepon Pemilik',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : updateStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: isLoading
                  ? CircularProgressIndicator(color: Colors.white)
                  : Text('Simpan Perubahan',
                      style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
