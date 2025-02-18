import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/shipments_controller.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class ShipmentsScreen extends StatefulWidget {
  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final ShipmentsController controller = Get.put(ShipmentsController());
  final supabase = Supabase.instance.client;
  RealtimeChannel? _ordersSubscription;
  String selectedStatus = 'all';
  List<Map<String, dynamic>> allOrders = [];
  List<Map<String, dynamic>> filteredOrders = [];
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchOrders();
    _initializeRealtime();
  }

  Future<void> fetchOrders() async {
    try {
      var query = supabase
          .from('orders')
          .select('*, users!orders_buyer_id_fkey(email, full_name, phone)');

      if (selectedStatus != 'all') {
        query = query.eq('status', selectedStatus);
      }

      final response = await query.order('created_at', ascending: false);

      setState(() {
        // Sort data berdasarkan prioritas status dan created_at
        allOrders = List<Map<String, dynamic>>.from(response)
          ..sort((a, b) {
            // Prioritas status
            final statusPriority = {
              'pending': 0,
              'processing': 1,
              'shipping': 2,
              'transit': 3,
              'delivered': 4,
              'completed': 5,
              'cancelled': 6,
              'pending_cancellation': 7,
            };

            final aStatus = statusPriority[a['status']] ?? 999;
            final bStatus = statusPriority[b['status']] ?? 999;

            // Jika status berbeda, urutkan berdasarkan prioritas
            if (aStatus != bStatus) {
              return aStatus.compareTo(bStatus);
            }

            // Jika status sama, urutkan berdasarkan created_at terbaru
            final aDate = DateTime.parse(a['created_at']);
            final bDate = DateTime.parse(b['created_at']);
            return bDate.compareTo(aDate);
          });

        applyFilters(searchController.text);
      });
    } catch (e) {
      print('Error fetching orders: $e');
    }
  }

  void applyFilters(String searchQuery) {
    setState(() {
      filteredOrders = allOrders.where((order) {
        // Jika ada query pencarian
        if (searchQuery.isNotEmpty) {
          final buyerId = order['buyer_id'].toString().toLowerCase();
          final searchLower = searchQuery.toLowerCase();
          return buyerId.contains(searchLower);
        }
        return true;
      }).toList();
    });
  }

  void _initializeRealtime() {
    final supabase = Supabase.instance.client;

    // Setup realtime subscription
    _ordersSubscription = supabase
        .channel('orders_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            fetchOrders();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _ordersSubscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pengiriman'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari berdasarkan ID Pembeli...',
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: applyFilters,
            ),
          ),

          // Filter Chips
          _buildFilterSection(),

          // Results Count
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Hasil: ${filteredOrders.length} pengiriman',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  selectedStatus != 'all'
                      ? _getStatusIndonesia(selectedStatus)
                      : 'Semua Status',
                  style: TextStyle(
                    color: Colors.pink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.local_shipping_outlined,
                            size: 80, color: Colors.grey[300]),
                        SizedBox(height: 16),
                        Text(
                          'Tidak ada data pengiriman',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredOrders.length,
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return _buildOrderCard(order);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip('all', 'Semua'),
          SizedBox(width: 8),
          _buildFilterChip('pending', 'Menunggu'),
          SizedBox(width: 8),
          _buildFilterChip('pending_cancellation', 'Menunggu Pembatalan'),
          SizedBox(width: 8),
          _buildFilterChip('processing', 'Diproses'),
          SizedBox(width: 8),
          _buildFilterChip('transit', 'Transit'),
          SizedBox(width: 8),
          _buildFilterChip('shipping', 'Dikirim'),
          SizedBox(width: 8),
          _buildFilterChip('delivered', 'Terkirim'),
          SizedBox(width: 8),
          _buildFilterChip('completed', 'Selesai'),
          SizedBox(width: 8),
          _buildFilterChip('cancelled', 'Dibatalkan'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, String label) {
    return FilterChip(
      selected: selectedStatus == status,
      label: Text(label),
      onSelected: (bool selected) {
        setState(() {
          selectedStatus = status;
        });
        fetchOrders(); // Ambil data baru sesuai filter
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.pink.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selectedStatus == status ? Colors.pink : Colors.black87,
        fontWeight:
            selectedStatus == status ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.pink,
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      child: InkWell(
        onTap: () => controller.goToDetail(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.blue,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: ${order['id']}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 16, color: Colors.grey[600]),
                            SizedBox(width: 4),
                            Text(
                              'ID Pembeli: ',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(
                                    text: order['buyer_id'].toString(),
                                  ));
                                  Get.snackbar(
                                    'Sukses',
                                    'ID Pembeli berhasil disalin',
                                    backgroundColor: Colors.green,
                                    colorText: Colors.white,
                                    duration: Duration(seconds: 2),
                                  );
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      '${order['buyer_id'].toString().substring(0, 8)}...',
                                      style: TextStyle(
                                        color: Colors.blue[700],
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                      ),
                                    ),
                                    Icon(
                                      Icons.copy,
                                      size: 14,
                                      color: Colors.blue[700],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(order['status']),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: Colors.grey[500], size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            order['shipping_address'],
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.payments_outlined,
                            color: Colors.grey[500], size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Rp ${order['total_amount']}',
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status) {
      case 'pending':
        chipColor = Colors.blue;
        break;
      case 'processing':
        chipColor = Colors.orange;
        break;
      case 'shipping':
        chipColor = Colors.purple;
        break;
      case 'completed':
        chipColor = Colors.green;
        break;
      case 'cancelled':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withOpacity(0.2)),
      ),
      child: Text(
        controller.getStatusIndonesia(status),
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getStatusIndonesia(String status) {
    // Implementasi untuk mengonversi status ke bahasa Indonesia
    // Contoh: Menggunakan switch statement untuk kasus sederhana
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
        return 'Status Tidak Diketahui';
    }
  }
}
