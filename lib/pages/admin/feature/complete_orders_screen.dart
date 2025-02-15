import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class CompleteOrdersScreen extends StatefulWidget {
  @override
  _CompleteOrdersScreenState createState() => _CompleteOrdersScreenState();
}

class _CompleteOrdersScreenState extends State<CompleteOrdersScreen>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final RxList<Map<String, dynamic>> orders = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchOrders();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    try {
      isLoading.value = true;

      final response = await supabase.from('orders').select('''
            *,
            buyer:users (
              full_name,
              phone
            ),
            payment_method:payment_methods (
              name
            ),
            courier:users (
              email
            )
          ''').inFilter('status', [
        'delivered',
        'completed'
      ]) // Ambil kedua status
          .order('created_at', ascending: false);

      orders.assignAll(List<Map<String, dynamic>>.from(response));
    } catch (e) {
      print('Error fetching orders: $e');
      Get.snackbar('Error', 'Gagal memuat data pesanan',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _completeOrder(String orderId) async {
    try {
      await supabase.from('orders').update({
        'status': 'completed',
      }).eq('id', orderId);

      Get.snackbar(
        'Sukses',
        'Pesanan berhasil diselesaikan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _fetchOrders();
    } catch (e) {
      print('Error completing order: $e');
      Get.snackbar(
        'Error',
        'Gagal menyelesaikan pesanan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tabController == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(
        title: Text('Selesaikan Pesanan'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Perlu Diselesaikan'),
            Tab(text: 'Sudah Selesai'),
          ],
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(status: 'delivered', showCompleteButton: true),
          _buildOrdersList(status: 'completed', showCompleteButton: false),
        ],
      ),
    );
  }

  Widget _buildOrdersList(
      {required String status, required bool showCompleteButton}) {
    return Column(
      children: [
        // Header Summary
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          child: Obx(() {
            final filteredOrders =
                orders.where((o) => o['status'] == status).toList();
            double totalAmount = 0;

            // Hitung total amount
            for (var order in filteredOrders) {
              totalAmount += (order['total_amount'] ?? 0) +
                  (order['shipping_cost'] ?? 0) +
                  (order['payment_method']?['admin'] ?? 0);
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        status == 'delivered'
                            ? 'Perlu Diselesaikan'
                            : 'Sudah Selesai',
                        '${filteredOrders.length}',
                        status == 'delivered'
                            ? Icons.pending_actions
                            : Icons.check_circle_outline,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payments_outlined,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 8),
                              Text(
                                'Total Pendapatan',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            NumberFormat.currency(
                              locale: 'id',
                              symbol: 'Rp ',
                              decimalDigits: 0,
                            ).format(totalAmount),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),

        // Orders List
        Expanded(
          child: Obx(() {
            if (isLoading.value) {
              return Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            }

            final filteredOrders =
                orders.where((o) => o['status'] == status).toList();

            if (filteredOrders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 80, color: Colors.grey[300]),
                    SizedBox(height: 16),
                    Text(
                      status == 'delivered'
                          ? 'Tidak ada pesanan yang perlu diselesaikan'
                          : 'Belum ada pesanan yang selesai',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _fetchOrders(),
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  final buyer = order['buyer'] as Map<String, dynamic>;
                  final paymentMethod =
                      order['payment_method'] as Map<String, dynamic>;
                  final courier = order['courier'] as Map<String, dynamic>?;

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Order Header
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${order['id'].toString().substring(0, 8)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy HH:mm').format(
                                        DateTime.parse(order['created_at'])),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                        ),

                        // Order Details
                        Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _buildDetailRow(
                                Icons.person_outline,
                                'Pembeli',
                                buyer['full_name'],
                              ),
                              _buildDetailRow(
                                Icons.phone_outlined,
                                'Telepon',
                                buyer['phone'],
                              ),
                              _buildDetailRow(
                                Icons.payment_outlined,
                                'Pembayaran',
                                paymentMethod['name'],
                              ),
                              _buildDetailRow(
                                Icons.delivery_dining_outlined,
                                'Kurir',
                                courier?['email'] ?? 'Belum ditentukan',
                              ),
                              _buildDetailRow(
                                Icons.location_on_outlined,
                                'Alamat',
                                order['shipping_address'],
                              ),
                              Divider(height: 24),
                              _buildDetailRow(
                                Icons.attach_money,
                                'Total',
                                NumberFormat.currency(
                                  locale: 'id',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(order['total_amount']),
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),

                        // Action Button - hanya tampilkan jika showCompleteButton true
                        if (showCompleteButton) ...[
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: ElevatedButton.icon(
                              onPressed: () => _completeOrder(order['id']),
                              icon: Icon(Icons.check_circle_outline),
                              label: Text('Selesaikan Pesanan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                minimumSize: Size(double.infinity, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value,
      {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                    color: isTotal ? Colors.green : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined, size: 16, color: Colors.blue),
          SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              color: Colors.blue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
