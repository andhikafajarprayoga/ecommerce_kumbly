import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';

class PesananSayaScreen extends StatefulWidget {
  const PesananSayaScreen({super.key});

  @override
  State<PesananSayaScreen> createState() => _PesananSayaScreenState();
}

class _PesananSayaScreenState extends State<PesananSayaScreen> {
  final OrderController orderController =
      Get.put(OrderController()); // Inisialisasi OrderController

  @override
  void initState() {
    super.initState();
    orderController.fetchOrders(); // Panggil fetchOrders saat layar dimulai
  }

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
          return const Center(child: Text('Tidak ada pesanan tersedia'));
        }

        return ListView.builder(
          itemCount: orderController.orders.length,
          itemBuilder: (context, index) {
            final order = orderController.orders[index];
            return Card(
              margin:
                  const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order ID: ${order['id']}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Tanggal: ${order['created_at']}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Total: Rp ${order['total_amount']}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Status: ${order['status']}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('Alamat Pengiriman: ${order['shipping_address']}',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
