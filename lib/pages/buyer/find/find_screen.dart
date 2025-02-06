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
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    searchController.text = productController.searchQuery.value;
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

  Future<void> performSearch(String query) async {
    try {
      productController.isLoading.value = true;

      // Reset merchants sebelum pencarian baru
      productController.searchedMerchants.clear();

      // Cari produk
      await productController.searchProducts(query);

      // Cari merchant jika query tidak kosong
      if (query.isNotEmpty) {
        final merchantResponse = await supabase
            .from('merchants')
            .select('id, store_name, store_description')
            .or('store_name.ilike.%${query}%,store_description.ilike.%${query}%')
            .limit(5);

        print('Merchant search response: $merchantResponse');
        productController.searchedMerchants.assignAll(merchantResponse);
      }
    } catch (e) {
      print('Error searching: $e');
    } finally {
      productController.isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primary,
        title: Container(
          height: 40,
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Cari Produk atau Toko...',
              hintStyle: TextStyle(fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              prefixIcon: Icon(Icons.search, color: AppTheme.textHint),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: AppTheme.textHint),
                      onPressed: () {
                        setState(() {
                          searchController.clear();
                          productController.searchQuery.value = '';
                          performSearch('');
                        });
                      },
                    )
                  : IconButton(
                      icon: Icon(Icons.search, color: AppTheme.textHint),
                      onPressed: () {
                        performSearch(searchController.text);
                      },
                    ),
            ),
            onChanged: (value) {
              setState(() {
                productController.searchQuery.value = value;
                if (value.isEmpty) {
                  performSearch('');
                }
              });
            },
            onSubmitted: (value) {
              performSearch(value);
            },
            textInputAction: TextInputAction.search,
          ),
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
                    fontWeight: FontWeight.bold,
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
    searchController.dispose();
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
