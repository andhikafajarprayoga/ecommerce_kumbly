import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/cart_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../cart/cart_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../checkout/checkout_screen.dart';
import '../checkout/edit_address_screen.dart';
import 'dart:convert';

class ProductDetailScreen extends StatelessWidget {
  final dynamic product;
  ProductDetailScreen({super.key, required this.product}) {
    Get.put(CartController());
  }
  final CartController cartController = Get.put(CartController());
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title:
            const Text('Detail Produk', style: TextStyle(color: Colors.white)),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () => Get.to(() => CartScreen()),
              ),
              Obx(() => cartController.cartItems.isNotEmpty
                  ? Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${cartController.cartItems.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : SizedBox()),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar Produk
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(product['image_url']),
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // Informasi Produk
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama dan Harga
                  Text(
                    product['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rp ${NumberFormat('#,###').format(product['price'])}',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'Terjual ${product['sales'] ?? 0}',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stok
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined,
                            color: AppTheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Stok: ${product['stock']}',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Deskripsi
                  Text(
                    'Deskripsi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['description'] ?? 'Tidak ada deskripsi',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Informasi Toko
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Penjual',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FutureBuilder(
                          future: supabase
                              .from('merchants')
                              .select('store_name, store_address')
                              .eq('id', product['seller_id'])
                              .single(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final merchant = snapshot.data as Map;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.store,
                                          color: AppTheme.primary),
                                      SizedBox(width: 8),
                                      Text(
                                        merchant['store_name'] ?? 'Nama Toko',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          color: AppTheme.primary),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Builder(
                                          builder: (context) {
                                            try {
                                              final addressData = jsonDecode(
                                                  merchant['store_address'] ??
                                                      '{}');
                                              return Text(
                                                '${addressData['street']}, ${addressData['village']}, ${addressData['district']}, ${addressData['city']}, ${addressData['province']} ${addressData['postal_code']}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            } catch (e) {
                                              return Text(
                                                'Alamat tidak valid',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }
                            return CircularProgressIndicator();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Produk Referensi
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Produk Referensi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchRelatedProducts(product['category']),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Tidak ada produk referensi'));
                }

                final relatedProducts = snapshot.data!;
                return SizedBox(
                  height: 220,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: relatedProducts.length,
                    itemBuilder: (context, index) {
                      final relatedProduct = relatedProducts[index];
                      if (relatedProduct['id'] == product['id']) {
                        return SizedBox.shrink(); // Skip produk yang sama
                      }
                      return GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetailScreen(
                                product: relatedProduct,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 160,
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          child: Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Gambar Produk
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(
                                          relatedProduct['image_url']),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                // Info Produk
                                Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        relatedProduct['name'],
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Rp ${NumberFormat('#,###').format(relatedProduct['price'])}',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.shopping_bag_outlined,
                                              size: 12, color: Colors.grey),
                                          SizedBox(width: 4),
                                          Text(
                                            'Terjual ${relatedProduct['sales'] ?? 0}',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey),
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
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tombol Chat
            Container(
              width: 35,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.chat_bubble_outline, size: 28),
                onPressed: _startChat,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            // Tombol Keranjang
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () {
                    cartController.addToCart(product);
                    Get.snackbar(
                      'Sukses',
                      'Produk ditambahkan ke keranjang',
                      snackPosition: SnackPosition.TOP,
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                      duration: Duration(seconds: 2),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text('Keranjang', style: TextStyle(fontSize: 11)),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Tombol Beli Langsung
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: handleCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text('Beli Langsung', style: TextStyle(fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRelatedProducts(
      String? category) async {
    if (category == null) return [];

    final response = await supabase
        .from('products')
        .select()
        .eq('category', category) // Filter berdasarkan kolom category
        .neq('id', product['id']) // Kecuali produk saat ini
        .order('sales', ascending: false) // Urutkan berdasarkan penjualan
        .limit(5);

    return response;
  }

  Future<void> _startChat() async {
    final buyerId = supabase.auth.currentUser?.id;
    if (buyerId == null) {
      Get.snackbar('Error', 'Silakan login terlebih dahulu');
      return;
    }

    // Cek apakah chat room sudah ada
    final existingRoom = await supabase
        .from('chat_rooms')
        .select()
        .eq('buyer_id', buyerId)
        .eq('seller_id', product['seller_id'])
        .maybeSingle();

    Map<String, dynamic> chatRoom;
    Map<String, dynamic> seller;

    if (existingRoom != null) {
      chatRoom = existingRoom;
    } else {
      // Buat chat room baru
      final response = await supabase
          .from('chat_rooms')
          .insert({
            'buyer_id': buyerId,
            'seller_id': product['seller_id'],
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      chatRoom = response;
    }

    // Dapatkan info seller
    seller = await supabase
        .from('merchants')
        .select()
        .eq('id', product['seller_id'])
        .single();

    // Navigasi ke chat detail
    Get.to(() => ChatDetailScreen(
          chatRoom: chatRoom,
          seller: seller,
        ));
  }

  void handleCheckout() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      Get.snackbar('Error', 'Silakan login terlebih dahulu');
      return;
    }

    try {
      final userResponse = await supabase
          .from('users')
          .select('address')
          .eq('id', userId)
          .single();

      String? address = userResponse['address'];

      if (address == null || address.isEmpty) {
        final newAddress = await Get.to(() => EditAddressScreen(
              initialAddress: '',
              onSave: (address) {},
            ));

        if (newAddress == null) return;
        address = newAddress;
      }

      // Data untuk checkout tanpa seller_id
      Get.to(() => CheckoutScreen(
            data: {
              'items': [
                {
                  'products': product, // Data produk lengkap
                  'quantity': 1,
                }
              ],
              'total_amount': product['price'] * 1,
              'shipping_address': address,
              'buyer_id': userId,
              'status': 'pending',
            },
          ));
    } catch (e) {
      print('Error getting address: $e');
      Get.snackbar(
        'Error',
        'Gagal mengambil data alamat. Silakan coba lagi.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

String formatTimestamp(DateTime timestamp) {
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss',
      'id_ID'); // Format waktu dengan zona waktu Indonesia
  return dateFormat.format(timestamp);
}
