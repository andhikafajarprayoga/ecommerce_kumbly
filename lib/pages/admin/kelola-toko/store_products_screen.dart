import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kumbly_ecommerce/pages/admin/kelola-toko/edit_product_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import 'package:get/get.dart';

class StoreProductsScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  StoreProductsScreen({required this.store});

  @override
  State<StoreProductsScreen> createState() => _StoreProductsScreenState();
}

class _StoreProductsScreenState extends State<StoreProductsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> products = [];
  bool isLoading = true;
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      final response = await supabase
          .from('products')
          .select()
          .eq('seller_id', widget.store['id'])
          .order('created_at', ascending: false);

      setState(() {
        products = (response as List<dynamic>).cast<Map<String, dynamic>>();
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching products: $e');
      setState(() => isLoading = false);
    }
  }

  void searchProducts(String query) async {
    try {
      final response = await supabase
          .from('products')
          .select()
          .eq('seller_id', widget.store['id'])
          .ilike('name', '%$query%')
          .order('created_at', ascending: false);

      setState(() {
        products = (response as List<dynamic>).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      print('Error searching products: $e');
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      await supabase.from('products').delete().eq('id', id);
      Get.snackbar(
        'Sukses',
        'Produk berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      fetchProducts();
    } catch (e) {
      print('Error deleting product: $e');
      Get.snackbar(
        'Error',
        'Gagal menghapus produk',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Produk ${widget.store['store_name']}',
          style: TextStyle(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppTheme.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  isDense: true, // Mengurangi padding internal
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  hintText: 'Cari produk...',
                  prefixIcon: Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
                          onPressed: () {
                            searchController.clear();
                            fetchProducts();
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  if (value.isEmpty) {
                    fetchProducts();
                  } else {
                    searchProducts(value);
                  }
                },
              ),
            ),

            // Product Grid
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'Tidak ada produk',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: EdgeInsets.all(16),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.7, // Sesuaikan rasio
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return InkWell(
                              onTap: () => _showProductActions(product),
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 1,
                                      child: product['image_url'] != null
                                          ? Image.network(
                                              product['image_url'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error,
                                                      stackTrace) =>
                                                  Container(
                                                color: Colors.grey[200],
                                                child: Icon(Icons.error_outline,
                                                    color: Colors.grey[400],
                                                    size: 24),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.grey[200],
                                              child: Icon(
                                                  Icons
                                                      .image_not_supported_outlined,
                                                  color: Colors.grey[400],
                                                  size: 24),
                                            ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              product['name'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              currencyFormatter
                                                  .format(product['price']),
                                              style: TextStyle(
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Spacer(),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  'Stok: ${product['stock']}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                Text(
                                                  'Terjual: ${product['sales']}',
                                                  style: TextStyle(
                                                    color: Colors.grey[600],
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductActions(Map<String, dynamic> product) {
    Get.bottomSheet(
      Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.edit, color: Colors.blue),
              title: Text('Edit Produk'),
              onTap: () async {
                Get.back();
                final result =
                    await Get.to(() => EditProductScreen(product: product));
                if (result == true) {
                  fetchProducts();
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red),
              title: Text('Hapus Produk'),
              onTap: () {
                Get.back();
                Get.dialog(
                  AlertDialog(
                    title: Text('Konfirmasi'),
                    content: Text('Yakin ingin menghapus produk ini?'),
                    actions: [
                      TextButton(
                        child: Text('Batal'),
                        onPressed: () => Get.back(),
                      ),
                      TextButton(
                        child:
                            Text('Hapus', style: TextStyle(color: Colors.red)),
                        onPressed: () {
                          Get.back();
                          deleteProduct(product['id']);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
