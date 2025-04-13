import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/product_controller.dart';
import 'add_product_screen.dart';
import 'edit_product_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import 'dart:async';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final ProductController productController = Get.put(ProductController());
  final supabase = Supabase.instance.client;
  StreamSubscription? _productsSubscription;

  @override
  void initState() {
    super.initState();
    _setupProductsStream();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }

  void _setupProductsStream() {
    // Initial fetch
    productController.fetchProducts();

    final userId = supabase.auth.currentUser!.id;

    // Listen to changes
    _productsSubscription = supabase
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('seller_id', userId)
        .order('created_at', ascending: false)
        .listen(
          (data) {
            print('DEBUG: Products stream update received');
            print('DEBUG: Number of products: ${data.length}');

            // Update products di controller
            productController
                .updateProducts(List<Map<String, dynamic>>.from(data));
          },
          onError: (error) {
            print('ERROR: Products stream error: $error');
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: AppTheme.primary,
        title: const Text(
          'Daftar Produk',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.normal,
          ),
        ),
      ),
      body: Obx(() {
        if (productController.isLoading.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
                SizedBox(height: 16),
                Text(
                  'Memuat Produk...',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: AppTheme.primary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  ),
                ),
              ],
            ),
          );
        }

        final myProducts = productController.products
            .where((product) =>
                product['seller_id'] == supabase.auth.currentUser!.id)
            .toList();

        if (myProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada produk',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tambahkan produk pertama Anda',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Get.to(() => AddProductScreen()),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Tambah Produk',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.75,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: myProducts.length,
                itemBuilder: (context, index) {
                  final product = myProducts[index];
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Image
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                              image: DecorationImage(
                                image: NetworkImage(
                                  _getProductImage(product['image_url']),
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // Product Info
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['name'] ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                NumberFormat.currency(
                                  locale: 'id',
                                  symbol: 'Rp ',
                                  decimalDigits: 0,
                                ).format(product['price'] ?? 0),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () => Get.to(() =>
                                          EditProductScreen(product: product)),
                                      child: const Text('Edit'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppTheme.primary,
                                        padding: EdgeInsets.zero,
                                        side:
                                            BorderSide(color: AppTheme.primary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    color: Colors.red,
                                    onPressed: () =>
                                        _showDeleteConfirmation(product),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => Get.to(() => AddProductScreen()),
                icon: Icon(Icons.add, color: Colors.white),
                label: Text(
                  'Tambah Produk',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> product) {
    Get.dialog(
      AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin menghapus produk ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                final productId =
                    product['id'].toString(); // Ambil ID sebagai String
                await productController.deleteProduct(productId);
                Get.snackbar(
                  'Sukses',
                  'Produk berhasil dihapus',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                print('Error deleting product: $e');
                Get.snackbar(
                  'Error',
                  'Gagal menghapus produk',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _getProductImage(dynamic imageUrl) {
    if (imageUrl == null) return 'https://via.placeholder.com/150';

    try {
      if (imageUrl is String) {
        // Jika imageUrl string JSON, parse menjadi List
        List<dynamic> images = jsonDecode(imageUrl);
        return images.isNotEmpty
            ? images[0]
            : 'https://via.placeholder.com/150';
      } else if (imageUrl is List) {
        // Jika imageUrl sudah berbentuk List
        return imageUrl.isNotEmpty
            ? imageUrl[0]
            : 'https://via.placeholder.com/150';
      }
    } catch (e) {
      print('Error parsing image URL: $e');
    }

    return 'https://via.placeholder.com/150';
  }
}
