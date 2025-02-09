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
import 'package:rxdart/rxdart.dart' hide Rx;
import '../../controllers/cart_controller.dart';
import 'dart:async';

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
  final RxInt _unreadChatsCount = 0.obs;
  late Stream<int> _unreadChatsStream;
  final CartController cartController = Get.put(CartController());
  StreamSubscription? _chatSubscription;

  @override
  void initState() {
    super.initState();
    productController.fetchProducts();
    fetchBanners();

    // Hanya jalankan fungsi yang membutuhkan auth jika user sudah login
    if (supabase.auth.currentUser != null) {
      fetchCartCount();
      listenToCartChanges();
      _setupUnreadChatsStream();
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    super.dispose();
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
    final myUserId = supabase.auth.currentUser?.id;
    if (myUserId == null) return; // Skip jika belum login

    supabase
        .from('cart_items')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .listen((List<Map<String, dynamic>> data) {
          cartCount.value =
              data.where((item) => item['user_id'] == myUserId).length;
        });
  }

  void _setupUnreadChatsStream() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _chatSubscription?.cancel();

    // Stream untuk chat_rooms
    final roomStream = supabase
        .from('chat_rooms')
        .stream(primaryKey: ['id']).eq('buyer_id', userId);

    // Stream untuk chat_messages
    final messageStream =
        supabase.from('chat_messages').stream(primaryKey: ['id']);

    // Combine kedua stream
    _chatSubscription = CombineLatestStream(
      [roomStream, messageStream],
      (values) async {
        final rooms = values[0] as List<Map<String, dynamic>>;
        final messages = values[1] as List<Map<String, dynamic>>;
        final roomIds = rooms.map((room) => room['id']).toList();

        if (roomIds.isEmpty) return 0;

        final unreadMessages = messages.where((msg) =>
            roomIds.contains(msg['room_id']) &&
            msg['is_read'] == false &&
            msg['sender_id'] != userId);

        final unreadRooms = unreadMessages.map((msg) => msg['room_id']).toSet();

        return unreadRooms.length;
      },
    ).listen(
      (Future<int> countFuture) async {
        final count = await countFuture;
        _unreadChatsCount.value = count;
      },
      onError: (error) => print('Error in chat stream: $error'),
    );
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
                        icon: Icon(Icons.shopping_cart_outlined,
                            color: Colors.white),
                        onPressed: () => Get.to(() => CartScreen()),
                      ),
                      Obx(() => cartController.cartItems.isNotEmpty
                          ? Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(255, 0, 0, 0),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  '${cartController.cartItems.length}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : SizedBox()),
                    ],
                  ),
                ),
                Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chat_outlined, color: Colors.white),
                      onPressed: () => Get.to(() => ChatScreen()),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Obx(() => _unreadChatsCount.value > 0
                          ? Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 1.5),
                              ),
                              constraints: BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                '${_unreadChatsCount.value}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : SizedBox()),
                    ),
                  ],
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
                        subCategories: [
                          'Tas & Dompet',
                          'Pakaian Pria',
                          'Sepatu & Sandal'
                        ],
                        onTap: () {
                          if (productController.currentCategory.value ==
                              'fashion') {
                            productController.currentCategory.value = '';
                            productController.fetchProducts();
                          } else {
                            productController.currentCategory.value = 'fashion';
                            productController.filterByMainCategory([
                              'Pakaian Pria',
                              'Sepatu & Sandal',
                              'Tas & Dompet',
                              'Aksesoris',
                              'Jam Tangan & Perhiasan',
                              'Pakaian Wanita'
                            ]);
                          }
                        },
                      ),
                      CategoryIcon(
                        icon: Icons.home_outlined,
                        label: 'Perabotan',
                        subCategories: [
                          'Peralatan Dapur',
                          'Furniture',
                          'Dekorasi Rumah',
                          'Alat Kebersihan'
                        ],
                        onTap: () {
                          if (productController.currentCategory.value ==
                              'perabotan') {
                            productController.currentCategory.value = '';
                            productController.fetchProducts();
                          } else {
                            productController.currentCategory.value =
                                'perabotan';
                            productController.filterByMainCategory([
                              'Peralatan Dapur',
                              'Furniture',
                              'Dekorasi Rumah',
                              'Alat Kebersihan'
                            ]);
                          }
                        },
                      ),
                      CategoryIcon(
                        icon: Icons.local_mall_outlined,
                        label: 'Aksesoris',
                        subCategories: ['Tas & Dompet'],
                        onTap: () {
                          if (productController.currentCategory.value ==
                              'aksesoris') {
                            productController.currentCategory.value = '';
                            productController.fetchProducts();
                          } else {
                            productController.currentCategory.value =
                                'aksesoris';
                            productController
                                .filterByMainCategory(['Tas & Dompet']);
                          }
                        },
                      ),
                      CategoryIcon(
                        icon: Icons.more_horiz,
                        label: 'Lainnya',
                        subCategories: [],
                        onTap: () => showModalBottomSheet(
                          context: context,
                          builder: (context) => CategoryListModal(),
                        ),
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
  final List<String> subCategories;
  final VoidCallback onTap;
  final ProductController productController = Get.find<ProductController>();

  CategoryIcon({
    required this.icon,
    required this.label,
    required this.subCategories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected =
          productController.currentCategory.value == label.toLowerCase();

      return GestureDetector(
        onTap: onTap,
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
              child: Icon(
                icon,
                size: 30,
                color: isSelected ? Colors.white : AppTheme.primary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
              ),
            ),
          ],
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

class CategoryListModal extends StatelessWidget {
  final ProductController productController = Get.find<ProductController>();

  final Map<String, List<String>> categoryMap = {
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
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Semua Kategori',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: categoryMap.length,
              itemBuilder: (context, index) {
                String mainCategory = categoryMap.keys.elementAt(index);
                List<String> subCategories = categoryMap[mainCategory]!;

                return ExpansionTile(
                  leading: Icon(_getCategoryIcon(mainCategory)),
                  title: Text(mainCategory),
                  children: subCategories
                      .map((subCategory) => ListTile(
                            contentPadding: EdgeInsets.only(left: 72),
                            title: Text(subCategory),
                            onTap: () {
                              print(
                                  'Selected sub-category: $subCategory'); // Debug print
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
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Elektronik & Gadget':
        return Icons.devices;
      case 'Fashion & Aksesoris':
        return Icons.checkroom;
      case 'Kesehatan & Kecantikan':
        return Icons.spa;
      case 'Makanan & Minuman':
        return Icons.fastfood;
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
}
