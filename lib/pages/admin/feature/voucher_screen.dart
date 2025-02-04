import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class VoucherScreen extends StatefulWidget {
  @override
  _VoucherScreenState createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _rateController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _addVoucher() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await supabase.from('shipping_vouchers').insert({
        'code': _codeController.text.toUpperCase(),
        'rate': double.parse(_rateController.text),
      });

      Get.snackbar(
        'Sukses',
        'Voucher berhasil ditambahkan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _codeController.clear();
      _rateController.clear();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menambahkan voucher',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _deleteVoucher(String id) async {
    try {
      await supabase.from('shipping_vouchers').delete().eq('id', id);
      Get.snackbar(
        'Sukses',
        'Voucher berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menghapus voucher',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _editVoucher(Map<String, dynamic> voucher) async {
    final _editFormKey = GlobalKey<FormState>();

    _codeController.text = voucher['code'] ?? '';
    _rateController.text = voucher['rate']?.toString() ?? '';

    try {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit Voucher'),
          content: Form(
            key: _editFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: 'Kode Voucher',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Kode tidak boleh kosong' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _rateController,
                  decoration: InputDecoration(
                    labelText: 'Nilai Diskon',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Nilai tidak boleh kosong';
                    }
                    final rate = double.tryParse(value!);
                    if (rate == null) {
                      return 'Masukkan angka yang valid';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal'),
            ),
            TextButton(
              onPressed: () async {
                if (!_editFormKey.currentState!.validate()) return;

                try {
                  await supabase.from('shipping_vouchers').update({
                    'code': _codeController.text.toUpperCase(),
                    'rate': double.parse(_rateController.text),
                  }).eq('id', voucher['id']);

                  Navigator.pop(context);

                  Get.snackbar(
                    'Sukses',
                    'Voucher berhasil diupdate',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                } catch (e) {
                  print('Error updating voucher: $e');
                  Get.snackbar(
                    'Error',
                    'Gagal mengupdate voucher: ${e.toString()}',
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              },
              child: Text('Simpan'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing dialog: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Voucher'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Kode Voucher',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Kode tidak boleh kosong'
                        : null,
                  ),
                  SizedBox(height: 16),
                  TextFormField(
                    controller: _rateController,
                    decoration: InputDecoration(
                      labelText: 'Nilai Diskon',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) => value?.isEmpty ?? true
                        ? 'Nilai tidak boleh kosong'
                        : null,
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addVoucher,
                    child: Text('Tambah Voucher'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: Size(double.infinity, 45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase.from('shipping_vouchers').stream(
                  primaryKey: ['id']).order('created_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final vouchers = snapshot.data!;

                return ListView.builder(
                  itemCount: vouchers.length,
                  itemBuilder: (context, index) {
                    final voucher = vouchers[index];
                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        title: Text(voucher['code']),
                        subtitle: Text('Diskon: Rp. ${voucher['rate']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.copy),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(
                                  text: voucher['code'],
                                ));
                                Get.snackbar(
                                  'Sukses',
                                  'Kode voucher berhasil disalin',
                                  backgroundColor: Colors.green,
                                  colorText: Colors.white,
                                  duration: Duration(seconds: 1),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.edit),
                              onPressed: () => _editVoucher(voucher),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => _deleteVoucher(voucher['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
