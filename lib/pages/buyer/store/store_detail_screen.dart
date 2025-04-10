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
  final TextEditingController searchController = TextEditingController();
  var searchQuery = ''.obs;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

  void _performSearch(String value) async {
    if (value.isEmpty) {
      // Jika pencarian kosong, tampilkan semua produk
      _fetchMerchantProducts();
      return;
    }

    try {
      productController.isLoading.value = true;

      // Fetch products dengan filter pencarian
      final productsResponse = await supabase
          .from('products')
          .select()
          .eq('seller_id', widget.merchant['id'])
          .or('name.ilike.%${value}%,description.ilike.%${value}%,category.ilike.%${value}%');

      if (productsResponse != null) {
        productController.products.assignAll(productsResponse);
      }
    } catch (e) {
      print('Error searching products: $e');
    } finally {
      productController.isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.merchant['store_name'],
            style: TextStyle(color: Colors.white)),
        foregroundColor: Colors.white,
        backgroundColor: AppTheme.primary,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: searchController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                hintText: 'Cari produk di toko ini...',
                hintStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(Icons.search, color: Colors.white),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.white),
                        onPressed: () {
                          searchController.clear();
                          _fetchMerchantProducts();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (value) {
                searchQuery.value = value;
                _performSearch(value);
              },
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Store Info
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Icon(Icons.store, size: 30, color: AppTheme.primary),
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
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // TabBar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primary,
              indicatorWeight: 3,
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(text: 'Produk'),
                Tab(text: 'Makanan'),
                Tab(text: 'Hotel'),
              ],
            ),
          ),

          // TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Products Tab
                Obx(() {
                  if (productController.isLoading.value) {
                    return Center(
                        child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ));
                  }

                  final foodCategories = [
                    'Makanan Instan',
                    'Minuman Kemasan',
                    'Makanan Camilan & Snack',
                    'Bahan Makanan',
                    'Makanan Hotel',
                  ];

                  final nonFoodProducts = productController.products
                      .where((product) =>
                          !foodCategories.contains(product['category']))
                      .toList();

                  if (nonFoodProducts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              size: 50, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'Tidak ada produk',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: nonFoodProducts.length,
                    itemBuilder: (context, index) {
                      return ProductCard(product: nonFoodProducts[index]);
                    },
                  );
                }),

                // Food Tab
                Obx(() {
                  if (productController.isLoading.value) {
                    return Center(
                        child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ));
                  }

                  final foodCategories = [
                    'Makanan Instan',
                    'Minuman Kemasan',
                    'Makanan Camilan & Snack',
                    'Bahan Makanan',
                    'Makanan Hotel',
                  ];

                  final foodProducts = productController.products
                      .where((product) =>
                          foodCategories.contains(product['category']))
                      .toList();

                  if (foodProducts.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fastfood_outlined,
                              size: 50, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'Tidak ada produk makanan',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: foodProducts.length,
                    itemBuilder: (context, index) {
                      return ProductCard(product: foodProducts[index]);
                    },
                  );
                }),

                // Hotels Tab
                Obx(() {
                  if (productController.isLoading.value) {
                    return Center(
                        child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppTheme.primary),
                    ));
                  }

                  if (productController.hotels.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hotel_outlined,
                              size: 50, color: Colors.grey[400]),
                          SizedBox(height: 16),
                          Text(
                            'Tidak ada hotel',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: productController.hotels.length,
                    itemBuilder: (context, index) {
                      final hotel = productController.hotels[index];
                      final imageUrls =
                          List<String>.from(hotel['image_url'] ?? []);
                      String cleanAddress = hotel['address']
                          .toString()
                          .replaceAll('"', '')
                          .replaceAll('{', '')
                          .replaceAll('}', '');

                      List<String> addressParts = cleanAddress.split(',');
                      List<String> formattedParts = [];

                      for (String part in addressParts) {
                        var keyValue = part.trim().split(':');
                        if (keyValue.length == 2) {
                          var key = keyValue[0].trim();
                          var value = keyValue[1].trim();

                          switch (key) {
                            case 'street':
                              if (value.isNotEmpty) formattedParts.add(value);
                              break;
                            case 'district':
                              if (value.isNotEmpty)
                                formattedParts.add('Kecamatan $value');
                              break;
                            case 'city':
                              if (value.isNotEmpty) formattedParts.add(value);
                              break;
                            case 'province':
                              if (value.isNotEmpty) formattedParts.add(value);
                              break;
                            case 'postal_code':
                              if (value.isNotEmpty) formattedParts.add(value);
                              break;
                          }
                        }
                      }

                      String formattedAddress = formattedParts.join(', ');

                      return Card(
                        margin: EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (imageUrls.isNotEmpty)
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                    child: Image.network(
                                      imageUrls.first,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (hotel['rating'] != null)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.star,
                                                size: 16, color: Colors.amber),
                                            SizedBox(width: 4),
                                            Text(
                                              '${hotel['rating']}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hotel['name'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.location_on_outlined,
                                          size: 16, color: Colors.grey[600]),
                                      SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          formattedAddress,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                try {
                                  final merchantData = await supabase
                                      .from('merchants')
                                      .select('store_address')
                                      .eq('id', widget.merchant['id'])
                                      .single();

                                  String storeAddress =
                                      merchantData['store_address']
                                          .toString()
                                          .replaceAll('"', '')
                                          .replaceAll('{', '')
                                          .replaceAll('}', '');

                                  Get.to(() => HotelDetailScreen(
                                        hotel: {
                                          ...hotel,
                                          'merchants': {
                                            ...merchantData,
                                            'store_address': storeAddress
                                          }
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
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey[200]!),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Lihat Detail',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
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
}
