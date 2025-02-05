import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/cart_controller.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:kumbly_ecommerce/pages/buyer/checkout/checkout_screen.dart';
import 'package:intl/intl.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartController cartController = Get.put(CartController());
  final OrderController orderController = Get.put(OrderController());
  final Map<String, bool> selectedItems = {};

  @override
  void initState() {
    super.initState();
    cartController.fetchCartItems();
  }

  double calculateSelectedTotal() {
    double total = 0;
    for (var item in cartController.cartItems) {
      if (selectedItems[item['id'].toString()] == true) {
        total += (item['products']['price'] * item['quantity']);
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Keranjang Saya', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
      ),
      body: Obx(() {
        if (cartController.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (cartController.cartItems.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shopping_cart_outlined,
                    size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Keranjang kosong', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        // Kelompokkan items berdasarkan merchant
        Map<String, List<dynamic>> groupedItems = {};
        for (var item in cartController.cartItems) {
          String sellerId = item['products']['seller_id'].toString();

          if (!groupedItems.containsKey(sellerId)) {
            groupedItems[sellerId] = [];
          }
          groupedItems[sellerId]!.add(item);
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: groupedItems.length,
                itemBuilder: (context, index) {
                  String sellerId = groupedItems.keys.elementAt(index);
                  List<dynamic> merchantItems = groupedItems[sellerId]!;

                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Merchant Header with Select All
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Checkbox(
                                value: merchantItems.every((item) =>
                                    selectedItems[item['id']] == true),
                                onChanged: (bool? value) {
                                  setState(() {
                                    for (var item in merchantItems) {
                                      selectedItems[item['id']] =
                                          value ?? false;
                                    }
                                  });
                                },
                                activeColor: AppTheme.primary,
                              ),
                              Icon(Icons.store, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  merchantItems.first['products']['merchant']
                                          ['store_name'] ??
                                      'Toko',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    bool currentValue = merchantItems.every(
                                        (item) =>
                                            selectedItems[item['id']] == true);
                                    for (var item in merchantItems) {
                                      selectedItems[item['id']] = !currentValue;
                                    }
                                  });
                                },
                                child: Text(
                                  merchantItems.every((item) =>
                                          selectedItems[item['id']] == true)
                                      ? 'Batal Pilih Semua'
                                      : 'Pilih Semua',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1),

                        // Merchant Items
                        ...merchantItems
                            .map((item) => CartItemWidget(
                                  item: item,
                                  isSelected:
                                      selectedItems[item['id']] ?? false,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      selectedItems[item['id']] =
                                          value ?? false;
                                    });
                                  },
                                  onUpdateQuantity:
                                      cartController.updateQuantity,
                                  onRemove: cartController.removeFromCart,
                                ))
                            .toList(),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total Pembayaran:'),
                      Text(
                        'Rp ${NumberFormat('#,###').format(calculateSelectedTotal())}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: selectedItems.containsValue(true)
                        ? () async {
                            List<Map<String, dynamic>> selectedProducts = [];
                            for (var item in cartController.cartItems) {
                              if (selectedItems[item['id'].toString()] ==
                                  true) {
                                selectedProducts.add({
                                  'id': item['id'],
                                  'product_id': item['product_id'],
                                  'quantity': item['quantity'],
                                  'products': item['products'],
                                });
                              }
                            }

                            String userId =
                                cartController.supabase.auth.currentUser!.id;
                            String shippingAddress =
                                await orderController.fetchUserAddress(userId);

                            final checkoutData = {
                              'buyer_id': userId,
                              'courier_id': 'default_courier',
                              'shipping_address': shippingAddress,
                              'total_amount': calculateSelectedTotal(),
                              'items': selectedProducts,
                            };

                            Get.to(() => CheckoutScreen(data: checkoutData));
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding:
                          EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      'Checkout (${selectedItems.values.where((v) => v).length})',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }
}

// Buat widget terpisah untuk item cart
class CartItemWidget extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool isSelected;
  final Function(bool?) onChanged;
  final Function(String, int) onUpdateQuantity;
  final Function(String) onRemove;

  const CartItemWidget({
    required this.item,
    required this.isSelected,
    required this.onChanged,
    required this.onUpdateQuantity,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(12),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            onChanged: onChanged,
            activeColor: AppTheme.primary,
          ),
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
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['products']['name'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Rp ${NumberFormat('#,###').format(item['products']['price'])}',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.remove, size: 16),
                            onPressed: () {
                              int newQuantity = item['quantity'] - 1;
                              if (newQuantity > 0) {
                                onUpdateQuantity(item['id'], newQuantity);
                              }
                            },
                            constraints: BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                          Text('${item['quantity']}'),
                          IconButton(
                            icon: Icon(Icons.add, size: 16),
                            onPressed: () {
                              onUpdateQuantity(
                                  item['id'], item['quantity'] + 1);
                            },
                            constraints: BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                      onPressed: () => onRemove(item['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
