import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductController extends GetxController {
  final supabase = Supabase.instance.client;
  final products = <dynamic>[].obs;
  final isLoading = false.obs;
  final searchQuery = ''.obs;
  final selectedCategory = Rx<String?>(null);

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      final response = await supabase
          .from('products')
          .select('*') // Ambil semua data products tanpa join dulu
          .order('created_at', ascending: false);

      if (response != null) {
        products.value = response;
      }
    } catch (e) {
      print('Error fetching products: $e');
    }
  }

  void searchProducts(String query) {
    searchQuery.value = query;
    if (query.isEmpty && selectedCategory.value == null) {
      fetchProducts();
      return;
    }

    final filteredProducts = products.where((product) {
      final matchesQuery = product['name']
          .toString()
          .toLowerCase()
          .contains(query.toLowerCase());
      final matchesCategory = selectedCategory.value == null ||
          product['category'] == selectedCategory.value;
      return matchesQuery && matchesCategory;
    }).toList();

    products.value = filteredProducts;
  }

  void filterByCategory(String? category) {
    selectedCategory.value = category;
    if (category == null && searchQuery.value.isEmpty) {
      fetchProducts();
      return;
    }

    final filteredProducts = products.where((product) {
      final matchesQuery = searchQuery.value.isEmpty ||
          product['name']
              .toString()
              .toLowerCase()
              .contains(searchQuery.value.toLowerCase());
      final matchesCategory =
          category == null || product['category'] == category;
      return matchesQuery && matchesCategory;
    }).toList();

    products.value = filteredProducts;
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

  Future<void> deleteProduct(int productId) async {
    try {
      isLoading.value = true;
      await supabase.from('products').delete().eq('id', productId);
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
}
