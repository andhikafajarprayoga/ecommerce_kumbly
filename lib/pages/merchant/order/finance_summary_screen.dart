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

  @override
  void initState() {
    super.initState();
    _fetchFinanceSummary();
    _fetchHotelFinanceSummary();
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

      double completed = 0.0;
      double cancelled = 0.0;
      double pending = 0.0;
      double confirmed = 0.0;

      for (var booking in bookings) {
        switch (booking['status']) {
          case 'completed':
            completed += (booking['total_price'] ?? 0.0);
            break;
          case 'cancelled':
            cancelled += (booking['total_price'] ?? 0.0);
            break;
          case 'pending':
            pending += (booking['total_price'] ?? 0.0);
            break;
          case 'confirmed':
            confirmed += (booking['total_price'] ?? 0.0);
            break;
        }
      }

      hotelCompletedAmount.value = completed;
      hotelCancelledAmount.value = cancelled;
      hotelPendingAmount.value = pending;
      hotelConfirmedAmount.value = confirmed;
    } catch (e) {
      print('Error fetching hotel finance summary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ringkasan Keuangan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.normal,
            )),
        backgroundColor: AppTheme.primary,
        elevation: 0,
      ),
      body: Obx(() => SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      shadowColor: Colors.black12,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 28),
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
            SizedBox(height: 16),
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
