import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class PengirimanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? pengiriman;

  PengirimanFormScreen({this.pengiriman});

  @override
  _PengirimanFormScreenState createState() => _PengirimanFormScreenState();
}

class _PengirimanFormScreenState extends State<PengirimanFormScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _hargaKgController = TextEditingController();
  final _hargaKmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.pengiriman != null) {
      _namaController.text = widget.pengiriman!['nama_pengiriman'];
      _hargaKgController.text = widget.pengiriman!['harga_per_kg'].toString();
      _hargaKmController.text = widget.pengiriman!['harga_per_km'].toString();
    }
  }

  Future<void> savePengiriman() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Tampilkan loading indicator
      Get.dialog(
        Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final data = {
        'nama_pengiriman': _namaController.text.trim(),
        'harga_per_kg':
            double.parse(_hargaKgController.text.replaceAll(',', '')),
        'harga_per_km':
            double.parse(_hargaKmController.text.replaceAll(',', '')),
      };

      if (widget.pengiriman != null) {
        await supabase
            .from('pengiriman')
            .update(data)
            .eq('id_pengiriman', widget.pengiriman!['id_pengiriman']);
      } else {
        await supabase.from('pengiriman').insert(data);
      }

      // Tutup loading indicator
      Get.back();

      Get.back(
          result: true); // Kembali ke halaman sebelumnya dengan hasil sukses

      Get.snackbar(
        'Sukses',
        widget.pengiriman != null
            ? 'Pengiriman berhasil diperbarui'
            : 'Pengiriman berhasil ditambahkan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: Duration(seconds: 2),
      );
    } catch (e) {
      // Tutup loading indicator jika terjadi error
      Get.back();

      Get.snackbar(
        'Error',
        'Gagal menyimpan pengiriman: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pengiriman != null
            ? 'Edit Pengiriman'
            : 'Tambah Pengiriman'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _namaController,
              decoration: InputDecoration(
                labelText: 'Nama Pengiriman',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Nama pengiriman harus diisi';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _hargaKgController,
              decoration: InputDecoration(
                labelText: 'Harga per KG',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Harga per KG harus diisi';
                }
                if (double.tryParse(value) == null) {
                  return 'Harga harus berupa angka';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _hargaKmController,
              decoration: InputDecoration(
                labelText: 'Harga per KM',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Harga per KM harus diisi';
                }
                if (double.tryParse(value) == null) {
                  return 'Harga harus berupa angka';
                }
                return null;
              },
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: savePengiriman,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                widget.pengiriman != null ? 'Update' : 'Simpan',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _hargaKgController.dispose();
    _hargaKmController.dispose();
    super.dispose();
  }
}
