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

        final processingOrders = controller.processingDeliveries;

        if (processingOrders.isEmpty) {
          return const Center(
            child: Text('Tidak ada paket yang perlu dijemput'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: processingOrders.length,
          itemBuilder: (context, index) {
            final order = processingOrders[index];

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
              margin: const EdgeInsets.only(bottom: 16),
              child: ListTile(
                title: Text(
                  'Order #${order.id.substring(0, 8)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Penjual: ${order.merchantName ?? "Tidak tersedia"}'),
                    Text(
                        'Alamat Penjual: ${formattedMerchantAddress.isNotEmpty ? formattedMerchantAddress : "Tidak tersedia"}'),
                    Text('Telepon: ${order.merchantPhone ?? "Tidak tersedia"}'),
                    Text(
                        'Total: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(order.totalAmount)}'),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () async {
                    await controller.assignCourier(order.id);
                  },
                  child: const Text('Terima'),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
