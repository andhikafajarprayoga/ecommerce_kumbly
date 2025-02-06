import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';

class OrderListScreen extends StatefulWidget {
  final String sellerId;

  const OrderListScreen({Key? key, required this.sellerId}) : super(key: key);

  @override
  _OrderListScreenState createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final supabase = Supabase.instance.client;
  final orders = <Map<String, dynamic>>[].obs;
  final searchController = TextEditingController();
  final filteredOrders = <Map<String, dynamic>>[].obs;
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final response = await supabase
          .from('orders')
          .select('*')
          .eq('merchant_id', widget.sellerId)
          .order('created_at', ascending: false);

      orders.value = List<Map<String, dynamic>>.from(response);
      filteredOrders.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching orders: $e');
    }
  }

  void _showFilterDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Filter Pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('Semua', 'all'),
            _buildFilterOption('Menunggu', 'pending'),
            _buildFilterOption('Diproses', 'processing'),
            _buildFilterOption('Dikirim', 'shipping'),
            _buildFilterOption('Selesai', 'completed'),
            _buildFilterOption('Dibatalkan', 'cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: selectedFilter,
      onChanged: (newValue) {
        selectedFilter = newValue!;
        _filterOrders();
        Get.back();
      },
    );
  }

  void _filterOrders() {
    if (selectedFilter == 'all') {
      filteredOrders.value = orders;
    } else {
      filteredOrders.value =
          orders.where((order) => order['status'] == selectedFilter).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Daftar Pesanan',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Obx(() => filteredOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.filter_1, size: 80, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    'Tidak ada pesanan ditemukan',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredOrders.length,
              itemBuilder: (context, index) {
                final order = filteredOrders[index];
                final status = order['status'];

                return Card(
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _getStatusColor(status).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      // TODO: Navigate to order detail
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${order['id'].toString().substring(0, 8)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              _buildStatusBadge(status),
                            ],
                          ),
                          Divider(height: 24),
                          Row(
                            children: [
                              Icon(Icons.access_time_outlined,
                                  size: 16, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Text(
                                _formatDate(order['created_at']),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.payments_outlined,
                                  size: 16, color: Colors.grey[600]),
                              SizedBox(width: 8),
                              Text(
                                _formatCurrency(order['total_amount']),
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )),
    );
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(status),
              size: 16, color: _getStatusColor(status)),
          SizedBox(width: 4),
          Text(
            _getStatusText(status),
            style: TextStyle(
              color: _getStatusColor(status),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'shipping':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'processing':
        return 'Diproses';
      case 'shipping':
        return 'Dikirim';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  String _formatCurrency(dynamic amount) {
    return NumberFormat.currency(
      locale: 'id',
      symbol: 'Rp ',
      decimalDigits: 0,
    ).format(amount);
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
      case 'processing':
      case 'shipping':
        return Icons.local_shipping;
      case 'cancelled':
        return Icons.cancel;
      case 'completed':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }
}
