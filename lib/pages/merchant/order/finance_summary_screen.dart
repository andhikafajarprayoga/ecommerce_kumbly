import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class FinanceSummaryScreen extends StatefulWidget {
  const FinanceSummaryScreen({Key? key}) : super(key: key);

  @override
  _FinanceSummaryScreenState createState() => _FinanceSummaryScreenState();
}

class _FinanceSummaryScreenState extends State<FinanceSummaryScreen> {
  final supabase = Supabase.instance.client;
  final completedAmount = 0.0.obs;
  final cancelledAmount = 0.0.obs;
  final pendingAmount = 0.0.obs;
  final hotelCompletedAmount = 0.0.obs;
  final hotelCancelledAmount = 0.0.obs;
  final hotelPendingAmount = 0.0.obs;
  final hotelConfirmedAmount = 0.0.obs;
  final selectedBankAccount = Rxn<Map<String, dynamic>>();
  final withdrawalAmount = TextEditingController();
  final bankAccounts = <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    _fetchFinanceSummary();
    _fetchHotelFinanceSummary();
    _fetchBankAccounts();
  }

  Future<void> _fetchFinanceSummary() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await supabase
          .from('orders')
          .select('status, total_amount')
          .eq('merchant_id', currentUserId);

      double completed = 0.0;
      double cancelled = 0.0;
      double pending = 0.0;

      for (var order in response) {
        switch (order['status']) {
          case 'completed':
            completed += (order['total_amount'] ?? 0.0);
            break;
          case 'cancelled':
            cancelled += (order['total_amount'] ?? 0.0);
            break;
          case 'pending':
            pending += (order['total_amount'] ?? 0.0);
            break;
        }
      }

      completedAmount.value = completed;
      cancelledAmount.value = cancelled;
      pendingAmount.value = pending;
    } catch (e) {
      print('Error fetching finance summary: $e');
    }
  }

  Future<void> _fetchHotelFinanceSummary() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final hotels =
          await supabase.from('hotels').select('id').eq('merchant_id', userId);

      if (hotels.isEmpty) return;

      final hotelIds = (hotels as List).map((hotel) => hotel['id']).toList();

      final bookings = await supabase
          .from('hotel_bookings')
          .select('status, total_price')
          .inFilter('hotel_id', hotelIds);

      print('DEBUG - Raw Bookings Data:');
      bookings.forEach((booking) {
        print(
            'Status: ${booking['status']}, Amount: ${booking['total_price']}');
      });

      double completed = 0.0;
      double cancelled = 0.0;
      double pending = 0.0;
      double confirmed = 0.0;

      for (var booking in bookings) {
        final amount = (booking['total_price'] ?? 0.0).toDouble();
        switch (booking['status']) {
          case 'cancelled':
            cancelled += amount;
            print('Added to cancelled: $amount, Total: $cancelled');
            break;
          case 'confirmed':
            confirmed += amount;
            print('Added to confirmed: $amount, Total: $confirmed');
            break;
          case 'pending':
            pending += amount;
            print('Added to pending: $amount, Total: $pending');
            break;
          case 'completed':
            completed += amount;
            print('Added to completed: $amount, Total: $completed');
            break;
        }
      }

      print('Final Totals:');
      print('Cancelled: $cancelled');
      print('Confirmed: $confirmed');
      print('Pending: $pending');
      print('Completed: $completed');

      hotelCompletedAmount.value = completed;
      hotelCancelledAmount.value = cancelled;
      hotelPendingAmount.value = pending;
      hotelConfirmedAmount.value = confirmed;
    } catch (e) {
      print('Error fetching hotel finance summary: $e');
    }
  }

  Future<void> _fetchBankAccounts() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('merchant_bank_accounts')
          .select()
          .eq('merchant_id', userId)
          .eq('is_active', true);

      bankAccounts.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching bank accounts: $e');
    }
  }

  double get totalAvailableBalance =>
      completedAmount.value + hotelCompletedAmount.value;

  Future<void> _submitWithdrawal() async {
    if (selectedBankAccount.value == null) {
      Get.snackbar('Error', 'Silakan pilih rekening bank');
      return;
    }

    final amount = double.tryParse(withdrawalAmount.text);
    if (amount == null || amount <= 0) {
      Get.snackbar('Error', 'Masukkan jumlah yang valid');
      return;
    }

    if (amount > totalAvailableBalance) {
      Get.snackbar('Error',
          'Jumlah melebihi saldo yang tersedia (Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(totalAvailableBalance)})');
      return;
    }

    try {
      await supabase.from('withdrawal_requests').insert({
        'merchant_id': supabase.auth.currentUser!.id,
        'bank_account_id': selectedBankAccount.value!['id'],
        'amount': amount,
      });

      Get.back();
      Get.snackbar('Sukses', 'Permintaan pencairan berhasil diajukan');
      withdrawalAmount.clear();
      selectedBankAccount.value = null;
    } catch (e) {
      Get.snackbar('Error', 'Gagal mengajukan pencairan');
    }
  }

  void _showWithdrawalBottomSheet() {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cairkan Dana',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Saldo tersedia: Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(totalAvailableBalance)}',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Obx(() => DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: InputDecoration(
                    labelText: 'Pilih Rekening Bank',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  value: selectedBankAccount.value,
                  items: bankAccounts.map((account) {
                    return DropdownMenuItem(
                      value: account,
                      child: Text(
                          '${account['bank_name']} - ${account['account_number']}'),
                    );
                  }).toList(),
                  onChanged: (value) => selectedBankAccount.value = value,
                )),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: withdrawalAmount,
                    decoration: InputDecoration(
                      labelText: 'Jumlah Pencairan',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final amount = double.tryParse(value) ?? 0;
                      if (amount > totalAvailableBalance) {
                        withdrawalAmount.text =
                            totalAvailableBalance.toString();
                        Get.snackbar(
                          'Peringatan',
                          'Jumlah melebihi saldo yang tersedia',
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.TOP,
                          duration: Duration(seconds: 2),
                        );
                      }
                    },
                  ),
                ),
                SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    withdrawalAmount.text = totalAvailableBalance.toString();
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: AppTheme.primary.withOpacity(0.1),
                  ),
                  child: Text(
                    'Semua',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: Text('Batal'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitWithdrawal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text('Ajukan Pencairan',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Keuangan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            )),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: Obx(() => SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card Saldo Tersedia
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 8,
                  color: AppTheme.primary,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Saldo Tersedia',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Rp ${NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(totalAvailableBalance)}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: totalAvailableBalance > 0
                              ? _showWithdrawalBottomSheet
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.primary,
                            minimumSize: Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('Cairkan Dana'),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                _buildSummaryCard('Transaksi Produk', Icons.shopping_bag, [
                  _buildSummaryRow(
                      'Transaksi Selesai', completedAmount.value, Colors.green),
                  _buildSummaryRow('Transaksi Dibatalkan',
                      cancelledAmount.value, Colors.red),
                  _buildSummaryRow(
                      'Transaksi Pending', pendingAmount.value, Colors.orange),
                ]),
                SizedBox(height: 24),
                _buildSummaryCard('Transaksi Hotel', Icons.hotel, [
                  _buildSummaryRow('Booking Selesai',
                      hotelCompletedAmount.value, Colors.green),
                  _buildSummaryRow('Booking Terkonfirmasi',
                      hotelConfirmedAmount.value, Colors.blue),
                  _buildSummaryRow('Booking Pending', hotelPendingAmount.value,
                      Colors.orange),
                  _buildSummaryRow('Booking Dibatalkan',
                      hotelCancelledAmount.value, Colors.red),
                ]),
              ],
            ),
          )),
    );
  }

  Widget _buildSummaryCard(String title, IconData icon, List<Widget> rows) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      shadowColor: Colors.black12,
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppTheme.primary, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Column(children: rows),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, double amount, Color color) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          Text(
            formatter.format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
