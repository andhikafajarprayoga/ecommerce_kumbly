import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxBool isLoading = false.obs;
  final RxList orders = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchOrders(); // Ambil pesanan saat controller diinisialisasi
  }

  Future<void> fetchOrders() async {
    try {
      isLoading.value = true;

      final userId = _supabase.auth.currentUser?.id; // Ambil userId dari auth
      if (userId == null) return; // Pastikan userId tidak null

      final response = await _supabase
          .from('orders')
          .select(
              '*, products(*)') // Ambil data dari tabel orders dan relasi ke products
          .eq('user_id', userId); // Filter berdasarkan userId

      orders.value = List<Map<String, dynamic>>.from(
          response); // Data langsung bisa digunakan
    } catch (e) {
      // Get.snackbar('Error', 'Gagal memuat pesanan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteOrder(int orderId) async {
    try {
      isLoading.value = true;
      await _supabase.from('orders').delete().eq('id', orderId);
      orders.removeWhere(
          (order) => order['id'] == orderId); // Hapus dari daftar lokal
      Get.snackbar('Sukses', 'Pesanan berhasil dihapus');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menghapus pesanan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateOrderStatus(int orderId, String newStatus) async {
    try {
      isLoading.value = true;

      await _supabase
          .from('orders')
          .update({'status': newStatus}).eq('id', orderId);
      // Update daftar lokal jika perlu
      final index = orders.indexWhere((order) => order['id'] == orderId);
      if (index != -1) {
        orders[index]['status'] = newStatus; // Update status di daftar lokal
      }

      Get.snackbar('Sukses', 'Status pesanan berhasil diperbarui');
    } catch (e) {
      Get.snackbar('Error', 'Gagal memperbarui status pesanan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> createOrder(Map<String, dynamic> data) async {
    try {
      isLoading.value = true;

      // Simpan data pesanan ke database
      final response = await _supabase.from('orders').insert({
        'buyer_id': data['buyer_id'],
        // 'courier_id': data['courier_id'],
        'total_amount': data['total_amount'],
        'status': 'pending', // Status awal
        'shipping_address': data['shipping_address'],
      });

      // Ambil ID pesanan yang baru dibuat
      final orderId = response.data[0]['id'];

      // Simpan detail item pesanan jika diperlukan
      for (var item in data['items']) {
        await _supabase.from('order_items').insert({
          'order_id': orderId, // Gunakan orderId yang baru dibuat
          'product_id': item['product_id'],
          'quantity': item['quantity'],
        });
      }

      Get.snackbar('Sukses', 'Pesanan berhasil dibuat!');
    } catch (e) {
      print('Error creating order: $e'); // Log error
      Get.snackbar('Error', 'Gagal membuat pesanan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<String> fetchUserAddress(String userId) async {
    try {
      final response = await _supabase
          .from('users')
          .select('address') // Ambil kolom address
          .eq('id', userId) // Filter berdasarkan userId
          .single(); // Ambil satu data

      return response['address'] ??
          'Alamat tidak tersedia'; // Kembalikan alamat atau pesan default
    } catch (e) {
      print('Error fetching user address: $e');
      return 'Alamat tidak tersedia'; // Kembalikan pesan default jika terjadi kesalahan
    }
  }
}
