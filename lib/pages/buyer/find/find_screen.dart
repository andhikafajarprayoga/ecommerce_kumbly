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

class FindScreen extends StatelessWidget {
  final ProductController productController = Get.find<ProductController>();
  final supabase = Supabase.instance.client;

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
          userLocation['lat']?.toDouble() ?? 0.0,
          userLocation['lng']?.toDouble() ?? 0.0,
          a['merchant_location']['lat']?.toDouble() ?? 0.0,
          a['merchant_location']['lng']?.toDouble() ?? 0.0,
        );

        double distanceB = _calculateDistance(
          userLocation['lat']?.toDouble() ?? 0.0,
          userLocation['lng']?.toDouble() ?? 0.0,
          b['merchant_location']['lat']?.toDouble() ?? 0.0,
          b['merchant_location']['lng']?.toDouble() ?? 0.0,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppTheme.primary,
        title: Container(
          height: 40,
          child: TextField(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'Cari Produk...',
              hintStyle: TextStyle(fontSize: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              suffixIcon: IconButton(
                icon: Icon(Icons.search, color: AppTheme.textHint),
                onPressed: () {
                  productController
                      .searchProducts(productController.searchQuery.value);
                },
              ),
            ),
            controller: TextEditingController(
                text: productController.searchQuery.value),
            onChanged: (value) {
              productController.searchQuery.value = value;
            },
            onSubmitted: (value) {
              productController.searchProducts(value);
            },
            textInputAction: TextInputAction.search,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showSortOptions(),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.sort,
                              size: 18, color: AppTheme.textPrimary),
                          SizedBox(width: 4),
                          Text(
                            'Urutkan',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: AppTheme.textPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: Obx(() {
              return GridView.builder(
                padding: EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: productController.products.length,
                itemBuilder: (context, index) {
                  final product = productController.products[index];
                  return ProductCard(
                      product: product); // Gunakan ProductCard dari home_screen
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
