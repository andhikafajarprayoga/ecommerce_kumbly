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
  final _withdrawalFeeController = TextEditingController();
  bool _isWithdrawalActive = true;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Kelola Fee', style: TextStyle(color: Colors.white)),
          backgroundColor: AppTheme.primary,
          elevation: 0,
          foregroundColor: Colors.white,
          bottom: TabBar(
            labelColor: Colors.white,
            tabs: [
              Tab(text: 'Fee Admin Hotel'),
              Tab(text: 'Fee Penarikan'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAdminFeesTab(),
            _buildWithdrawalConfigTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminFeesTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWithdrawalConfigTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('withdrawal_configs')
          .stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Terjadi kesalahan: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final configs = snapshot.data!;

        return ListView.builder(
          padding: EdgeInsets.all(16),
          itemCount: configs.length,
          itemBuilder: (context, index) {
            final config = configs[index];
            return Card(
              child: ListTile(
                title: Text('Fee Tetap: Rp ${config['fee_fixed']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: config['is_active'] ?? false,
                      onChanged: (value) =>
                          _updateWithdrawalStatus(config['id'], value),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () =>
                          _showWithdrawalConfigDialog(config: config),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
      barrierDismissible: false, // Prevent dismissing by tapping outside
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  if (fee == null) {
                    await _addFee();
                  } else {
                    await _updateFee(fee['id']);
                  }
                  Navigator.of(context)
                      .pop(); // Close dialog after successful operation
                  setState(() {}); // Tambahkan ini untuk refresh tampilan
                  Get.snackbar(
                    'Sukses',
                    fee == null
                        ? 'Fee berhasil ditambahkan'
                        : 'Fee berhasil diperbarui',
                    backgroundColor: const Color.fromARGB(255, 133, 240, 119),
                    duration: Duration(seconds: 2),
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    fee == null
                        ? 'Gagal menambahkan fee: $e'
                        : 'Gagal memperbarui fee: $e',
                    backgroundColor: Colors.red[100],
                    duration: Duration(seconds: 2),
                  );
                }
              }
            },
            child: Text(fee == null ? 'Tambah' : 'Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _addFee() async {
    await supabase.from('admin_fees').insert({
      'name': _nameController.text,
      'fee': double.parse(_feeController.text),
    });
  }

  Future<void> _updateFee(int id) async {
    await supabase.from('admin_fees').update({
      'name': _nameController.text,
      'fee': double.parse(_feeController.text),
    }).eq('id', id);
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

  Future<void> _showWithdrawalConfigDialog(
      {Map<String, dynamic>? config}) async {
    if (config != null) {
      _withdrawalFeeController.text = config['fee_fixed'].toString();
      _isWithdrawalActive = config['is_active'];
    } else {
      _withdrawalFeeController.clear();
      _isWithdrawalActive = true;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(config == null ? 'Tambah Konfigurasi' : 'Edit Konfigurasi'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _withdrawalFeeController,
                decoration: InputDecoration(labelText: 'Fee Tetap (Rp)'),
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
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                try {
                  if (config == null) {
                    await _addWithdrawalConfig();
                  } else {
                    await _updateWithdrawalConfig(config['id']);
                  }
                  Navigator.of(context).pop();
                  Get.snackbar(
                    'Sukses',
                    config == null
                        ? 'Konfigurasi berhasil ditambahkan'
                        : 'Konfigurasi berhasil diperbarui',
                    backgroundColor: const Color.fromARGB(255, 103, 181, 92),
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error',
                    'Gagal ${config == null ? 'menambahkan' : 'memperbarui'} konfigurasi: $e',
                    backgroundColor: Colors.red[100],
                  );
                }
              }
            },
            child: Text(config == null ? 'Tambah' : 'Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _addWithdrawalConfig() async {
    await supabase.from('withdrawal_configs').insert({
      'fee_fixed': double.parse(_withdrawalFeeController.text),
      'is_active': _isWithdrawalActive,
    });
  }

  Future<void> _updateWithdrawalConfig(String id) async {
    await supabase.from('withdrawal_configs').update({
      'fee_fixed': double.parse(_withdrawalFeeController.text),
      'is_active': _isWithdrawalActive,
    }).eq('id', id);
  }

  Future<void> _updateWithdrawalStatus(String id, bool status) async {
    try {
      await supabase
          .from('withdrawal_configs')
          .update({'is_active': status}).eq('id', id);
      Get.snackbar('Sukses', 'Status berhasil diperbarui');
    } catch (e) {
      Get.snackbar('Error', 'Gagal memperbarui status: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    _withdrawalFeeController.dispose();
    super.dispose();
  }
}
