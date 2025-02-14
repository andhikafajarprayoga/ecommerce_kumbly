import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class AdminFeesScreen extends StatefulWidget {
  @override
  _AdminFeesScreenState createState() => _AdminFeesScreenState();
}

class _AdminFeesScreenState extends State<AdminFeesScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _feeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kelola Fee Admin Hotel',
            style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddEditDialog(),
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabase
            .from('admin_fees')
            .stream(primaryKey: ['id']).order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final fees = snapshot.data!;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: fees.length,
            itemBuilder: (context, index) {
              final fee = fees[index];
              return Card(
                child: ListTile(
                  title: Text(fee['name']),
                  subtitle: Text('Rp: ${fee['fee']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: fee['is_active'] ?? false,
                        onChanged: (value) => _updateStatus(fee['id'], value),
                      ),
                      IconButton(
                        icon: Icon(Icons.edit),
                        onPressed: () => _showAddEditDialog(fee: fee),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteFee(fee['id']),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? fee}) async {
    if (fee != null) {
      _nameController.text = fee['name'];
      _feeController.text = fee['fee'].toString();
    } else {
      _nameController.clear();
      _feeController.clear();
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fee == null ? 'Tambah Fee' : 'Edit Fee'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Nama'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Nama tidak boleh kosong' : null,
              ),
              TextFormField(
                controller: _feeController,
                decoration: InputDecoration(labelText: 'Fee (Rp)'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Fee tidak boleh kosong';
                  if (double.tryParse(value!) == null) {
                    return 'Fee harus berupa angka';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                if (fee == null) {
                  await _addFee();
                } else {
                  await _updateFee(fee['id']);
                }
                Get.back();
              }
            },
            child: Text(fee == null ? 'Tambah' : 'Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _addFee() async {
    try {
      await supabase.from('admin_fees').insert({
        'name': _nameController.text,
        'fee': double.parse(_feeController.text),
      });
      Get.snackbar('Sukses', 'Fee berhasil ditambahkan');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menambahkan fee: $e');
    }
  }

  Future<void> _updateFee(int id) async {
    try {
      await supabase.from('admin_fees').update({
        'name': _nameController.text,
        'fee': double.parse(_feeController.text),
      }).eq('id', id);
      Get.snackbar('Sukses', 'Fee berhasil diperbarui');
    } catch (e) {
      Get.snackbar('Error', 'Gagal memperbarui fee: $e');
    }
  }

  Future<void> _updateStatus(int id, bool status) async {
    try {
      await supabase
          .from('admin_fees')
          .update({'is_active': status}).eq('id', id);
      Get.snackbar('Sukses', 'Status berhasil diperbarui');
    } catch (e) {
      Get.snackbar('Error', 'Gagal memperbarui status: $e');
    }
  }

  Future<void> _deleteFee(int id) async {
    try {
      await supabase.from('admin_fees').delete().eq('id', id);
      Get.snackbar('Sukses', 'Fee berhasil dihapus');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menghapus fee: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    super.dispose();
  }
}
