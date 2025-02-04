import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({Key? key}) : super(key: key);

  @override
  _PerformanceScreenState createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final supabase = Supabase.instance.client;
  final totalOrders = 0.obs;
  final completedOrders = 0.obs;
  final cancelledOrders = 0.obs;
  final totalRevenue = 0.0.obs;
  final averageOrderValue = 0.0.obs;

  @override
  void initState() {
    super.initState();
    _fetchPerformanceData();
  }

  Future<void> _fetchPerformanceData() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await supabase
          .from('orders')
          .select('status, total_amount')
          .eq('merchant_id', currentUserId);

      int total = 0;
      int completed = 0;
      int cancelled = 0;
      double revenue = 0.0;

      for (var order in response) {
        total++;
        switch (order['status']) {
          case 'completed':
            completed++;
            revenue += (order['total_amount'] ?? 0.0);
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      totalOrders.value = total;
      completedOrders.value = completed;
      cancelledOrders.value = cancelled;
      totalRevenue.value = revenue;
      averageOrderValue.value = completed > 0 ? revenue / completed : 0;
    } catch (e) {
      print('Error fetching performance data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performa Toko'),
      ),
      body: Obx(() => SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildPerformanceCard(
                  'Total Pesanan',
                  totalOrders.value.toString(),
                  Icons.shopping_bag,
                  Colors.blue,
                ),
                _buildPerformanceCard(
                  'Pesanan Selesai',
                  completedOrders.value.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildPerformanceCard(
                  'Pesanan Dibatalkan',
                  cancelledOrders.value.toString(),
                  Icons.cancel,
                  Colors.red,
                ),
                _buildPerformanceCard(
                  'Total Pendapatan',
                  'Rp ${totalRevenue.value.toStringAsFixed(0)}',
                  Icons.payments,
                  Colors.purple,
                ),
                _buildPerformanceCard(
                  'Rata-rata Nilai Pesanan',
                  'Rp ${averageOrderValue.value.toStringAsFixed(0)}',
                  Icons.analytics,
                  Colors.orange,
                ),
                _buildSuccessRateCard(),
              ],
            ),
          )),
    );
  }

  Widget _buildPerformanceCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: color, size: 32),
        title: Text(title),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessRateCard() {
    double successRate = totalOrders > 0
        ? (completedOrders.value / totalOrders.value) * 100
        : 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Tingkat Keberhasilan Pesanan',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              '${successRate.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}