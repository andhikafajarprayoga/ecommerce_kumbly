import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({Key? key}) : super(key: key);

  @override
  _PerformanceScreenState createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  final supabase = Supabase.instance.client;
  // Produk metrics
  final totalOrders = 0.obs;
  final completedOrders = 0.obs;
  final cancelledOrders = 0.obs;
  final totalRevenue = 0.0.obs;
  final averageOrderValue = 0.0.obs;
  // Hotel metrics
  final totalBookings = 0.obs;
  final completedBookings = 0.obs;
  final confirmedBookings = 0.obs;
  final cancelledBookings = 0.obs;
  final totalHotelRevenue = 0.0.obs;
  final averageBookingValue = 0.0.obs;

  @override
  void initState() {
    super.initState();
    _fetchPerformanceData();
    _fetchHotelPerformanceData();
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

  Future<void> _fetchHotelPerformanceData() async {
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

      int total = 0;
      int completed = 0;
      int confirmed = 0;
      int cancelled = 0;
      double revenue = 0.0;

      for (var booking in bookings) {
        total++;
        switch (booking['status']) {
          case 'completed':
            completed++;
            revenue += (booking['total_price'] ?? 0.0);
            break;
          case 'confirmed':
            confirmed++;
            break;
          case 'cancelled':
            cancelled++;
            break;
        }
      }

      totalBookings.value = total;
      completedBookings.value = completed;
      confirmedBookings.value = confirmed;
      cancelledBookings.value = cancelled;
      totalHotelRevenue.value = revenue;
      averageBookingValue.value = completed > 0 ? revenue / completed : 0;
    } catch (e) {
      print('Error fetching hotel performance data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performa', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
      ),
      body: Obx(() => SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Performa Produk', Icons.shopping_bag),
                      SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          _buildMetricCard(
                              'Total\nPesanan',
                              totalOrders.value.toString(),
                              Icons.shopping_cart,
                              Colors.blue),
                          _buildMetricCard(
                              'Pesanan\nSelesai',
                              completedOrders.value.toString(),
                              Icons.check_circle,
                              Colors.green),
                          _buildMetricCard(
                              'Pesanan\nBatal',
                              cancelledOrders.value.toString(),
                              Icons.cancel,
                              Colors.red),
                        ],
                      ),
                      SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          _buildMetricCard(
                              'Total Pendapatan',
                              'Rp ${NumberFormat('#,###').format(totalRevenue.value)}',
                              Icons.payments,
                              Colors.purple),
                          _buildMetricCard(
                              'Rata-rata',
                              'Rp ${NumberFormat('#,###').format(averageOrderValue.value)}',
                              Icons.analytics,
                              Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 1),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Performa Hotel', Icons.hotel),
                      SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        childAspectRatio: 1.2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          _buildMetricCard(
                              'Total\nBooking',
                              totalBookings.value.toString(),
                              Icons.book_online,
                              Colors.blue),
                          _buildMetricCard(
                              'Booking\nSelesai',
                              completedBookings.value.toString(),
                              Icons.check_circle,
                              Colors.green),
                          _buildMetricCard(
                              'Booking\nBatal',
                              cancelledBookings.value.toString(),
                              Icons.cancel,
                              Colors.red),
                        ],
                      ),
                      SizedBox(height: 8),
                      GridView.count(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          _buildMetricCard(
                              'Total Pendapatan',
                              'Rp ${NumberFormat('#,###').format(totalHotelRevenue.value)}',
                              Icons.payments,
                              Colors.purple),
                          _buildMetricCard(
                              'Rata-rata',
                              'Rp ${NumberFormat('#,###').format(averageBookingValue.value)}',
                              Icons.analytics,
                              Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary, size: 20),
        SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
