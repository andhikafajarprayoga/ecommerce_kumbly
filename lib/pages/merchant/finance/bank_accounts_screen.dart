import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class BankAccountsScreen extends StatefulWidget {
  @override
  _BankAccountsScreenState createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends State<BankAccountsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> bankAccounts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBankAccounts();
  }

  Future<void> _fetchBankAccounts() async {
    try {
      final response = await supabase
          .from('merchant_bank_accounts')
          .select()
          .eq('is_active', true)
          .order('created_at');

      setState(() {
        bankAccounts = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching bank accounts: $e');
      isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rekening Bank'),
        backgroundColor: AppTheme.primary,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: bankAccounts.length,
              itemBuilder: (context, index) {
                final account = bankAccounts[index];
                return Card(
                  child: ListTile(
                    title: Text(account['bank_name']),
                    subtitle: Text(
                      '${account['account_number']}\n${account['account_holder']}',
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteAccount(account['id']),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(),
        child: Icon(Icons.add),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  void _showAddAccountDialog() {
    final _formKey = GlobalKey<FormState>();
    String bankName = '';
    String accountNumber = '';
    String accountHolder = '';

    Get.dialog(
      AlertDialog(
        title: Text('Tambah Rekening'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: InputDecoration(labelText: 'Nama Bank'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Wajib diisi' : null,
                onSaved: (value) => bankName = value ?? '',
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Nomor Rekening'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Wajib diisi' : null,
                onSaved: (value) => accountNumber = value ?? '',
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Nama Pemilik'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Wajib diisi' : null,
                onSaved: (value) => accountHolder = value ?? '',
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
              if (_formKey.currentState?.validate() ?? false) {
                _formKey.currentState?.save();
                await _addBankAccount(
                  bankName,
                  accountNumber,
                  accountHolder,
                );
                Get.back();
              }
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBankAccount(
    String bankName,
    String accountNumber,
    String accountHolder,
  ) async {
    try {
      await supabase.from('merchant_bank_accounts').insert({
        'bank_name': bankName,
        'account_number': accountNumber,
        'account_holder': accountHolder,
        'merchant_id': supabase.auth.currentUser!.id,
      });

      _fetchBankAccounts();
      Get.snackbar('Sukses', 'Rekening berhasil ditambahkan');
    } catch (e) {
      print('Error adding bank account: $e');
      Get.snackbar('Error', 'Gagal menambahkan rekening');
    }
  }

  Future<void> _deleteAccount(String id) async {
    try {
      await supabase
          .from('merchant_bank_accounts')
          .update({'is_active': false}).eq('id', id);

      _fetchBankAccounts();
      Get.snackbar('Sukses', 'Rekening berhasil dihapus');
    } catch (e) {
      print('Error deleting bank account: $e');
      Get.snackbar('Error', 'Gagal menghapus rekening');
    }
  }
}
