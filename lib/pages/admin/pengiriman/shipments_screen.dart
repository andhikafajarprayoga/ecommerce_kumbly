import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/shipments_controller.dart';
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
        title: Text('Pengiriman'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilterSection(),
            SizedBox(height: 16),
            _buildShipmentsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: controller.searchController,
              onChanged: (value) => controller.filterShipments(),
              decoration: InputDecoration(
                hintText: 'Cari ID atau alamat pengiriman...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Obx(() => DropdownButtonFormField(
                    value: controller.selectedStatus.value,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Semua',
                      'Menunggu',
                      'Menunggu Pembatalan',
                      'Diproses',
                      'Dikirim',
                      'Terkirim',
                      'Selesai',
                      'Dibatalkan'
                    ].map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ))
                        .toList(),
                    onChanged: (value) => controller.filterByStatus(value.toString()),
                  )),
                ),
              ],
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
                       size: 64, 
                       color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Tidak ada data pengiriman',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
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
                  elevation: 2,
                  margin: EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                              SizedBox(width: 8),
                              _buildStatusChip(orderData['status']),
                            ],
                          ),

                          SizedBox(height: 12),

                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, 
                                   color: Colors.grey,
                                   size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  orderData['shipping_address'],
                                  style: TextStyle(
                                    color: Colors.grey[600],

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
                                   color: Colors.grey,
                                   size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Rp ${orderData['total_amount']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],

                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,

                                  ),
                                  overflow: TextOverflow.ellipsis,
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        controller.getStatusIndonesia(status),
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
