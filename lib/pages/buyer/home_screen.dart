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
import 'notification/notification_screen.dart';
import '../../controllers/hotel_screen_controller.dart';
import '../../services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'kirim_barang/kirim_barang_screen.dart';

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
  var searchQuery = ''.obs;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    Get.put(RxInt(0), tag: 'selectedIndex');

    // Kosongkan field pencarian saat halaman beranda dimuat

    // Setup notifikasi untuk berbagai event

    // Reset data jika kembali dari FindScreen atau StoreDetail
    final arguments = Get.arguments;
    if (arguments != null && arguments is int && arguments == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        productController.products.clear();
        productController.searchQuery.value = '';
        productController.searchedMerchants.clear();
        productController.fetchProducts();
        searchController.clear();
      });
    } else {
      // Reset data produk dan hotel ketika kembali ke home screen
      productController.products.clear();
      productController.hotels.clear();
      productController.fetchProducts();
    }

    fetchBanners();

    // Hanya jalankan fungsi yang membutuhkan auth jika user sudah login
    if (supabase.auth.currentUser != null) {
      fetchCartCount();
      listenToCartChanges();
      _setupUnreadChatsStream();
      _setupNotificationListeners();
    }

    // Inisialisasi notification handler
    flutterLocalNotificationsPlugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationTap(details.payload);
      },
    );
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

  void resetSearch() {
    searchQuery.value = '';
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

    try {
      // Stream untuk chat_rooms
      final roomStream = supabase
          .from('chat_rooms')
          .stream(primaryKey: ['id'])
          .eq('buyer_id', userId)
          .execute()
          .handleError((error) {
            print('Room stream error: $error');
            Future.delayed(
                Duration(seconds: 3), () => _setupUnreadChatsStream());
          });

      // Stream untuk chat_messages
      final messageStream = supabase
          .from('chat_messages')
          .stream(primaryKey: ['id'])
          .execute()
          .handleError((error) {
            print('Message stream error: $error');
            Future.delayed(
                Duration(seconds: 3), () => _setupUnreadChatsStream());
          });

      // Combine kedua stream dengan error handling
      _chatSubscription = CombineLatestStream.combine2(
        roomStream,
        messageStream,
        (rooms, messages) async {
          try {
            final roomsList = rooms as List<Map<String, dynamic>>;
            final messagesList = messages as List<Map<String, dynamic>>;
            final roomIds = roomsList.map((room) => room['id']).toList();

            if (roomIds.isEmpty) return 0;

            final unreadMessages = messagesList.where((msg) =>
                roomIds.contains(msg['room_id']) &&
                msg['is_read'] == false &&
                msg['sender_id'] != userId);

            return unreadMessages.map((msg) => msg['room_id']).toSet().length;
          } catch (e) {
            print('Error processing chat data: $e');
            return 0;
          }
        },
      ).asyncMap((future) async => await future).listen(
        (count) => _unreadChatsCount.value = count,
        onError: (error) {
          print('Combined stream error: $error');
          Future.delayed(Duration(seconds: 3), () => _setupUnreadChatsStream());
        },
      );
    } catch (e) {
      print('Setup chat stream error: $e');
      // Coba setup ulang setelah error
      Future.delayed(Duration(seconds: 3), () => _setupUnreadChatsStream());
    }
  }

  void _setupNotificationListeners() {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Listen to notifications table
    supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .execute()
        .listen((List<Map<String, dynamic>> notifications) {
          if (notifications.isEmpty) return;

          // Cek notifikasi yang belum dibaca
          final unreadNotifications =
              notifications.where((n) => n['is_read'] == false);
          if (unreadNotifications.isEmpty) return;

          // Ambil notifikasi terbaru
          final latestNotif = unreadNotifications.first;
          final now = DateTime.now();
          final notifTime = DateTime.parse(latestNotif['created_at']);

          // Tampilkan notifikasi jika baru dibuat (dalam 5 detik terakhir)
          if (now.difference(notifTime).inSeconds <= 5) {
            _showNotification(
              latestNotif['title'],
              latestNotif['message'],
            );
          }
        });
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;

    try {
      final data = jsonDecode(payload);
      if (data['type'] == 'notification') {
        Get.to(() => NotificationScreen());
      }
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  void _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'notifications_buyer_channel',
      'Notifications',
      channelDescription: 'Channel for buyer notifications',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      fullScreenIntent: true,
      styleInformation: BigTextStyleInformation(''),
      playSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      platformDetails,
      payload: jsonEncode({
        'type': 'notification',
        'data': {
          'title': title,
          'message': body,
        }
      }),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      if (_selectedIndex == index) {
        if (index == 0) {
          // Reset Beranda
          WidgetsBinding.instance.addPostFrameCallback((_) {
            searchController.clear();
            productController.products.clear();
            productController.searchQuery.value = '';
            productController.searchedMerchants.clear();
            productController.fetchProducts();
          });
          // Kosongkan field pencarian saat kembali ke beranda
        } else if (index == 1) {
          // Reset Find/Search screen hanya jika tab diklik ulang
          if (_selectedIndex == 1) {
            searchController.clear();
            productController.products.clear();
            productController.searchQuery.value = '';
            productController.searchedMerchants.clear();
            // Jangan panggil fetchProducts() di sini
          }
        } else if (index == 2) {
          // Reset Hotel screen
          Get.find<HotelScreenController>().resetSearch();
        }
      }
      _selectedIndex = index;
      if (_selectedIndex == 0) {
        // Panggil fetchProducts saat kembali ke beranda
        productController.fetchProducts();
      }
    });
  }

  void _performSearch(String value) async {
    if (value.isEmpty) return;

    try {
      // Set search query
      productController.searchQuery.value = value;
      productController.isLoading.value = true;

      // Buat query pencarian yang lebih komprehensif
      final productsResponse = await supabase
          .from('products')
          .select()
          .or('name.ilike.%${value}%,description.ilike.%${value}%,category.ilike.%${value}%')
          .order('created_at', ascending: false);

      // Update hasil pencarian
      if (productsResponse != null) {
        productController.products.assignAll(productsResponse);
        print(
            'Debug: Found ${productsResponse.length} products for query: $value');
      }

      // Cari toko dengan case insensitive
      final merchantResponse = await supabase
          .from('merchants')
          .select('id, store_name, store_description, store_address')
          .or('store_name.ilike.%${value}%,store_description.ilike.%${value}%')
          .limit(10);

      print('Debug: Merchants search result: $merchantResponse');

      if (merchantResponse != null) {
        productController.searchedMerchants.assignAll(merchantResponse);
      }

      // Pindah ke FindScreen dengan search query dan hasil pencarian
      Get.off(() => FindScreen(initialSearchQuery: value), arguments: value);
    } catch (e) {
      print('Error searching: $e');
      Get.snackbar(
        'Error',
        'Terjadi kesalahan saat mencari produk',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      productController.isLoading.value = false;
    }
  }

  Widget _getScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        // Pass initial search query dan hasil pencarian ke FindScreen
        return FindScreen(
            initialSearchQuery: productController.searchQuery.value);
      case 2:
        return HotelScreen();
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
                  onSubmitted: (value) {
                    _performSearch(value);
                    // Kosongkan field setelah pencarian
                  },
                ),
              ),
              actions: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.2),
                  child: Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.notifications_outlined,
                            color: Colors.white),
                        onPressed: () {
                          if (supabase.auth.currentUser == null) {
                            Get.toNamed('/login');
                          } else {
                            Get.to(() => NotificationScreen());
                          }
                        },
                      ),
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: supabase
                            .from('notifications')
                            .select()
                            .eq('user_id', supabase.auth.currentUser?.id ?? '')
                            .eq('is_read', false)
                            .order('created_at', ascending: false)
                            .asStream(),
                        builder: (context, snapshot) {
                          final unreadCount =
                              (snapshot.data as List?)?.length ?? 0;
                          if (unreadCount == 0) return SizedBox();

                          return Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
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
                                '$unreadCount',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.2),
                  child: Stack(
                    children: [
                      IconButton(
                        icon: Icon(Icons.shopping_cart_outlined,
                            color: Colors.white),
                        onPressed: () {
                          if (supabase.auth.currentUser == null) {
                            Get.toNamed('/login');
                          } else {
                            Get.to(() => CartScreen());
                          }
                        },
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
                      onPressed: () {
                        if (supabase.auth.currentUser == null) {
                          Get.toNamed('/login');
                        } else {
                          Get.to(() => ChatScreen());
                        }
                      },
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
                  icon: Icons.food_bank_outlined,
                  label: 'Makanan',
                  subCategories: [
                    'Makanan Instan',
                    'Minuman Kemasan',
                    'Makanan Camilan & Snack',
                    'Bahan Makanan',
                    'Makanan Hotel'
                  ],
                  onTap: () {
                    if (productController.currentCategory.value ==
                      'Makanan') {
                    productController.currentCategory.value = '';
                    productController.fetchProducts();
                    } else {
                    productController.currentCategory.value = 'Makanan';
                    productController.filterByMainCategory([
                      'Makanan Instan',
                      'Minuman Kemasan',
                      'Makanan Camilan & Snack',
                      'Bahan Makanan',
                      'Makanan Hotel'
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
                    icon: Icons.local_shipping_outlined,
                    label: 'Kirim Barang',
                    subCategories: [],
                    onTap: () {
                    if (supabase.auth.currentUser == null) {
                      // Tampilkan dialog login dengan tampilan lebih menarik
                      showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                        children: [
                          Icon(Icons.lock_outline, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text(
                          'Login Diperlukan',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          ),
                        ],
                        ),
                        content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.local_shipping_outlined,
                            size: 48, color: AppTheme.primary),
                          SizedBox(height: 12),
                          Text(
                          'Silakan login dahulu untuk menggunakan fitur Kirim Barang.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                          ),
                        ],
                        ),
                        actionsAlignment: MainAxisAlignment.spaceBetween,
                        actions: [
                        TextButton(
                          style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textHint,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Batal'),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          foregroundColor: Colors.white, // icon & text color
                          ),
                          icon: Icon(Icons.login, size: 18, color: Colors.white),
                          label: Text('Login', style: TextStyle(color: Colors.white)),
                          onPressed: () {
                          Navigator.of(context).pop();
                          Get.toNamed('/login');
                          },
                        ),
                        ],
                      ),
                      );
                    } else {
                      Get.to(() => KirimBarangScreen());
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Produk Terlaris',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                  Obx(() {
                    if (productController.isLoading.value) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (productController.products.isEmpty) {
                      return Center(child: Text('Tidak ada produk'));
                    }

                    // Sort products by sales in descending order
                    final sortedProducts = List.from(productController.products)
                      ..sort((a, b) =>
                          (b['sales'] ?? 0).compareTo(a['sales'] ?? 0));

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: sortedProducts.length,
                      itemBuilder: (context, index) {
                        final product = sortedProducts[index];
                        return ProductCard(product: product);
                      },
                    );
                  }),
                ],
              ),
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
          productController.currentCategory.value.toLowerCase() ==
              label.toLowerCase();

      return GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeInOut,
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
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  icon,
                  key: ValueKey<bool>(isSelected),
                  size: 30,
                  color: isSelected ? Colors.white : AppTheme.primary,
                ),
              ),
            ),
            SizedBox(height: 8),
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
      'Makanan Camilan & Snack',
      'Bahan Makanan',
      'Makanan Hotel',
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
