import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'branch_order_detail_screen.dart';
import '../../../controllers/order_controller.dart';

class BranchOrdersScreen extends StatefulWidget {
  @override
  _BranchOrdersScreenState createState() => _BranchOrdersScreenState();
}

class _BranchOrdersScreenState extends State<BranchOrdersScreen> {
  final supabase = Supabase.instance.client;
  final allOrders = <Map<String, dynamic>>[].obs;
  final filteredOrders = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final searchController = TextEditingController();
  final selectedStatus = 'all'.obs;

  void _filterOrders() {
    final searchQuery = searchController.text.toLowerCase();

    filteredOrders.value = allOrders.where((order) {
      // Filter berdasarkan status
      if (selectedStatus.value != 'all' &&
          order['status'] != selectedStatus.value) {
        return false;
      }

      // Filter berdasarkan pencarian
      if (searchQuery.isNotEmpty) {
        final orderId = order['id'].toString().toLowerCase();
        final branchName =
            order['branches']?['name']?.toString().toLowerCase() ?? '';
        final recipientName =
            order['branch_shipping_details']?.isNotEmpty == true
                ? order['branch_shipping_details'][0]['recipient_name']
                        ?.toString()
                        .toLowerCase() ??
                    ''
                : '';

        return orderId.contains(searchQuery) ||
            branchName.contains(searchQuery) ||
            recipientName.contains(searchQuery);
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    fetchOrders();
  }

  Future<void> fetchOrders() async {
    try {
      isLoading.value = true;

      final response = await supabase.from('branch_orders').select('''
            *,
            branches:branch_id (name),
            branch_shipping_details (*),
            branch_order_items (
              *,
              products:product_id (name, price)
            )
          ''').order('created_at', ascending: false);

      allOrders.value = List<Map<String, dynamic>>.from(response);
      _filterOrders(); // Apply initial filter
    } catch (e) {
      print('Error fetching orders: $e');
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pesanan Branch'),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: Obx(() {
              if (isLoading.value) {
                return Center(child: CircularProgressIndicator());
              }

              if (filteredOrders.isEmpty) {
                return Center(
                  child: Text(
                    searchController.text.isEmpty &&
                            selectedStatus.value == 'all'
                        ? 'Tidak ada pesanan'
                        : 'Tidak ada pesanan yang sesuai filter',
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: fetchOrders,
                child: ListView.builder(
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Cari berdasarkan ID, Branch, atau Penerima...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onChanged: (value) => _filterOrders(),
          ),
          SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua', 'all'),
                _buildFilterChip('Pending', 'pending'),
                _buildFilterChip('Diproses', 'processing'),
                _buildFilterChip('Dikirim', 'shipping'),
                _buildFilterChip('Selesai', 'completed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    return Obx(() {
      final isSelected = selectedStatus.value == value;
      return Padding(
        padding: EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (bool selected) {
            selectedStatus.value = selected ? value : 'all';
            _filterOrders();
          },
          backgroundColor: Colors.grey[200],
          selectedColor: AppTheme.primary.withOpacity(0.2),
          labelStyle: TextStyle(
            color: isSelected ? AppTheme.primary : Colors.black87,
          ),
        ),
      );
    });
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final shippingDetails = order['branch_shipping_details'] != null &&
            order['branch_shipping_details'].isNotEmpty
        ? order['branch_shipping_details'][0]
        : null;
    final orderItems =
        List<Map<String, dynamic>>.from(order['branch_order_items'] ?? []);
    final totalItems = orderItems.fold<int>(
        0, (sum, item) => sum + (item['quantity'] as int? ?? 0));

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _viewOrderDetail(order),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${order['id'].toString().substring(0, 8)}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildStatusChip(order['status'] ?? 'pending'),
                ],
              ),
              Divider(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Branch: ${order['branches']?['name'] ?? 'Unknown'}'),
                        SizedBox(height: 4),
                        if (shippingDetails != null)
                          Text(
                              'Penerima: ${shippingDetails['recipient_name'] ?? 'N/A'}'),
                        Text('Total Item: $totalItems'),
                        Text(
                          'Total: Rp${NumberFormat('#,###').format(order['total_amount'] ?? 0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                        Text(
                          'Tanggal: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(order['created_at'] ?? DateTime.now().toIso8601String()))}',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pending';
        break;
      case 'processing':
        color = Colors.blue;
        label = 'Diproses';
        break;
      case 'shipping':
        color = Colors.purple;
        label = 'Dikirim';
        break;
      case 'completed':
        color = Colors.green;
        label = 'Selesai';
        break;
      default:
        color = Colors.grey;
        label = 'Unknown';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  final ordersController = Get.put(OrderController());

  void _viewOrderDetail(Map<String, dynamic> order) async {
    final updatedOrder =
        await Get.to(() => BranchOrderDetailScreen(order: order));
    if (updatedOrder != null) {
      ordersController.updateOrder(updatedOrder);
    }
  }
}
