import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../merchant/finance/bank_accounts_screen.dart';

class WithdrawalScreen extends StatefulWidget {
  final double balance;

  const WithdrawalScreen({Key? key, required this.balance}) : super(key: key);

  @override
  _WithdrawalScreenState createState() => _WithdrawalScreenState();
}

class _WithdrawalScreenState extends State<WithdrawalScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  Map<String, dynamic>? selectedMerchant;
  List<Map<String, dynamic>> merchants = [];

  Map<String, dynamic>? selectedAccount;
  List<Map<String, dynamic>> bankAccounts = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMerchants();
  }

  Future<void> _fetchMerchants() async {
    try {
      final response = await supabase
          .from('merchants')
          .select('id, store_name')
          .order('store_name');

      setState(() {
        merchants = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching merchants: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchBankAccounts() async {
    if (selectedMerchant == null) return;

    setState(() => isLoading = true);

    try {
      final response = await supabase
          .from('merchant_bank_accounts')
          .select()
          .eq('merchant_id',
              selectedMerchant!['id'].toString()) // Filter merchant_id
          .eq('is_active', true)
          .order('created_at');
      print("Selected Merchant ID: ${selectedMerchant!['id']}");

      print("Data rekening bank dari Supabase: $response"); // Debugging

      setState(() {
        bankAccounts = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching bank accounts: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedMerchant == null || selectedAccount == null) {
      Get.snackbar(
        'Error',
        'Pilih merchant dan rekening tujuan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      final amount = double.parse(_amountController.text);
      await supabase.from('withdrawal_requests').insert({
        'merchant_id': selectedMerchant!['id'],
        'bank_account_id': selectedAccount!['id'],
        'amount': amount,
        'status': 'pending',
      });

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Permintaan pencairan berhasil diajukan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error submitting withdrawal: $e');
      Get.snackbar(
        'Error',
        'Gagal mengajukan pencairan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pencairan Dana'),
        backgroundColor: AppTheme.primary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo Tersedia',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        NumberFormat.currency(
                          locale: 'id',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(widget.balance),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Pilih Merchant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                hint: Text('Pilih Merchant'),
                value: selectedMerchant,
                items: merchants.map((merchant) {
                  return DropdownMenuItem(
                    value: merchant,
                    child: Text(merchant['store_name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedMerchant = value;
                    selectedAccount =
                        null; // Reset rekening jika merchant berubah
                    _fetchBankAccounts(); // Ambil rekening bank berdasarkan merchant
                  });
                },
                validator: (value) => value == null ? 'Pilih merchant' : null,
              ),
              SizedBox(height: 24),
              Text(
                'Rekening Tujuan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              DropdownButtonFormField<Map<String, dynamic>>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                hint: Text('Pilih Rekening Bank'),
                value: selectedAccount, // Rekening bank yang dipilih
                items: bankAccounts.map((account) {
                  return DropdownMenuItem<Map<String, dynamic>>(
                    value: account,
                    child: Text(
                        "${account['bank_name']} - ${account['account_number']}"),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedAccount = value;
                  });
                },
                validator: (value) => value == null ? 'Pilih rekening' : null,
              ),
              SizedBox(height: 24),
              Text(
                'Jumlah Pencairan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  prefixText: 'Rp ',
                ),
                validator: (value) {
                  if (value?.isEmpty ?? true) return 'Wajib diisi';
                  final amount = double.tryParse(value!) ?? 0;
                  if (amount <= 0) return 'Jumlah harus lebih dari 0';
                  if (amount > widget.balance)
                    return 'Jumlah melebihi saldo tersedia';
                  return null;
                },
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitWithdrawal,
                  child: Text('Ajukan Pencairan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
