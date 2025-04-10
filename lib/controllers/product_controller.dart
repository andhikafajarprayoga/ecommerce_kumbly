import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/widgets.dart';

class ProductController extends GetxController {
  final supabase = Supabase.instance.client;
  final products = <dynamic>[].obs;
  final isLoading = false.obs;
  final searchQuery = ''.obs;
  final selectedCategory = Rx<String?>(null);
  RxString currentCategory = ''.obs;
  Rx<double?> minPrice = Rx<double?>(null);
  Rx<double?> maxPrice = Rx<double?>(null);
  final RxList<dynamic> searchedMerchants = <dynamic>[].obs;
  RxList<Map<String, dynamic>> hotels = <Map<String, dynamic>>[].obs;
  List<Map<String, dynamic>> originalProducts = [];

  @override
  void onInit() {
    super.onInit();
    originalProducts =
        products.map((product) => Map<String, dynamic>.from(product)).toList();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      isLoading.value = true;
      final response = await supabase
          .from('products')
          .select()
          .order('created_at', ascending: false)
          .limit(20);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        products.assignAll(response);
      });
    } catch (e) {
      print('Error fetching products: $e');
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        isLoading.value = false;
      });
    }
  }

  Future<void> searchProducts(String query, {String? category}) async {
    if (query.isEmpty && category == null) {
      products.assignAll(originalProducts);
      return;
    }

    final filteredProducts = originalProducts.where((product) {
      final name = product['name']?.toString().toLowerCase() ?? '';
      final productCategory =
          product['category']?.toString().toLowerCase() ?? '';
      final description =
          product['description']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();

      bool matchesQuery = query.isEmpty ||
          name.contains(searchQuery) ||
          productCategory.contains(searchQuery) ||
          description.contains(searchQuery);

      bool matchesCategory =
          category == null || productCategory == category.toLowerCase();

      return matchesQuery && matchesCategory;
    }).toList();

    products.assignAll(filteredProducts);
  }

  void filterByCategory(String category) async {
    try {
      final response = await supabase
          .from('products')
          .select()
          .ilike('category', category)
          .order('created_at');

      products.value = List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error filtering by category: $e');
    }
  }

  Future<void> addProduct(
    String name,
    double price,
    int stock,
    String description,
    String category,
    String imageUrl,
  ) async {
    try {
      final userId = supabase.auth.currentUser!.id;
      await supabase.from('products').insert({
        'seller_id': userId,
        'name': name,
        'description': description,
        'price': price,
        'stock': stock,
        'category': category,
        'image_url': imageUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
      await fetchProducts();
    } catch (e) {
      print('Error adding product: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(
    String id,
    String name,
    double price,
    int stock,
    String description,
    String category,
    List<String> imageUrls,
    int weight,
    int length,
    int width,
    int height,
  ) async {
    await supabase.from('products').update({
      'name': name,
      'price': price,
      'stock': stock,
      'description': description,
      'category': category,
      'image_url': imageUrls,
      'weight': weight,
      'length': length,
      'width': width,
      'height': height,
    }).eq('id', id);
  }

  Future<void> deleteProduct(String productId) async {
    try {
      isLoading.value = true;
      await supabase
          .from('products')
          .delete()
          .eq('id', productId); // Gunakan String
      fetchProducts();
    } catch (e) {
      Get.snackbar('Error', 'Gagal menghapus produk: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Filter berdasarkan penjualan terbanyak
  void sortBySales() {
    products.sort((a, b) => (b['sales'] ?? 0).compareTo(a['sales'] ?? 0));
    products.refresh();
  }

  // Filter harga terendah ke tertinggi
  void sortByPriceAsc() {
    products.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
    products.refresh();
  }

  // Filter harga tertinggi ke terendah
  void sortByPriceDesc() {
    products.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
    products.refresh();
  }

  void filterByPrice(double? min, double? max) {
    minPrice.value = min;
    maxPrice.value = max;

    if (min == null && max == null) {
      fetchProducts(); // Reset filter
      return;
    }

    final filtered = products.where((product) {
      final price = double.tryParse(product['price'].toString()) ?? 0;
      bool matchesMin = min == null || price >= min;
      bool matchesMax = max == null || price <= max;
      return matchesMin && matchesMax;
    }).toList();

    products.value = filtered;
  }

  void filterByPriceRange(int minPrice, int maxPrice) {
    final filteredProducts = products.where((product) {
      final price = double.tryParse(product['price'].toString()) ?? 0;
      return price >= minPrice && price <= maxPrice;
    }).toList();

    products.value = filteredProducts;
  }

  void filterOtherCategories() async {
    try {
      // Fetch semua produk terlebih dahulu
      final response = await supabase
          .from('products')
          .select()
          .not('category', 'in', '(fashion,elektronik,aksesoris)')
          .order('created_at');

      products.value = List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      print('Error filtering other categories: $e');
    }
  }

  void filterByMainCategory(List<String> categories) async {
    try {
      isLoading.value = true;
      print('Filtering by categories: $categories'); // Debug print

      final response = await supabase
          .from('products')
          .select()
          .inFilter('category', categories); // Hapus pengecekan is_active

      print('Filter response: $response'); // Debug print
      print('Number of filtered products: ${response.length}'); // Debug print

      products.assignAll(response);
    } catch (e) {
      print('Error filtering products: $e'); // Debug print error
    } finally {
      isLoading.value = false;
    }
  }

  void updateProducts(List<Map<String, dynamic>> newProducts) {
    products.value = newProducts;
    isLoading.value = false;
  }
}
