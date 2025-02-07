import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/product_controller.dart';
import '../../../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import '../product/product_detail_screen.dart';
import 'package:intl/intl.dart';
import '../store/store_detail_screen.dart';

class FindScreen extends StatefulWidget {
  @override
  State<FindScreen> createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  final ProductController productController = Get.find<ProductController>();
  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();
  final minPriceController = TextEditingController(text: '0');
  final maxPriceController = TextEditingController(text: '0');
  final formatter = NumberFormat('#,###');
  final isSearching = false.obs;

  @override
  void initState() {
    super.initState();

    print('Debug: FindScreen initState');
    searchController.text = productController.searchQuery.value;
    productController.products.clear();

    final query = Get.arguments as String?;

    if (query != null && query.isNotEmpty) {
      print('Debug: Memulai pencarian dengan query: $query');
      searchController.text = query;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await performSearch(query);
      });
    }
  }

  void _showSortOptions() {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Urutkan Berdasarkan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Divider(height: 1),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.trending_up, color: AppTheme.primary),
              ),
              title: Text('Terlaris'),
              onTap: () {
                productController.sortBySales();
                Get.back();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_upward, color: AppTheme.primary),
              ),
              title: Text('Harga Terendah'),
              onTap: () {
                productController.sortByPriceAsc();
                Get.back();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.arrow_downward, color: AppTheme.primary),
              ),
              title: Text('Harga Tertinggi'),
              onTap: () {
                productController.sortByPriceDesc();
                Get.back();
              },
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.location_on, color: AppTheme.primary),
              ),
              title: Text('Terdekat'),
              onTap: () {
                _sortByDistance();
                Get.back();
              },
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              Divider(),
              Text(
                'Rentang Harga',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        labelText: 'Harga Minimum',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          try {
                            String numericValue =
                                value.replaceAll(RegExp(r'[^0-9]'), '');
                            if (numericValue.isEmpty) numericValue = '0';
                            String formattedValue =
                                formatter.format(int.parse(numericValue));
                            minPriceController.value = TextEditingValue(
                              text: formattedValue,
                              selection: TextSelection.collapsed(
                                  offset: formattedValue.length),
                            );
                          } catch (e) {
                            print('Error formatting price: $e');
                          }
                        }
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rp ',
                        labelText: 'Harga Maksimum',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          try {
                            String numericValue =
                                value.replaceAll(RegExp(r'[^0-9]'), '');
                            if (numericValue.isEmpty) numericValue = '0';
                            String formattedValue =
                                formatter.format(int.parse(numericValue));
                            maxPriceController.value = TextEditingValue(
                              text: formattedValue,
                              selection: TextSelection.collapsed(
                                  offset: formattedValue.length),
                            );
                          } catch (e) {
                            print('Error formatting price: $e');
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              Divider(),
              Text(
                'Urutkan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.trending_up, color: AppTheme.primary),
                ),
                title: Text('Terlaris'),
                onTap: () {
                  productController.sortBySales();
                  Get.back();
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_upward, color: AppTheme.primary),
                ),
                title: Text('Harga Terendah'),
                onTap: () {
                  productController.sortByPriceAsc();
                  Get.back();
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.arrow_downward, color: AppTheme.primary),
                ),
                title: Text('Harga Tertinggi'),
                onTap: () {
                  productController.sortByPriceDesc();
                  Get.back();
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.location_on, color: AppTheme.primary),
                ),
                title: Text('Terdekat dengan alamat pengiriman'),
                onTap: () {
                  _sortByDistance();
                  Get.back();
                },
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    try {
                      // Konversi string ke integer dengan menghapus format ribuan
                      int minPrice = int.parse(minPriceController.text
                          .replaceAll(RegExp(r'[^0-9]'), ''));
                      int maxPrice = int.parse(maxPriceController.text
                          .replaceAll(RegExp(r'[^0-9]'), ''));

                      if (minPrice > maxPrice && maxPrice != 0) {
                        Get.snackbar(
                          'Error',
                          'Harga minimum tidak boleh lebih besar dari harga maksimum',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                        );
                        return;
                      }

                      productController.filterByPriceRange(minPrice, maxPrice);
                      Get.back();
                    } catch (e) {
                      print('Error applying price filter: $e');
                      Get.snackbar(
                        'Error',
                        'Format harga tidak valid',
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Terapkan Filter',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  Future<void> _sortByDistance() async {
    try {
      // Get current user's address
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userResponse = await supabase
          .from('users')
          .select('address')
          .eq('id', userId)
          .single();

      final userAddress = userResponse['address'];
      if (userAddress == null) {
        Get.snackbar(
          'Error',
          'Harap atur alamat pengiriman Anda terlebih dahulu',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Convert user address to coordinates
      final userAddressStr = '${userAddress['street']}, '
          '${userAddress['village']}, '
          '${userAddress['district']}, '
          '${userAddress['city']}, '
          '${userAddress['province']} '
          '${userAddress['postal_code']}';

      final userLocation = await _getCoordinatesFromAddress(userAddressStr);
      if (userLocation == null) {
        Get.snackbar(
          'Error',
          'Gagal mendapatkan koordinat alamat Anda',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Get all products with merchant locations
      final products =
          List<Map<String, dynamic>>.from(productController.products);

      // Get merchant locations
      for (var product in products) {
        final merchant = await supabase
            .from('merchants')
            .select('store_address')
            .eq('id', product['seller_id'])
            .single();

        try {
          final storeAddress = merchant['store_address'];
          if (storeAddress != null) {
            // Parse JSON string ke Map
            final merchantAddress = jsonDecode(storeAddress);

            final addressStr = '${merchantAddress['street']}, '
                '${merchantAddress['village']}, '
                '${merchantAddress['district']}, '
                '${merchantAddress['city']}, '
                '${merchantAddress['province']} '
                '${merchantAddress['postal_code']}';

            product['merchant_location'] =
                await _getCoordinatesFromAddress(addressStr);
          }
        } catch (e) {
          print('Error parsing address: $e');
          product['merchant_location'] = null;
        }
      }

      // Sort products by distance from user's address
      products.sort((a, b) {
        if (a['merchant_location'] == null) return 1;
        if (b['merchant_location'] == null) return -1;

        double distanceA = _calculateDistance(
          a['merchant_location']['lat']?.toDouble() ?? 0.0,
          a['merchant_location']['lng']?.toDouble() ?? 0.0,
          userLocation['lat']?.toDouble() ?? 0.0,
          userLocation['lng']?.toDouble() ?? 0.0,
        );

        double distanceB = _calculateDistance(
          b['merchant_location']['lat']?.toDouble() ?? 0.0,
          b['merchant_location']['lng']?.toDouble() ?? 0.0,
          userLocation['lat']?.toDouble() ?? 0.0,
          userLocation['lng']?.toDouble() ?? 0.0,
        );

        return distanceA.compareTo(distanceB);
      });

      // Update products list
      productController.products.value = products;
    } catch (e) {
      print('Error sorting by distance: $e');
      Get.snackbar(
        'Error',
        'Gagal mengurutkan berdasarkan jarak',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<Map<String, double>?> _getCoordinatesFromAddress(
      String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        return {
          'lat': locations.first.latitude,
          'lng': locations.first.longitude,
        };
      }
    } catch (e) {
      print('Error getting coordinates: $e');
    }
    return null;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    var p = 0.017453292519943295; // Math.PI / 180
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  Future<void> _fetchMerchantProducts(String merchantId) async {
    try {
      print('Fetching products for merchant ID: $merchantId'); // Debug print
      productController.isLoading.value = true; // Set loading state

      final response =
          await Supabase.instance.client.from('products').select('''
            id,
            name,
            description,
            price,
            stock,
            category,
            image_url,
            sales,
            seller_id
          ''').eq('seller_id', merchantId);

      print('Raw merchant products response: $response'); // Debug print

      if (response != null && response is List) {
        print('Number of products found: ${response.length}'); // Debug print
        productController.products.assignAll(response);
      } else {
        print('No products found or invalid response format'); // Debug print
        productController.products
            .clear(); // Clear existing products if none found
      }
    } catch (e) {
      print('Error fetching merchant products: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat produk dari toko ini',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      productController.isLoading.value = false; // Reset loading state
    }
  }

  Future<void> performSearch(String value) async {
    if (value.isEmpty) return;

    try {
      isSearching.value = true; // Set searching state
      print('Debug: Membersihkan data lama');
      productController.products.clear();
      productController.searchedMerchants.clear();

      print('Debug: Mencari produk');
      await productController.searchProducts(value);

      print('Debug: Mencari toko');
      final merchantResponse = await supabase
          .from('merchants')
          .select('id, store_name, store_description')
          .or('store_name.ilike.%${value}%,store_description.ilike.%${value}%')
          .limit(5);

      print(
          'Debug: Hasil pencarian toko: ${merchantResponse.length} toko ditemukan');
      productController.searchedMerchants.assignAll(merchantResponse);
    } catch (e) {
      print('Debug: Error dalam pencarian: $e');
    } finally {
      isSearching.value = false; // Reset searching state
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primary,
        title: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                child: TextField(
                  controller: searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Cari Produk atau Toko...',
                    hintStyle: TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    prefixIcon: Icon(Icons.search, color: AppTheme.textHint),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: AppTheme.textHint),
                            onPressed: () {
                              setState(() {
                                searchController.clear();
                                productController.searchQuery.value = '';
                                productController.products.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {
                      productController.searchQuery.value = value;
                      if (value.isEmpty) {
                        productController.products.clear();
                      }
                    });
                  },
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      performSearch(value);
                    }
                  },
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.tune, color: Colors.white),
              onPressed: _showFilterBottomSheet,
            ),
          ],
        ),
      ),
      body: Obx(() {
        if (productController.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          slivers: [
            if (productController.searchedMerchants.isNotEmpty) ...[
              SliverPadding(
                padding: EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Toko',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final merchant = productController.searchedMerchants[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(Icons.store),
                      ),
                      title: Text(merchant['store_name'] ?? 'Nama Toko'),
                      subtitle: Text(
                        merchant['store_description'] ??
                            'Deskripsi tidak tersedia',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        Get.to(() => StoreDetailScreen(merchant: merchant));
                      },
                    );
                  },
                  childCount: productController.searchedMerchants.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Divider(height: 32),
              ),
            ],
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  productController.searchedMerchants.isEmpty
                      ? 'Hasil Pencarian'
                      : 'Produk dari Toko',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final product = productController.products[index];
                    return ProductCard(product: product);
                  },
                  childCount: productController.products.length,
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  @override
  void dispose() {
    // Gunakan addPostFrameCallback untuk menghindari error setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      productController.products.clear();
      productController.searchedMerchants.clear();
      productController.searchQuery.value = '';
    });
    searchController.dispose();
    minPriceController.dispose();
    maxPriceController.dispose();
    super.dispose();
  }
}

class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductCard({super.key, required this.product});

  String _getFirstImageUrl(Map<String, dynamic> product) {
    List<String> imageUrls = [];
    if (product['image_url'] != null) {
      try {
        if (product['image_url'] is List) {
          imageUrls = List<String>.from(product['image_url']);
        } else if (product['image_url'] is String) {
          final List<dynamic> urls = json.decode(product['image_url']);
          imageUrls = List<String>.from(urls);
        }
      } catch (e) {
        print('Error parsing image URLs: $e');
      }
    }
    return imageUrls.isNotEmpty
        ? imageUrls.first
        : 'https://via.placeholder.com/150';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => ProductDetailScreen(product: product)),
      child: Card(
        elevation: 0.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(_getFirstImageUrl(product)),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Rp ${NumberFormat('#,###').format(product['price'])}',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 12, color: AppTheme.textHint),
                      SizedBox(width: 4),
                      Text(
                        'Terjual ${product['sales'] ?? 0}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: AppTheme.textHint),
                      SizedBox(width: 4),
                      Expanded(
                        child: FutureBuilder(
                          future: Supabase.instance.client
                              .from('merchants')
                              .select('store_address')
                              .eq('id', product['seller_id'])
                              .single(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              final merchant = snapshot.data as Map;
                              try {
                                final addressData = jsonDecode(
                                    merchant['store_address'] ?? '{}');
                                return Text(
                                  addressData['city'] ??
                                      'Alamat tidak tersedia',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                );
                              } catch (e) {
                                return Text(
                                  'Alamat tidak valid',
                                  style: Theme.of(context).textTheme.bodySmall,
                                );
                              }
                            }
                            return Text(
                              'Memuat...',
                              style: Theme.of(context).textTheme.bodySmall,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
