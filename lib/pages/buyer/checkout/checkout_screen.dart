import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  CheckoutScreen({required this.data}); // Menerima data dari CartScreen

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String paymentMethod = 'COD'; // Default payment method

  @override
  Widget build(BuildContext context) {
    final OrderController orderController = Get.put(OrderController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: Obx(() {
        if (orderController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // Tampilkan alamat pengiriman
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ringkasan Pesanan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                  'Alamat Pengiriman: ${widget.data['shipping_address']}'), // Tampilkan alamat
              const SizedBox(height: 16),
              const Text(
                'Metode Pembayaran:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      title: const Text('COD'),
                      leading: Radio<String>(
                        value: 'COD',
                        groupValue: paymentMethod,
                        onChanged: (value) {
                          setState(() {
                            paymentMethod = value!; // Update payment method
                          });
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      title: const Text('Transfer'),
                      leading: Radio<String>(
                        value: 'Transfer',
                        groupValue: paymentMethod,
                        onChanged: (value) {
                          setState(() {
                            paymentMethod = value!; // Update payment method
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Daftar Produk:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.data['items'].length,
                  itemBuilder: (context, index) {
                    final item = widget.data['items'][index];
                    return ListTile(
                      title:
                          Text(item['product_id']), // Ganti dengan nama produk
                      subtitle: Text(
                          'Jumlah: ${item['quantity']} - Rp ${item['price']}'), // Pastikan harga ada di data
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Total: Rp ${widget.data['total_amount']}',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  // Panggil fungsi untuk menyimpan pesanan
                  await orderController.createOrder({
                    ...widget.data,
                    'payment_method':
                        paymentMethod, // Tambahkan metode pembayaran
                  });
                  Get.back(); // Kembali ke halaman sebelumnya setelah checkout
                },
                child: const Text('Konfirmasi Pesanan'),
              ),
            ],
          ),
        );
      }),
    );
  }
}
