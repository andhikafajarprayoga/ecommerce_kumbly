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

class BuyerHomeScreen extends StatefulWidget {
  BuyerHomeScreen({super.key});

  @override
  _BuyerHomeScreenState createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  final ProductController productController = Get.put(ProductController());
  final AuthController authController = Get.find<AuthController>();
  int _selectedIndex = 0;
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    productController.fetchProducts();
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

  Widget _getScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return FindScreen();
      case 2:
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
                      onPressed: () {
                        final searchValue = searchController.text;
                        setState(() => _selectedIndex = 1);
                        productController.searchQuery.value = searchValue;
                        productController.searchProducts(searchValue);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  ),
                  onSubmitted: (value) {
                    setState(() => _selectedIndex = 1);
                    productController.searchQuery.value = value;
                    productController.searchProducts(value);
                  },
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.chat_outlined, color: Colors.white),
                  onPressed: () => Get.to(() => ChatScreen()),
                ),
                IconButton(
                  icon: Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  onPressed: () => Get.to(() => CartScreen()),
                ),
              ],
            )
          : null,
      body: _getScreen(),
      bottomNavigationBar: BottomNavigationBar(
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

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await productController.fetchProducts();
      },
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Banner Carousel
            Container(
              height: 210,
              child: PageView(
                scrollDirection: Axis.horizontal,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width *
                        0.90, // Adjusted width
                    margin:
                        EdgeInsets.symmetric(horizontal: 8), // Adjusted margin
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(2), // Adjusted border radius
                      image: DecorationImage(
                        image: AssetImage('images/1.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width *
                        0.90, // Adjusted width
                    margin:
                        EdgeInsets.symmetric(horizontal: 8), // Adjusted margin
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(2), // Adjusted border radius
                      image: DecorationImage(
                        image: AssetImage('images/2.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width *
                        0.90, // Adjusted width
                    margin:
                        EdgeInsets.symmetric(horizontal: 8), // Adjusted margin
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(2), // Adjusted border radius
                      image: DecorationImage(
                        image: AssetImage('images/3.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Categories
            Container(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kategori',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      CategoryIcon(
                        icon: Icons.checkroom_outlined,
                        label: 'Pakaian',
                        onTap: () =>
                            productController.filterByCategory('fashion'),
                      ),
                      CategoryIcon(
                        icon: Icons.phone_android_outlined,
                        label: 'Elektronik',
                        onTap: () =>
                            productController.filterByCategory('elektronik'),
                      ),
                      CategoryIcon(
                        icon: Icons.watch_outlined,
                        label: 'Aksesoris',
                        onTap: () =>
                            productController.filterByCategory('aksesoris'),
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
                    image: NetworkImage(product['image_url']),
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
                              return Text(
                                merchant['store_address'] ??
                                    'Alamat tidak tersedia',
                                style: Theme.of(context).textTheme.bodySmall,
                                overflow: TextOverflow.ellipsis,
                              );
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
