import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/cart_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../cart/cart_screen.dart';
import '../chat/chat_detail_screen.dart';
import '../checkout/checkout_screen.dart';
import 'dart:convert';
import '../../../controllers/product_controller.dart';
import '../find/find_screen.dart';
import '../store/store_detail_screen.dart';
import '../profile/alamat_screen.dart';
import 'package:share_plus/share_plus.dart';

class ProductDetailScreen extends StatefulWidget {
  final dynamic product;
  ProductDetailScreen({super.key, required this.product}) {
    Get.put(CartController());
    if (!Get.isRegistered<ProductController>()) {
      Get.put(ProductController());
    }
  }

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class ProductDetailController extends GetxController {
  final showSearch = false.obs;
  late final ProductController productController;
  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    productController = Get.find<ProductController>();
  }

  void updateSearchVisibility(double offset) {
    showSearch.value = offset > 200;
  }

  void performSearch(String value) {
    if (value.isEmpty) return;

    // Navigasi ke FindScreen dengan query baru sebagai String
    Get.off(() => FindScreen(),
        arguments: value, // Kirim value sebagai String untuk query pencarian
        preventDuplicates: false);
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductDetailController controller = Get.put(ProductDetailController());
  final CartController cartController = Get.put(CartController());
  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      controller.updateSearchVisibility(_scrollController.offset);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Parse image URLs
    List<String> imageUrls = [];
    if (widget.product['image_url'] != null) {
      try {
        if (widget.product['image_url'] is List) {
          imageUrls = List<String>.from(widget.product['image_url']);
        } else if (widget.product['image_url'] is String) {
          final List<dynamic> urls = json.decode(widget.product['image_url']);
          imageUrls = List<String>.from(urls);
        }
      } catch (e) {
        print('Error parsing image URLs: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title:
            const Text('Detail Produk', style: TextStyle(color: Colors.white)),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.shopping_cart, color: Colors.white),
                onPressed: () => Get.to(() => CartScreen()),
              ),
              Obx(() => cartController.cartItems.isNotEmpty
                  ? Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 0, 0, 0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 1.5),
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
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gambar Produk dengan Slider
                Container(
                  height: 300,
                  child: Stack(
                    children: [
                      PageView.builder(
                        itemCount: imageUrls.isEmpty ? 1 : imageUrls.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (imageUrls.isNotEmpty) {
                                    showDialog(
                                      context: context,
                                      builder: (_) => Dialog(
                                        backgroundColor: Colors.black,
                                        insetPadding: EdgeInsets.zero,
                                        child: Stack(
                                            children: [
                                            // PageView untuk geser foto
                                            PageView.builder(
                                              itemCount: imageUrls.length,
                                              controller: PageController(initialPage: index),
                                              itemBuilder: (context, pageIndex) {
                                              return InteractiveViewer(
                                                minScale: 1,
                                                maxScale: 5,
                                                child: Center(
                                                child: Image.network(
                                                  imageUrls[pageIndex],
                                                  fit: BoxFit.contain,
                                                ),
                                                ),
                                              );
                                              },
                                            ),
                                            // Indikator halaman (jika lebih dari 1 foto)
                                            if (imageUrls.length > 1)
                                              Positioned(
                                              top: 50,
                                              left: 0,
                                              right: 0,
                                              child: Center(
                                                child: Container(
                                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withOpacity(0.7),
                                                  borderRadius: BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  '${index + 1} / ${imageUrls.length}',
                                                  style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                ),
                                              ),
                                              ),
                                            // Tombol close
                                            Positioned(
                                              top: 24,
                                              right: 24,
                                              child: IconButton(
                                              icon: Icon(Icons.close, color: Colors.white, size: 32),
                                              onPressed: () => Navigator.of(context).pop(),
                                              ),
                                            ),
                                            // Bottom card dengan info produk dan tombol
                                            // Icon toko yang bisa di klik
                                            Positioned(
                                              bottom: 250, // dinaikkan dari 190 ke 250
                                              right: 24,
                                              child: GestureDetector(
                                              onTap: () async {
                                              // Ambil data merchant
                                              final merchant = await supabase
                                                .from('merchants')
                                                .select()
                                                .eq('id', widget.product['seller_id'])
                                                .single();
                                              Get.to(() => StoreDetailScreen(
                                                merchant: Map<String, dynamic>.from(merchant),
                                                ));
                                              },
                                              child: Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                color: Colors.black.withOpacity(0.08),
                                                blurRadius: 8,
                                                ),
                                              ],
                                              ),
                                              child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                Icons.store,
                                                color: AppTheme.primary,
                                                size: 26,
                                                ),
                                                SizedBox(height: 1),
                                                Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                color: AppTheme.primary.withOpacity(0.12),
                                                borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                'Toko',
                                                style: TextStyle(
                                                fontSize: 10,
                                                color: AppTheme.primary,
                                                fontWeight: FontWeight.w500,
                                                ),
                                                ),
                                                ),
                                              ],
                                              ),
                                              ),
                                              ),
                                            ),
                                            // Tombol share di bawah icon toko
                                            Positioned(
                                              bottom: 180, // dinaikkan dari 140 ke 200
                                              right: 30,
                                              child: GestureDetector(
                                                onTap: () async {
                                                  final String productName = widget.product['name'];
                                                  final String productDescription = widget.product['description'] ?? '';
                                                  final String productUrl =
                                                      'https://play.google.com/store/apps/details?id=com.saraja.kumblyecommerce.v2.app&referrer=productId%3D${widget.product['id']}';
                                                  final String shareContent =
                                                      'Cek produk ini: $productName\n\n$productDescription\n\n$productUrl';
                                                  try {
                                                    await Share.share(
                                                      shareContent,
                                                      subject: 'Produk Menarik dari Saraja',
                                                    );
                                                  } catch (e) {
                                                    Get.snackbar(
                                                      'Gagal Membagikan',
                                                      'Tidak dapat membagikan produk saat ini',
                                                      backgroundColor: Colors.red,
                                                      colorText: Colors.white,
                                                    );
                                                  }
                                                },
                                                child: Column(
                                                  children: [
                                                    Container(
                                                      padding: EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withOpacity(0.08),
                                                            blurRadius: 8,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Transform.rotate(
                                                        angle: -0.5, // sedikit miring seperti ikon di gambar
                                                        child: Icon(
                                                          Icons.send, // lebih mirip ikon share di gambar
                                                          color: AppTheme.primary,
                                                          size: 26,
                                                        ),
                                                      ),
                                                    ),
                                                    SizedBox(height: 2),
                                                    Text(
                                                      'Bagikan',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w500,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Positioned(
                                              // Ubah bottom ke lebih atas, misal 80 dari bawah
                                              bottom: 90,
                                              left: 16,
                                              right: 16,
                                              child: Container(
                                              padding: EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.08),
                                                blurRadius: 10,
                                              ),
                                              ],
                                              ),
                                              child: SafeArea(
                                                top: false,
                                                child: Row(
                                                children: [
                                                  // Info produk
                                                  Expanded(
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                    Text(
                                                      'Rp ${NumberFormat('#,###').format(widget.product['price'])}',
                                                      style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppTheme.primary,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      widget.product['name'],
                                                      style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.black87,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    ],
                                                  ),
                                                  ),
                                                  SizedBox(width: 16),
                                                  // Tombol actions
                                                  Row(
                                                  children: [
                                                    // Tombol keranjang
                                                    IconButton(
                                                    onPressed: widget.product['stock'] == 0
                                                      ? null
                                                      : () {
                                                        final userId = supabase.auth.currentUser?.id;
                                                        if (userId == null) {
                                                          Get.toNamed('/login');
                                                          return;
                                                        }
                                                        cartController.addToCart(widget.product);
                                                        Get.snackbar(
                                                          'Sukses',
                                                          'Produk ditambahkan ke keranjang',
                                                          snackPosition: SnackPosition.TOP,
                                                          backgroundColor: Colors.green,
                                                          colorText: Colors.white,
                                                          duration: Duration(seconds: 2),
                                                        );
                                                        },
                                                    icon: Icon(Icons.shopping_cart_outlined, color: Colors.grey[600]),
                                                    ),
                                                    SizedBox(width: 8),
                                                    
                                                    SizedBox(width: 8),
                                                    // Tombol beli sekarang
                                                    ElevatedButton(
                                                    onPressed: widget.product['stock'] == 0
                                                      ? null
                                                      : () => handleCheckout(),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppTheme.primary,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                    ),
                                                    child: Text(
                                                      'Beli Sekarang',
                                                      style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      ),
                                                    ),
                                                    ),
                                                  ],
                                                  ),
                                                ],
                                                ),
                                              ),
                                              ),
                                            ),
                                            ],
                                          
                                        ),
                                      ),
                                    );
                                  
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    image: DecorationImage(
                                      image: NetworkImage(
                                        imageUrls.isEmpty
                                            ? 'https://via.placeholder.com/300'
                                            : imageUrls[index],
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                              if (widget.product['stock'] == 0)
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.7),
                                        Colors.black.withOpacity(0.5),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.block,
                                          color: Colors.white,
                                          size: 50,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'Stok Habis',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      if (imageUrls.length > 1)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentImageIndex + 1}/${imageUrls.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Informasi Produk
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nama dan Harga
                      Text(
                        widget.product['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rp ${NumberFormat('#,###').format(widget.product['price'])}',
                            style: TextStyle(
                              fontSize: 18,
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              // Tombol share yang baru
                              InkWell(
                                onTap: () async {
                                  final String productName =
                                      widget.product['name'];
                                  final String productDescription =
                                      widget.product['description'] ?? '';
                                  final String productUrl =
                                      'https://play.google.com/store/apps/details?id=com.saraja.kumblyecommerce.v2.app&referrer=productId%3D${widget.product['id']}';
                                  final String shareContent =
                                      'Cek produk ini: $productName\n\n$productDescription\n\n$productUrl';
                                  try {
                                    await Share.share(
                                      shareContent,
                                      subject: 'Produk Menarik dari Saraja',
                                    );
                                  } catch (e) {
                                    print('Error sharing: $e');
                                    Get.snackbar(
                                      'Gagal Membagikan',
                                      'Tidak dapat membagikan produk saat ini',
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                    );
                                  }
                                },
                                child: Container(
                                  padding: EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.share,
                                      size: 20, color: AppTheme.primary),
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.shopping_bag_outlined, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Terjual ${widget.product['sales'] ?? 0}',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Stok
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors
                              .grey[100], // Changed to standard light gray
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_outlined,
                                color: AppTheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Stok: ${widget.product['stock']}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Deskripsi
                      Text(
                        'Deskripsi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.product['description'] ?? 'Tidak ada deskripsi',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Informasi Toko
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Informasi Penjual',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            FutureBuilder(
                              future: supabase
                                  .from('merchants')
                                  .select()
                                  .eq('id', widget.product['seller_id'])
                                  .single(),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final merchant = snapshot.data as Map;
                                  return InkWell(
                                    onTap: () {
                                      Get.to(() => StoreDetailScreen(
                                            merchant: merchant
                                                as Map<String, dynamic>,
                                          ));
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.store,
                                                    color: AppTheme.primary),
                                                SizedBox(width: 8),
                                                Text(
                                                  merchant['store_name'] ??
                                                      'Nama Toko',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Icon(Icons.chevron_right,
                                                color: Colors.grey, size: 20),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.location_on,
                                                color: AppTheme.primary),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Builder(
                                                builder: (context) {
                                                  try {
                                                    final addressData =
                                                        jsonDecode(merchant[
                                                                'store_address'] ??
                                                            '{}');
                                                    return Text(
                                                      '${addressData['street']}, ${addressData['village']}, ${addressData['district']}, ${addressData['city']}, ${addressData['province']} ${addressData['postal_code']}',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    );
                                                  } catch (e) {
                                                    return Text(
                                                      'Alamat tidak valid',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return CircularProgressIndicator();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Ubah judul dari "Produk Serupa" menjadi "Produk Lainnya dari Toko Ini"
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Produk Lainnya dari Toko Ini',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchMerchantProducts(widget.product['seller_id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Tidak ada produk lain dari toko ini'),
                      );
                    }

                    return Container(
                      height: 220,
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final product = snapshot.data![index];
                          return InkWell(
                            onTap: () {
                              Get.to(
                                () => ProductDetailScreen(product: product),
                                preventDuplicates: false,
                              );
                            },
                            child: Container(
                              width: 140,
                              margin: EdgeInsets.only(right: 12),
                              child: Card(
                                elevation: 0.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Gambar Produk
                                    ClipRRect(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(8)),
                                      child: Image.network(
                                        _getFirstImageUrl(product),
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Container(
                                            height: 120,
                                            color: Colors.grey[200],
                                            child: Icon(Icons.error_outline),
                                          );
                                        },
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product['name'],
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 12),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Rp ${NumberFormat('#,###').format(product['price'])}',
                                            style: TextStyle(
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.shopping_bag_outlined,
                                                  size: 12, color: Colors.grey),
                                              SizedBox(width: 4),
                                              Text(
                                                'Terjual ${product['sales'] ?? 0}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
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
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Tambahkan bagian Produk Serupa
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Produk Serupa',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchSimilarProducts(
                      widget.product['category'], widget.product['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Tidak ada produk serupa'),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final product = snapshot.data![index];
                          return InkWell(
                            onTap: () {
                              Get.to(
                                () => ProductDetailScreen(product: product),
                                preventDuplicates: false,
                              );
                            },
                            child: Card(
                              elevation: 0.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(8)),
                                    child: Image.network(
                                      _getFirstImageUrl(product),
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          height: 150,
                                          color: Colors.grey[200],
                                          child: Icon(Icons.error_outline),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name'],
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Rp ${NumberFormat('#,###').format(product['price'])}',
                                          style: TextStyle(
                                            color: AppTheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.shopping_bag_outlined,
                                                size: 12, color: Colors.grey),
                                            SizedBox(width: 4),
                                            Text(
                                              'Terjual ${product['sales'] ?? 0}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
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
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
          Obx(
            () => controller.showSearch.value
                ? Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: Colors.white,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: controller.searchController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            hintText: 'Produk lain?',
                            hintStyle: TextStyle(
                                fontSize: 13, color: AppTheme.textHint),
                            suffixIcon: IconButton(
                              icon:
                                  Icon(Icons.search, color: AppTheme.textHint),
                              onPressed: () => controller.performSearch(
                                  controller.searchController.text),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 16),
                          ),
                          onSubmitted: controller.performSearch,
                        ),
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Tombol Chat
            Container(
              width: 35,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
                icon: Icon(Icons.chat_bubble_outline, size: 28),
                onPressed: _startChat,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            // Tombol Keranjang
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: widget.product['stock'] == 0
                      ? null
                      : () {
                          final userId = supabase.auth.currentUser?.id;
                          if (userId == null) {
                            Get.toNamed('/login');
                            return;
                          }
                          cartController.addToCart(widget.product);
                          Get.snackbar(
                            'Sukses',
                            'Produk ditambahkan ke keranjang',
                            snackPosition: SnackPosition.TOP,
                            backgroundColor: Colors.green,
                            colorText: Colors.white,
                            duration: Duration(seconds: 2),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: AppTheme.primary),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    widget.product['stock'] == 0 ? 'Stok Habis' : 'Keranjang',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Tombol Beli Langsung
            Expanded(
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed:
                      widget.product['stock'] == 0 ? null : handleCheckout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(
                    widget.product['stock'] == 0
                        ? 'Stok Habis'
                        : 'Beli Langsung',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchMerchantProducts(
      String sellerId) async {
    final response = await supabase
        .from('products')
        .select()
        .eq('seller_id', sellerId)
        .neq('id', widget.product['id'])
        .order('sales', ascending: false)
        .limit(5);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _startChat() async {
    final buyerId = supabase.auth.currentUser?.id;
    if (buyerId == null) {
      Get.toNamed('/login');
      return;
    }

    // Cek apakah chat room sudah ada
    final existingRoom = await supabase
        .from('chat_rooms')
        .select()
        .eq('buyer_id', buyerId)
        .eq('seller_id', widget.product['seller_id'])
        .maybeSingle();

    Map<String, dynamic> chatRoom;
    Map<String, dynamic> seller;

    if (existingRoom != null) {
      chatRoom = existingRoom;
    } else {
      // Buat chat room baru
      final response = await supabase
          .from('chat_rooms')
          .insert({
            'buyer_id': buyerId,
            'seller_id': widget.product['seller_id'],
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      chatRoom = response;
    }

    // Dapatkan info seller
    seller = await supabase
        .from('merchants')
        .select()
        .eq('id', widget.product['seller_id'])
        .single();

    // Navigasi ke chat detail dengan data produk untuk konfirmasi
    Get.to(
        () => ChatDetailScreen(
              chatRoom: chatRoom,
              seller: seller,
            ),
        arguments: {'productToSend': widget.product});
  }

  void handleCheckout() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      Get.toNamed('/login');
      return;
    }

    try {
      // Ambil alamat user
      final userResponse = await supabase
          .from('users')
          .select('address, address2, address3, address4')
          .eq('id', userId)
          .single();

      // Cek apakah user memiliki alamat
      bool hasAddress = userResponse['address'] != null ||
          userResponse['address2'] != null ||
          userResponse['address3'] != null ||
          userResponse['address4'] != null;

      if (!hasAddress) {
        // Tampilkan dialog untuk menambahkan alamat
        Get.dialog(
          AlertDialog(
            title: Text('Alamat Pengiriman'),
            content: Text(
                'Anda belum memiliki alamat pengiriman. Tambahkan alamat terlebih dahulu untuk melanjutkan pembelian.'),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('Batal'),
              ),
              ElevatedButton(
                onPressed: () {
                  Get.back(); // Tutup dialog
                  Get.to(() => AlamatScreen())
                      ?.then((value) => handleCheckout());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
                child: Text('Tambah Alamat',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return;
      }

      // Ambil data merchant
      final merchantResponse = await supabase
          .from('merchants')
          .select()
          .eq('id', widget.product['seller_id'])
          .single();

      // Gunakan alamat pertama yang tersedia
      Map<String, dynamic>? selectedAddress;
      if (userResponse['address4'] != null) {
        selectedAddress = userResponse['address4'];
      } else if (userResponse['address'] != null) {
        selectedAddress = userResponse['address'];
      } else if (userResponse['address2'] != null) {
        selectedAddress = userResponse['address2'];
      } else if (userResponse['address3'] != null) {
        selectedAddress = userResponse['address3'];
      }

      // Format alamat
      final formattedAddress = '${selectedAddress!['street']}, '
          '${selectedAddress['village']}, '
          '${selectedAddress['district']}, '
          '${selectedAddress['city']}, '
          '${selectedAddress['province']}, '
          '${selectedAddress['postal_code']}';

      // Konversi product ke Map<String, dynamic>
      final productData = Map<String, dynamic>.from(widget.product);

      // Format data untuk checkout
      final checkoutData = {
        'items': [
          {
            'products': {
              ...productData,
              'seller_id': widget.product['seller_id'],
              'merchant': Map<String, dynamic>.from(merchantResponse),
            },
            'quantity': 1,
          }
        ],
        'total_amount': widget.product['price'],
        'buyer_id': userId,
        'status': 'pending',
        'shipping_address': formattedAddress,
        'payment_method': null,
        'shipping_cost': 0,
        'admin_fee': 0,
      };

      // Navigasi ke CheckoutScreen
      Get.to(() => CheckoutScreen(data: checkoutData));
    } catch (e) {
      Get.snackbar(
        'Error',
        'Terjadi kesalahan. Silakan coba lagi.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

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

  // Tambahkan fungsi untuk mengambil produk serupa
  Future<List<Map<String, dynamic>>> _fetchSimilarProducts(
      String category, String currentProductId) async {
    final response = await supabase
        .from('products')
        .select()
        .eq('category', category)
        .neq('id', currentProductId)
        .order('sales', ascending: false)
        .limit(6);

    return List<Map<String, dynamic>>.from(response);
  }
}

String formatTimestamp(DateTime timestamp) {
  final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss',
      'id_ID'); // Format waktu dengan zona waktu Indonesia
  return dateFormat.format(timestamp);
}
