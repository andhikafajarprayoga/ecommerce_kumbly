import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class HotelFinancialSummaryScreen extends StatefulWidget {
  @override
  _HotelFinancialSummaryScreenState createState() =>
      _HotelFinancialSummaryScreenState();
}

class _HotelFinancialSummaryScreenState
    extends State<HotelFinancialSummaryScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  Map<String, double> summaryData = {
    'pending': 0,
    'confirmed': 0,
    'completed': 0,
    'cancelled': 0,
  };

  @override
  void initState() {
    super.initState();
    fetchSummaryData();
  }

  Future<void> fetchSummaryData() async {
    try {
      setState(() => isLoading = true);

      final response = await supabase.from('hotel_bookings').select('''
        id,
        total_price,
        admin_fee,
        app_fee,
        status
      ''');

      Map<String, double> tempSummary = {
        'pending': 0,
        'confirmed': 0,
        'completed': 0,
        'cancelled': 0,
      };

      for (var booking in response) {
        double totalAmount = (booking['total_price'] ?? 0).toDouble() +
            (booking['admin_fee'] ?? 0).toDouble() +
            (booking['app_fee'] ?? 0).toDouble();

        String status = booking['status'] ?? 'pending';
        tempSummary[status] = (tempSummary[status] ?? 0) + totalAmount;
      }

      setState(() {
        summaryData = tempSummary;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching summary: $e');
      setState(() => isLoading = false);
      Get.snackbar(
        'Error',
        'Gagal memuat data ringkasan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ringkasan Keuangan'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSummaryCard(
                    'Total Pending',
                    summaryData['pending'] ?? 0,
                    Colors.orange,
                    Icons.pending,
                  ),
                  SizedBox(height: 16),
                  _buildSummaryCard(
                    'Total Dikonfirmasi',
                    summaryData['confirmed'] ?? 0,
                    Colors.blue,
                    Icons.check_circle_outline,
                  ),
                  SizedBox(height: 16),
                  _buildSummaryCard(
                    'Total Selesai',
                    summaryData['completed'] ?? 0,
                    Colors.green,
                    Icons.done_all,
                  ),
                  SizedBox(height: 16),
                  _buildSummaryCard(
                    'Total Dibatalkan',
                    summaryData['cancelled'] ?? 0,
                    Colors.red,
                    Icons.cancel_outlined,
                  ),
                  SizedBox(height: 24),
                  _buildTotalCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCard(
      String title, double amount, Color color, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Rp ${NumberFormat('#,###').format(amount)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    double total = summaryData.values.fold(0, (sum, amount) => sum + amount);
    return Card(
      elevation: 4,
      color: AppTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Total Keseluruhan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Rp ${NumberFormat('#,###').format(total)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
