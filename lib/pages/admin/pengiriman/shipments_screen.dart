import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/shipments_controller.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShipmentsScreen extends StatefulWidget {
  @override
  State<ShipmentsScreen> createState() => _ShipmentsScreenState();
}

class _ShipmentsScreenState extends State<ShipmentsScreen> {
  final ShipmentsController controller = Get.put(ShipmentsController());
  RealtimeChannel? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    _initializeRealtime();
  }

  void _initializeRealtime() {
    final supabase = Supabase.instance.client;

    // Initial fetch
    controller.fetchOrders();

    // Setup realtime subscription
    _ordersSubscription = supabase
        .channel('orders_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            controller.fetchOrders();
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
        title: Text(
          'Pengiriman',
          style: TextStyle(fontWeight: FontWeight.normal),
        ),
        elevation: 0,
        backgroundColor: AppTheme.primary,
        foregroundColor: const Color.fromARGB(221, 255, 255, 255),
      ),
      body: Container(
        color: Colors.grey[50],
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildFilterSection(),
              SizedBox(height: 16),
              _buildShipmentsList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller.searchController,
              onChanged: (value) => controller.filterShipments(),
              decoration: InputDecoration(
                hintText: 'Cari ID atau alamat pengiriman...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue, width: 1),
                ),
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Obx(() => DropdownButton<String>(
                    value: controller.selectedStatus.value,
                    isExpanded: true,
                    underline: SizedBox(),
                    items: [
                      'Semua',
                      'Menunggu',
                      'Menunggu Pembatalan',
                      'Diproses',
                      'Transit',
                      'Dikirim',
                      'Terkirim',
                      'Selesai',
                      'Dibatalkan',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        controller.filterByStatus(newValue);
                      }
                    },
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                    ),
                    icon: Icon(Icons.keyboard_arrow_down_rounded),
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShipmentsList() {
    return Expanded(
      child: Obx(() => controller.filteredOrders.isEmpty
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: controller.filteredOrders.length,
              itemBuilder: (context, index) {
                final orderData = controller.filteredOrders[index];
                return Card(
                  elevation: 0,
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!, width: 1),
                  ),
                  child: InkWell(
                    onTap: () => controller.goToDetail(orderData),
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
                                child: Text(
                                  'ID: ${orderData['id']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _buildStatusChip(orderData['status']),
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
                                        orderData['shipping_address'],
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
                                      'Rp ${orderData['total_amount']}',
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
              },
            )),
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
}
