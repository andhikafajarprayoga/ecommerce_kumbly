import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartController extends GetxController {
  final supabase = Supabase.instance.client;
  final cartItems = <Map<String, dynamic>>[].obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchCartItems();
  }

  // Mengambil data keranjang dari database
  Future<void> fetchCartItems() async {
    try {
      isLoading(true);
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('cart_items')
          .select('*, products(*)')
          .eq('user_id', userId);

      cartItems.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching cart items: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat keranjang belanja',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading(false);
    }
  }

  // Menambahkan produk ke keranjang
  Future<void> addToCart(Map<String, dynamic> product) async {
    try {
      isLoading(true);
      final userId = supabase.auth.currentUser!.id;

      // Cek apakah produk sudah ada di keranjang
      final existingItem = cartItems
          .firstWhereOrNull((item) => item['product_id'] == product['id']);

      if (existingItem != null) {
        // Update quantity jika produk sudah ada
        await supabase
            .from('cart_items')
            .update({'quantity': existingItem['quantity'] + 1}).eq(
                'id', existingItem['id']);
      } else {
        // Tambah produk baru ke keranjang
        await supabase.from('cart_items').insert({
          'user_id': userId,
          'product_id': product['id'],
          'quantity': 1,
        });
      }

      // Refresh keranjang
      await fetchCartItems();
    } catch (e) {
      print('Error adding to cart: $e');
      Get.snackbar(
        'Error',
        'Gagal menambahkan ke keranjang',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading(false);
    }
  }

  // Update quantity produk di keranjang
  Future<void> updateQuantity(int cartItemId, int quantity) async {
    try {
      if (quantity < 1) return;

      isLoading(true);
      await supabase
          .from('cart_items')
          .update({'quantity': quantity}).eq('id', cartItemId);

      await fetchCartItems();
    } catch (e) {
      print('Error updating quantity: $e');
      Get.snackbar(
        'Error',
        'Gagal mengupdate jumlah produk',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading(false);
    }
  }

  // Menghapus produk dari keranjang
  Future<void> removeFromCart(int cartItemId) async {
    try {
      isLoading(true);
      await supabase.from('cart_items').delete().eq('id', cartItemId);

      await fetchCartItems();

      Get.snackbar(
        'Sukses',
        'Produk dihapus dari keranjang',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      print('Error removing from cart: $e');
      Get.snackbar(
        'Error',
        'Gagal menghapus produk',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading(false);
    }
  }

  // Menghitung total harga keranjang
  double get totalPrice {
    return cartItems.fold(0, (sum, item) {
      return sum + (item['products']['price'] * item['quantity']);
    });
  }

  // Menghitung total item di keranjang
  int get totalItems {
    return cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }

  // Mengosongkan keranjang
  Future<void> clearCart() async {
    try {
      isLoading(true);
      final userId = supabase.auth.currentUser!.id;

      await supabase.from('cart_items').delete().eq('user_id', userId);

      cartItems.clear();
    } catch (e) {
      print('Error clearing cart: $e');
      Get.snackbar(
        'Error',
        'Gagal mengosongkan keranjang',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading(false);
    }
  }
}
