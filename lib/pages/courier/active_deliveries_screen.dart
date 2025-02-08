import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/active_delivery_controller.dart';
import 'package:intl/intl.dart';
import '../../models/active_delivery.dart';
import 'dart:convert';

class ActiveDeliveriesScreen extends StatelessWidget {
  final controller = Get.put(ActiveDeliveryController());

  ActiveDeliveriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Daftar Pengiriman'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Diproses'),
              Tab(text: 'Dikirim'),
              Tab(text: 'Diterima'),
              Tab(text: 'Selesai'),
              Tab(text: 'Dibatalkan'),
              Tab(text: 'Minta Batal'),
            ],
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return TabBarView(
            children: [
              _buildDeliveryList(controller.pendingDeliveries),
              _buildDeliveryList(controller.processingDeliveries),
              _buildDeliveryList(controller.shippingDeliveries),
              _buildDeliveryList(controller.deliveredDeliveries),
              _buildDeliveryList(controller.completedDeliveries),
              _buildDeliveryList(controller.cancelledDeliveries),
              _buildDeliveryList(controller.pendingCancellationDeliveries),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildDeliveryList(List<ActiveDelivery> deliveries) {
    if (deliveries.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada pengiriman',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final delivery = deliveries[index];

        // Parse alamat merchant dari JSON string
        Map<String, dynamic>? merchantAddressJson;
        try {
          if (delivery.merchantAddress != null) {
            merchantAddressJson = jsonDecode(delivery.merchantAddress!);
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
                      'Order #${delivery.id.substring(0, 8)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        delivery.status,
                        style: TextStyle(
                          color: Colors.blue.shade900,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                    'Pembeli', delivery.buyerName ?? "Tidak tersedia"),
                const SizedBox(height: 8),
                _buildInfoRow(
                    'Penjual', delivery.merchantName ?? "Tidak tersedia"),
                const SizedBox(height: 8),
                _buildInfoRow(
                    'Alamat Penjual',
                    formattedMerchantAddress.isNotEmpty
                        ? formattedMerchantAddress
                        : "Tidak tersedia"),
                const SizedBox(height: 8),
                _buildInfoRow('Telepon Penjual',
                    delivery.merchantPhone ?? "Tidak tersedia"),
                const SizedBox(height: 8),
                _buildInfoRow('Alamat Pengiriman', delivery.shippingAddress),
                const SizedBox(height: 8),
                _buildInfoRow(
                    'Total',
                    NumberFormat.currency(
                      locale: 'id_ID',
                      symbol: 'Rp ',
                    ).format(delivery.totalAmount)),
                if (delivery.status == 'shipping') ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Upload Bukti Pengiriman'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        // Implementasi upload foto bukti pengiriman
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
