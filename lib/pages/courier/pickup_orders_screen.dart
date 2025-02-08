import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/active_delivery_controller.dart';
import 'package:intl/intl.dart';
import '../../models/active_delivery.dart';
import 'dart:convert';

class PickupOrdersScreen extends StatelessWidget {
  final controller = Get.put(ActiveDeliveryController());

  PickupOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jemput Paket'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        print('\n=== DEBUG PICKUP ORDERS ===');
        print('Total orders: ${controller.processingDeliveries.length}');

        // Filter hanya berdasarkan status processing
        final availableOrders = controller.processingDeliveries
            .where((order) => order.status == 'processing')
            .toList();

        print('\n=== AFTER FILTER ===');
        print('Available orders: ${availableOrders.length}');

        availableOrders.forEach((order) {
          print('''
Order ID: ${order.id}
Courier ID: ${order.courierId}
Status: ${order.status}
Merchant: ${order.merchantName}
---------------------''');
        });

        if (availableOrders.isEmpty) {
          return const Center(
            child: Text('Tidak ada paket yang perlu dijemput'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: availableOrders.length,
          itemBuilder: (context, index) {
            final order = availableOrders[index];

            // Parse alamat merchant dari JSON string
            Map<String, dynamic>? merchantAddressJson;
            try {
              if (order.merchantAddress != null) {
                merchantAddressJson = jsonDecode(order.merchantAddress!);
              }
            } catch (e) {
              print('Error parsing merchant address: $e');
            }

            // Format alamat merchant
            String formattedMerchantAddress = '';
            if (merchantAddressJson != null) {
              formattedMerchantAddress = [
                merchantAddressJson['street'],
                merchantAddressJson['village'],
                merchantAddressJson['district'],
                merchantAddressJson['city'],
                merchantAddressJson['province'],
                merchantAddressJson['postal_code'],
              ].where((e) => e != null).join(', ');
            }

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${order.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Menunggu Pickup',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      icon: Icons.store,
                      label: 'Penjual',
                      value: order.merchantName ?? "Tidak tersedia",
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.location_on,
                      label: 'Alamat',
                      value: formattedMerchantAddress.isNotEmpty
                          ? formattedMerchantAddress
                          : "Tidak tersedia",
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.phone,
                      label: 'Telepon',
                      value: order.merchantPhone ?? "Tidak tersedia",
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      icon: Icons.payment,
                      label: 'Total',
                      value: NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                      ).format(order.totalAmount),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await controller.assignCourier(order.id);
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Terima Pesanan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
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
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
