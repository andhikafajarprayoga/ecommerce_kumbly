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

      final response = await _supabase
          .from('orders')
          .select('*'); // Tidak perlu menggunakan .execute()

      orders.value = response; // Data langsung bisa digunakan
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat pesanan: $e');
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
}
