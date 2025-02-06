import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/auth_controller.dart';
import 'cart/cart_screen.dart';
import 'profile/profile_screen.dart';
import 'product/product_detail_screen.dart';
import '../../theme/app_theme.dart';
import 'find/find_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat/chat_screen.dart';
import 'dart:convert';
import 'hotel/hotel_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  BuyerHomeScreen({super.key});

  @override
  _BuyerHomeScreenState createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  final ProductController productController = Get.put(ProductController());
  final AuthController authController = Get.find<AuthController>();
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> banners = [];
  bool isLoadingBanners = true;
  int _selectedIndex = 0;
  final TextEditingController searchController = TextEditingController();
  final TextEditingController minPriceController = TextEditingController();
  final TextEditingController maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    productController.fetchProducts();
    fetchBanners();
  }

  Future<void> fetchBanners() async {
    try {
      final response = await supabase
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('created_at');

      setState(() {
        banners = (response as List<dynamic>).cast<Map<String, dynamic>>();
        isLoadingBanners = false;
      });
    } catch (e) {
      print('Error fetching banners: $e');
      setState(() {
        isLoadingBanners = false;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) {
        searchController.clear();
        productController.searchQuery.value = '';
        productController.fetchProducts();
      }
    });
  }

  void _showPriceFilterDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Filter Harga'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Harga Minimum',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: maxPriceController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Harga Maksimum',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              minPriceController.clear();
              maxPriceController.clear();
              productController.filterByPrice(null, null);
              Get.back();
            },
            child: Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              final minPrice = double.tryParse(minPriceController.text);
              final maxPrice = double.tryParse(maxPriceController.text);
              productController.filterByPrice(minPrice, maxPrice);
              Get.back();
            },
            child: Text('Terapkan'),
          ),
        ],
      ),
    );
  }

  void _performSearch(String value) async {
    setState(() => _selectedIndex = 1);
    productController.searchQuery.value = value;

    try {
      // Cari produk
      productController.searchProducts(value);

      // Cari toko dengan case insensitive
      final merchantResponse = await supabase
          .from('merchants')
          .select('id, store_name, store_description')
          .or('store_name.ilike.%${value}%,store_description.ilike.%${value}%')
          .limit(5);

      print('Merchant search response: $merchantResponse'); // Debug print
      productController.searchedMerchants.assignAll(merchantResponse);
    } catch (e) {
      print('Error searching: $e');
    }
  }

  Widget _getScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return FindScreen();
      case 2:
        return HotelScreen(); // Tambahkan screen hotel
      case 3:
        return ProfileScreen();
      default:
        return _buildHomeContent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: AppTheme.primary,
              title: Container(
                height: 40,
                child: TextField(
                  controller: searchController,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    hintText: 'Cari di Saraja',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textHint,
                        ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.search, color: AppTheme.textHint),
                      onPressed: () => _performSearch(searchController.text),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                  onSubmitted: _performSearch,
                ),
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.2),
                  child: IconButton(
                    icon:
                        Icon(Icons.notifications_outlined, color: Colors.white),
                    onPressed: () => Get.to(() => CartScreen()),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.2),
                  child: IconButton(
                    icon:
                        Icon(Icons.shopping_cart_outlined, color: Colors.white),
                    onPressed: () => Get.to(() => CartScreen()),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.2),
                  child: IconButton(
                    icon: Icon(Icons.chat_outlined, color: Colors.white),
                    onPressed: () => Get.to(() => ChatScreen()),
                  ),
                ),
              ],
            )
          : null,
      body: _getScreen(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: 'Menemukan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hotel_outlined),
            label: 'Hotel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildBannerCarousel() {
    if (isLoadingBanners) {
      return Container(
        height: 210,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (banners.isEmpty) {
      return Container(
        height: 210,
        child: Center(child: Text('Tidak ada banner tersedia')),
      );
    }

    return Container(
      height: 210,
      child: PageView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final banner = banners[index];
          return Container(
            width: MediaQuery.of(context).size.width * 0.90,
            margin: EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              image: DecorationImage(
                image: NetworkImage(banner['image_url']),
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          productController.fetchProducts(),
          fetchBanners(),
        ]);
      },
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildBannerCarousel(),

            // Menu Categories
            Container(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kategori',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showPriceFilterDialog,
                        icon: Icon(Icons.filter_list,
                            size: 20, color: AppTheme.primary),
                        label: Text(
                          'Filter Harga',
                          style: TextStyle(color: AppTheme.primary),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      CategoryIcon(
                        icon: Icons.checkroom_outlined,
                        label: 'Pakaian',
                        onTap: () {
                          if (productController.currentCategory.value ==
                              'fashion') {
                            productController.currentCategory.value = '';
                            productController.fetchProducts();
                          } else {
                            productController.currentCategory.value = 'fashion';
                            productController.filterByCategory('fashion');
                          }
                        },
                      ),
                      CategoryIcon(
                        icon: Icons.phone_android_outlined,
                        label: 'Elektronik',
                        onTap: () {
                          if (productController.currentCategory.value ==
                              'elektronik') {
                            productController.currentCategory.value = '';
                            productController.fetchProducts();
                          } else {
                            productController.currentCategory.value =
                                'elektronik';
                            productController.filterByCategory('elektronik');
                          }
                        },
                      ),
                      CategoryIcon(
                        icon: Icons.watch_outlined,
                        label: 'Aksesoris',
                        onTap: () {
                          if (productController.currentCategory.value ==
                              'aksesoris') {
                            productController.currentCategory.value = '';
                            productController.fetchProducts();
                          } else {
                            productController.currentCategory.value =
                                'aksesoris';
                            productController.filterByCategory('aksesoris');
                          }
                        },
                      ),
                      CategoryIcon(
                        icon: Icons.more_horiz,
                        label: 'lainnya',
                        onTap: () =>
                            productController.filterByCategory('aksesoris'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Products Grid
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Obx(() {
                if (productController.isLoading.value) {
                  return Center(child: CircularProgressIndicator());
                }

                if (productController.products.isEmpty) {
                  return Center(child: Text('Tidak ada produk'));
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: productController.products.length,
                  itemBuilder: (context, index) {
                    final product = productController.products[index];
                    return ProductCard(product: product);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget untuk Category Icon
class CategoryIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const CategoryIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 30, color: AppTheme.primary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Memperbarui ProductCard untuk gaya Shopee
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    // Parse image URLs
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
            // Gambar Produk
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                      imageUrls.isNotEmpty
                          ? imageUrls.first // Tampilkan gambar pertama
                          : 'https://via.placeholder.com/150', // Gambar default
                    ),
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
                                // Parse JSON string ke Map
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
