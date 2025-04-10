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
  final String? initialSearchQuery;

  const FindScreen({Key? key, this.initialSearchQuery}) : super(key: key);

  @override
  _FindScreenState createState() => _FindScreenState();
}

class _FindScreenState extends State<FindScreen> {
  final TextEditingController searchController = TextEditingController();
  final ProductController productController = Get.find<ProductController>();
  final supabase = Supabase.instance.client;
  final minPriceController = TextEditingController(text: '0');
  final maxPriceController = TextEditingController(text: '0');
  final formatter = NumberFormat('#,###');
  final isSearching = false.obs;

  @override
  void initState() {
    super.initState();

    // Selalu gunakan nilai pencarian dari productController jika ada
    final searchValue = productController.searchQuery.value;
    if (searchValue.isNotEmpty) {
      searchController.text = searchValue;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(searchValue);
      });
    }

    // Cek tipe arguments untuk menentukan apakah query pencarian atau index navigasi
    final arguments = Get.arguments;
    if (arguments != null) {
      if (arguments is String) {
        // Jika arguments adalah String, itu adalah query pencarian dari home screen
        searchController.text = arguments;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          performSearch(arguments);
        });
      } else if (arguments is int) {
        // Jika arguments adalah int, itu adalah index navigasi
        // Langsung load semua produk hanya jika bukan dari home screen
        if (productController.searchQuery.value.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            performSearch(''); // Load semua produk dengan query kosong
          });
        }
      }
    } else {
      // Jika tidak ada arguments dan tidak ada query pencarian, load semua produk
      if (productController.searchQuery.value.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          performSearch('');
        });
      }
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) return;

    try {
      isSearching.value = true;

      // Set search query
      productController.searchQuery.value = query;

      // Cari produk
      await productController.searchProducts(query);

      // Cari toko
      final merchantResponse = await supabase
          .from('merchants')
          .select('id, store_name, store_description')
          .or('store_name.ilike.%${query}%,store_description.ilike.%${query}%')
          .limit(5);

      productController.searchedMerchants.assignAll(merchantResponse);
    } catch (e) {
      print('Error searching in FindScreen: $e');
    } finally {
      isSearching.value = false;
    }
  }

  void resetSearch() {
    searchController.clear();
    productController.searchQuery.value = '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      productController.products.clear();
      productController.searchedMerchants.clear();
    });
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
    final Map<String, List<String>> categories = {
      'Elektronik & Gadget': [
        'Smartphone & Aksesoris',
        'Laptop & PC',
        'Kamera & Aksesoris',
        'Smartwatch & Wearable Tech',
        'Peralatan Gaming',
      ],
      'Fashion & Aksesoris': [
        'Pakaian Pria',
        'Pakaian Wanita',
        'Sepatu & Sandal',
        'Tas & Dompet',
        'Jam Tangan & Perhiasan',
      ],
      'Kesehatan & Kecantikan': [
        'Skincare',
        'Make-up',
        'Parfum',
        'Suplemen & Vitamin',
        'Alat Kesehatan',
      ],
      'Makanan & Minuman': [
        'Makanan Instan',
        'Minuman Kemasan',
        'Camilan & Snack',
        'Bahan Makanan',
      ],
      'Rumah Tangga & Perabotan': [
        'Peralatan Dapur',
        'Furniture',
        'Dekorasi Rumah',
        'Alat Kebersihan',
      ],
      'Otomotif & Aksesoris': [
        'Suku Cadang Kendaraan',
        'Aksesoris Mobil & Motor',
        'Helm & Perlengkapan Berkendara',
      ],
      'Hobi & Koleksi': [
        'Buku & Majalah',
        'Alat Musik',
        'Action Figure & Koleksi',
        'Olahraga & Outdoor',
      ],
      'Bayi & Anak': [
        'Pakaian Bayi & Anak',
        'Mainan Anak',
        'Perlengkapan Bayi',
      ],
      'Keperluan Industri & Bisnis': [
        'Alat Teknik & Mesin',
        'Perlengkapan Kantor',
        'Peralatan Keamanan',
      ],

      // ... kategori lainnya ...
    };

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.all(16),
          child: SingleChildScrollView(
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
                // Tambahkan bagian Kategori
                Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  height: 200,
                  child: ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      String mainCategory = categories.keys.elementAt(index);
                      List<String> subCategories = categories[mainCategory]!;

                      return ExpansionTile(
                        leading: Icon(_getCategoryIcon(mainCategory)),
                        title: Text(mainCategory),
                        children: subCategories
                            .map((subCategory) => ListTile(
                                  contentPadding: EdgeInsets.only(left: 72),
                                  title: Text(subCategory),
                                  onTap: () {
                                    productController
                                        .filterByMainCategory([subCategory]);
                                    Get.back();
                                  },
                                ))
                            .toList(),
                      );
                    },
                  ),
                ),
                Divider(),
                // Bagian filter harga yang sudah ada
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
                // Bagian pengurutan yang sudah ada
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
                        int minPrice = 0;
                        int maxPrice = 999999999;

                        if (minPriceController.text.isNotEmpty) {
                          minPrice = int.parse(minPriceController.text
                              .replaceAll(RegExp(r'[^0-9]'), ''));
                        }

                        if (maxPriceController.text.isNotEmpty) {
                          maxPrice = int.parse(maxPriceController.text
                              .replaceAll(RegExp(r'[^0-9]'), ''));
                        }

                        // Validasi harga minimum dan maksimum
                        if (minPrice > maxPrice && maxPrice != 999999999) {
                          Get.snackbar(
                            'Error',
                            'Harga maksimum tidak boleh kosong',
                            backgroundColor: Colors.red,
                            colorText: Colors.white,
                          );
                          return;
                        }

                        // Terapkan filter harga
                        productController.filterByPriceRange(
                            minPrice, maxPrice);
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
      ),
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Elektronik & Gadget':
        return Icons.devices;
      case 'Fashion & Aksesoris':
        return Icons.shopping_bag;
      case 'Kesehatan & Kecantikan':
        return Icons.health_and_safety;
      case 'Makanan & Minuman':
        return Icons.restaurant;
      case 'Rumah Tangga & Perabotan':
        return Icons.home;
      case 'Otomotif & Aksesoris':
        return Icons.directions_car;
      case 'Hobi & Koleksi':
        return Icons.sports_esports;
      case 'Bayi & Anak':
        return Icons.child_care;
      case 'Keperluan Industri & Bisnis':
        return Icons.business;
      default:
        return Icons.category;
    }
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
    try {
      isSearching.value = true;
      productController.products.clear();
      productController.searchedMerchants.clear();

      // Cek apakah ini pencarian dari home screen
      final isFromHomeScreen = Get.arguments is String && value.isNotEmpty;

      if (value.isEmpty && !isFromHomeScreen) {
        // Jika query kosong dan bukan dari home screen, ambil semua produk
        final productsResponse = await supabase
            .from('products')
            .select()
            .order('created_at', ascending: false);

        if (productsResponse != null) {
          productController.products.assignAll(productsResponse);
          print('Debug: Loaded all products: ${productsResponse.length}');
        }
        return;
      }

      // Cari merchant berdasarkan nama toko
      final merchantsResponse = await supabase
          .from('merchants')
          .select('id, store_name, store_description, store_address')
          .or('store_name.ilike.%${value}%,store_description.ilike.%${value}%')
          .limit(10);

      print('Debug: Merchants search result: $merchantsResponse');

      if (merchantsResponse != null && merchantsResponse.isNotEmpty) {
        productController.searchedMerchants.assignAll(merchantsResponse);
        print('Debug: Found ${merchantsResponse.length} merchants');

        // Jika ada merchant yang ditemukan, cari produk dari merchant pertama
        if (merchantsResponse.isNotEmpty) {
          final merchantId = merchantsResponse[0]['id'];
          await _fetchMerchantProducts(merchantId);
        }
      } else {
        print('Debug: No merchants found for query: $value');
      }

      // Jika tidak ada produk dari merchant, cari produk berdasarkan nama, deskripsi, dan kategori
      if (productController.products.isEmpty) {
        final productsResponse = await supabase
            .from('products')
            .select()
            .or('name.ilike.%$value%,category.ilike.%$value%')
            .order('created_at', ascending: false);

        print('Debug: Products search result: $productsResponse');

        if (productsResponse != null) {
          productController.products.assignAll(productsResponse);
          print('Debug: Found ${productsResponse.length} products');
        } else {
          print('Debug: No products found for query: $value');
        }
      }

      // Debug state setelah pencarian
      print(
          'Debug: searchedMerchants count: ${productController.searchedMerchants.length}');
      print('Debug: products count: ${productController.products.length}');
    } catch (e) {
      print('Debug: Error dalam pencarian: $e');
    } finally {
      isSearching.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        navigateBack();
        return false;
      },
      child: Scaffold(
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
                    autofocus: Get.arguments is String,
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
                                  productController.searchedMerchants.clear();
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
                          productController.searchedMerchants.clear();
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
          print('Debug: Building FindScreen body');
          print(
              'Debug: searchedMerchants count: ${productController.searchedMerchants.length}');
          print('Debug: products count: ${productController.products.length}');

          if (productController.isLoading.value) {
            return Center(child: CircularProgressIndicator());
          }

          // Cek apakah ada produk yang ditemukan
          if (productController.products.isEmpty &&
              productController.searchedMerchants.isEmpty) {
            return Center(child: Text('Tidak ada produk ditemukan'));
          }

          // Tampilkan produk secara langsung saat awal masuk
          if (productController.products.isEmpty &&
              productController.searchedMerchants.isEmpty &&
              !isSearching.value &&
              productController.searchQuery.value.isEmpty) {
            print('Debug: Auto-loading all products');
            performSearch('');
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
                      final merchant =
                          productController.searchedMerchants[index];
                      print(
                          'Debug: Rendering merchant: ${merchant['store_name']}');
                      return Card(
                        margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(8),
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey[200],
                            child: Icon(Icons.store, color: AppTheme.primary),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  merchant['store_name'] ?? 'Nama Toko',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Toko',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                merchant['store_description'] ??
                                    'Deskripsi tidak tersedia',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 4),
                              FutureBuilder(
                                future: supabase
                                    .from('products')
                                    .select('id')
                                    .eq('seller_id', merchant['id']),
                                builder: (context, snapshot) {
                                  int productCount = 0;
                                  if (snapshot.hasData &&
                                      snapshot.data is List) {
                                    productCount =
                                        (snapshot.data as List).length;
                                  }
                                  return Text(
                                    '$productCount Produk',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textHint,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          trailing: Icon(Icons.chevron_right),
                          onTap: () {
                            Get.to(() => StoreDetailScreen(merchant: merchant));
                          },
                        ),
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
      ),
    );
  }

  @override
  void dispose() {
    // Reset state pencarian saat meninggalkan FindScreen
    productController.searchQuery.value = '';
    searchController.dispose();
    super.dispose();
  }

  void navigateBack() {
    resetSearch();
    // Kembali ke home screen dengan index 0 (Beranda) untuk reset
    Get.off(() => BuyerHomeScreen(), arguments: 0);
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
                    product['name'].length > 20
                        ? '${product['name'].substring(0, 20)}...'
                        : product['name'],
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
                                // Handle kasus dimana store_address null atau kosong
                                if (merchant['store_address'] == null ||
                                    merchant['store_address']
                                        .toString()
                                        .isEmpty) {
                                  return Text(
                                    'Alamat tidak tersedia',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }

                                // Parse address data dengan pengecekan
                                Map<String, dynamic> addressData;
                                try {
                                  addressData =
                                      jsonDecode(merchant['store_address']);
                                } catch (e) {
                                  // Jika gagal parse JSON, coba gunakan string address langsung
                                  return Text(
                                    merchant['store_address'].toString(),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }

                                // Tampilkan kota jika ada, atau full address jika tidak ada kota
                                return Text(
                                  addressData['city'] ??
                                      addressData['full_address'] ??
                                      'Alamat tidak tersedia',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                );
                              } catch (e) {
                                print('Error parsing address: $e');
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
