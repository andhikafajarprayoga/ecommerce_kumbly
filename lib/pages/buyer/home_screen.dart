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
import 'package:rxdart/rxdart.dart';
import '../../controllers/cart_controller.dart';

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
  RxInt cartCount = 0.obs;
  RxInt unreadChatCount = 0.obs;
  final CartController cartController = Get.put(CartController());

  @override
  void initState() {
    super.initState();
    productController.fetchProducts();
    fetchBanners();
    fetchCartCount();
    listenToCartChanges();
    fetchUnreadChats();
    listenToUnreadChats();
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

  Future<void> fetchCartCount() async {
    try {
      final response = await supabase
          .from('cart_items')
          .select('id')
          .eq('user_id', supabase.auth.currentUser!.id)
          .count();

      cartCount.value = response.count ?? 0;
    } catch (e) {
      print('Error fetching cart count: $e');
    }
  }

  void listenToCartChanges() {
    final myUserId = supabase.auth.currentUser!.id;
    supabase
        .from('cart_items')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          cartCount.value =
              data.where((item) => item['user_id'] == myUserId).length;
        });
  }

  Future<void> fetchUnreadChats() async {
    try {
      final response = await supabase
          .from('chat_messages')
          .select('id')
          .eq('receiver_id', supabase.auth.currentUser!.id)
          .eq('is_read', false)
          .count();

      unreadChatCount.value = response.count ?? 0;
    } catch (e) {
      print('Error fetching unread chats: $e');
    }
  }

  void listenToUnreadChats() {
    final myUserId = supabase.auth.currentUser!.id;
    supabase
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          unreadChatCount.value = data
              .where((msg) =>
                  msg['receiver_id'] == myUserId && msg['is_read'] == false)
              .length;
        });
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
                  child: Stack(
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
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.2),
                  child: Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.chat_outlined, color: Colors.white),
                        onPressed: () => Get.to(() => ChatScreen()),
                      ),
                      Obx(() => unreadChatCount.value > 0
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
                                  '${unreadChatCount.value}',
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
            label: 'Jelajahi',
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
                          fontWeight: FontWeight.normal,
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
                        label: 'Fashion',
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
                        label: 'Lainnya',
                        onTap: () {
                          if (productController.currentCategory.value ==
                              'lainnya') {
                            productController.currentCategory.value = '';
                            productController.fetchProducts();
                          } else {
                            productController.currentCategory.value = 'lainnya';
                            productController.filterOtherCategories();
                          }
                        },
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
  final ProductController productController = Get.find<ProductController>();

  CategoryIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  String _getCategoryValue() {
    switch (label.toLowerCase()) {
      case 'fashion':
        return 'fashion';
      case 'elektronik':
        return 'elektronik';
      case 'aksesoris':
        return 'aksesoris';
      case 'lainnya':
        return 'lainnya';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected =
          productController.currentCategory.value == _getCategoryValue() &&
              productController.currentCategory.value.isNotEmpty;
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          child: Column(
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 300),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : AppTheme.primaryLight.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          )
                        ]
                      : [],
                ),
                child: Icon(icon,
                    size: 30,
                    color: isSelected ? Colors.white : AppTheme.primary),
              ),
              const SizedBox(height: 8),
              AnimatedDefaultTextStyle(
                duration: Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      );
    });
  }
}

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
