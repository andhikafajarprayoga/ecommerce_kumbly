import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/product_controller.dart';
import '../../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../home_screen.dart';
import 'dart:convert';
import '../hotel/hotel_detail_screen.dart';

class StoreDetailScreen extends StatefulWidget {
  final Map<String, dynamic> merchant;

  const StoreDetailScreen({Key? key, required this.merchant}) : super(key: key);

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ProductController productController = Get.find<ProductController>();
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMerchantProducts();
    });
  }

  Future<void> _fetchMerchantProducts() async {
    try {
      productController.isLoading.value = true;

      // Fetch products
      final productsResponse = await supabase
          .from('products')
          .select()
          .eq('seller_id', widget.merchant['id']);

      // Fetch hotels dengan kolom yang sesuai
      final hotelsResponse = await supabase.from('hotels').select('''
            id,
            name,
            description,
            address,
            image_url,
            facilities,
            room_types,
            rating
          ''').eq('merchant_id', widget.merchant['id']);

      print('Hotels response: $hotelsResponse'); // Debug print

      if (productsResponse != null) {
        productController.products.assignAll(productsResponse);
      }

      if (hotelsResponse != null) {
        productController.hotels.assignAll(hotelsResponse);
      }
    } catch (e) {
      print('Error fetching merchant data: $e');
    } finally {
      productController.isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.merchant['store_name']),
        backgroundColor: AppTheme.primary,
      ),
      body: Column(
        children: [
          // Store Info
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  child: Icon(Icons.store, size: 30),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.merchant['store_name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.merchant['store_description'] ??
                            'Tidak ada deskripsi',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // TabBar
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Produk'),
              Tab(text: 'Hotel'),
            ],
          ),

          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Products Tab
                Obx(() {
                  if (productController.isLoading.value) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (productController.products.isEmpty) {
                    return Center(child: Text('Tidak ada produk'));
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: productController.products.length,
                    itemBuilder: (context, index) {
                      return ProductCard(
                          product: productController.products[index]);
                    },
                  );
                }),

                // Hotels Tab
                Obx(() {
                  if (productController.isLoading.value) {
                    return Center(child: CircularProgressIndicator());
                  }

                  if (productController.hotels.isEmpty) {
                    return Center(child: Text('Tidak ada hotel'));
                  }

                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: productController.hotels.length,
                    itemBuilder: (context, index) {
                      final hotel = productController.hotels[index];
                      final imageUrls =
                          List<String>.from(hotel['image_url'] ?? []);
                      String cleanAddress =
                          hotel['address'].toString().replaceAll('"', '');

                      return Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrls.isNotEmpty)
                              Image.network(
                                imageUrls.first,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ListTile(
                              title: Text(hotel['name']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cleanAddress),
                                  if (hotel['rating'] != null)
                                    Row(
                                      children: [
                                        Icon(Icons.star,
                                            size: 16, color: Colors.amber),
                                        Text(' ${hotel['rating']}'),
                                      ],
                                    ),
                                ],
                              ),
                              trailing: Icon(Icons.chevron_right),
                              onTap: () async {
                                try {
                                  // Fetch merchant data terlebih dahulu
                                  final merchantData = await supabase
                                      .from('merchants')
                                      .select('store_address')
                                      .eq('id', widget.merchant['id'])
                                      .single();

                                  // Navigate to hotel detail dengan data lengkap
                                  Get.to(() => HotelDetailScreen(
                                        hotel: {
                                          ...hotel,
                                          'merchants': merchantData
                                        },
                                      ));
                                } catch (e) {
                                  print('Error fetching merchant data: $e');
                                  Get.snackbar(
                                    'Error',
                                    'Gagal memuat data hotel',
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
