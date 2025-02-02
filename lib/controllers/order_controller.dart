import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

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
          .select('*') // Ambil semua kolom dari tabel orders
          .eq('buyer_id', userId); // Filter berdasarkan userId

      if (response != null) {
        orders.value = response; // Simpan data pesanan
      } else {
        Get.snackbar('Error', 'Gagal memuat pesanan');
      }
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

  Future<void> createOrder(Map<String, dynamic> orderData) async {
    try {
      isLoading(true);

      // Buat order baru
      final orderResponse = await _supabase
          .from('orders')
          .insert({
            'buyer_id': orderData['buyer_id'],
            'total_amount': orderData['total_amount'],
            'shipping_address': orderData['shipping_address'],
            'payment_method_id':
                int.parse(orderData['payment_method_id']), // Convert ke int
            'status': 'pending'
          })
          .select()
          .single();

      // Masukkan semua item ke order_items
      final items = orderData['items'] as List;
      for (var item in items) {
        await _supabase.from('order_items').insert({
          'order_id': orderResponse['id'],
          'product_id': item['product_id'],
          'quantity': item['quantity'],
          'price': item['products']['price'],
        });
      }

      Get.snackbar(
        'Sukses',
        'Pesanan berhasil dibuat',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error creating order: $e');
      Get.snackbar(
        'Error',
        'Gagal membuat pesanan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
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

  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      final response = await _supabase
          .from('orders') // Ganti dengan nama tabel yang sesuai
          .select()
          .eq('id', orderId)
          .single(); // Ambil satu data

      return Map<String, dynamic>.from(response); // Kembalikan data sebagai Map
    } catch (e) {
      print('Error fetching order details: $e');
      throw e; // Lempar kembali kesalahan untuk ditangani di tempat lain
    }
  }
}
