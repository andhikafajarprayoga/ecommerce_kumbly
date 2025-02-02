import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/cart_controller.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:kumbly_ecommerce/pages/buyer/checkout/checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartController cartController = Get.put(CartController());
  final OrderController orderController = Get.put(OrderController());

  @override
  void initState() {
    super.initState();
    cartController.fetchCartItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keranjang Belanja'),
      ),
      body: Obx(() {
        if (cartController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (cartController.cartItems.isEmpty) {
          return const Center(child: Text('Keranjang kosong'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cartController.cartItems.length,
          itemBuilder: (context, index) {
            final item = cartController.cartItems[index];
            return CartItemCard(
              item: item,
              onUpdate: (quantity) {
                int newQuantity = int.tryParse(quantity.toString()) ?? 0;
                cartController.updateQuantity(item['id'], newQuantity);
              },
              onRemove: () {
                cartController.removeFromCart(item['id']);
              },
            );
          },
        );
      }),
      bottomNavigationBar: Obx(() {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total:'),
                    Text(
                      'Rp ${cartController.totalPrice}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  // Misalnya, Anda bisa mendapatkan courierId dan shippingAddress dari input pengguna
                  String courierId =
                      'your_courier_id'; // Ganti dengan nilai yang sesuai
                  String userId = cartController.supabase.auth.currentUser!.id;
                  String shippingAddress =
                      await orderController.fetchUserAddress(userId);

                  final checkoutData = cartController.prepareCheckoutData(
                      courierId, shippingAddress);
                  Get.to(() => CheckoutScreen(
                      data: checkoutData)); // Navigasi ke CheckoutScreen
                },
                child: const Text('Checkout'),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class CartItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final Function(String) onUpdate;
  final Function() onRemove;

  const CartItemCard({
    super.key,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(item['products']['image_url']),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['products']['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Rp ${item['products']['price']}'),
                  // Gunakan GetBuilder untuk mengontrol rebuild hanya pada bagian quantity
                  GetBuilder<CartController>(
                    builder: (controller) {
                      final currentItem = controller.cartItems.firstWhere(
                        (element) => element['id'] == item['id'],
                        orElse: () => item,
                      );

                      return Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              int newQuantity = currentItem['quantity'] - 1;
                              if (newQuantity > 0) {
                                onUpdate(newQuantity.toString());
                              }
                            },
                          ),
                          Text('${currentItem['quantity']}'),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              int newQuantity = currentItem['quantity'] + 1;
                              onUpdate(newQuantity.toString());
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
