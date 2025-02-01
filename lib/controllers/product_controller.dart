import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxBool isLoading = false.obs;
  final RxList products = [].obs;
  final RxString selectedCategory = ''.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      isLoading.value = true;

      var query =
          _supabase.from('products').select('*, users!inner(full_name)');

      if (selectedCategory.isNotEmpty) {
        query = query.eq('category', selectedCategory.value);
      }

      if (searchQuery.isNotEmpty) {
        query = query.ilike('name', '%${searchQuery.value}%');
      }

      final response = await query;
      products.value = response;
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat produk: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void filterByCategory(String? category) {
    selectedCategory.value = category ?? '';
    fetchProducts();
  }

  void searchProducts(String query) {
    searchQuery.value = query;
    fetchProducts();
  }
}
