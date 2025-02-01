import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart'; // Pastikan untuk mengimpor OrderController

class PesananSayaScreen extends StatelessWidget {
  PesananSayaScreen({super.key});

  final OrderController orderController = Get.put(OrderController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
      ),
      body: Obx(() {
        if (orderController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orderController.orders.isEmpty) {
          return const Center(child: Text('Tidak ada pesanan'));
        }

        return ListView.builder(
          itemCount: orderController.orders.length,
          itemBuilder: (context, index) {
            final order = orderController.orders[index];
            return OrderCard(order: order);
          },
        );
      }),
    );
  }
}

class OrderCard extends StatelessWidget {
  final dynamic order;

  const OrderCard({
    super.key,
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order ID: ${order.id}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Tanggal: ${order.date}'),
            const SizedBox(height: 8),
            Text('Total: Rp ${order.total.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            Text('Status: ${order.status}'),
          ],
        ),
      ),
    );
  }
}
