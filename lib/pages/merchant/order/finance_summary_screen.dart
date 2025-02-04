import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchFinanceSummary();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Keuangan'),
      ),
      body: Obx(() => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSummaryCard(
                  'Transaksi Selesai',
                  completedAmount.value,
                  Colors.green,
                  Icons.check_circle,
                ),
                _buildSummaryCard(
                  'Transaksi Dibatalkan',
                  cancelledAmount.value,
                  Colors.red,
                  Icons.cancel,
                ),
                _buildSummaryCard(
                  'Transaksi Pending',
                  pendingAmount.value,
                  Colors.orange,
                  Icons.pending,
                ),
              ],
            ),
          )),
    );
  }

  Widget _buildSummaryCard(
      String title, double amount, Color color, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
          'Rp ${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}
