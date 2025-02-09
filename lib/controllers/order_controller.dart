import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxBool isLoading = false.obs;
  final RxList orders = <dynamic>[].obs;
  final RxList hotelBookings = <Map<String, dynamic>>[].obs;
  final RxBool isLoadingHotel = false.obs;
  final orderss = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchOrders(); // Ambil pesanan saat controller diinisialisasi
  }

  void updateOrder(Map<String, dynamic> updatedOrder) {
    final index = orderss.indexWhere((o) => o['id'] == updatedOrder['id']);
    if (index != -1) {
      orderss[index] = updatedOrder;
    }
  }

  Future<void> fetchOrders() async {
    try {
      isLoading.value = true;
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase.from('orders').select('''
            id,
            status,
            total_amount,
            shipping_address,
            shipping_cost,
            created_at,
            payment_group_id,
            order_items!left (
              id,
              quantity,
              price,
              product_id,
              products (
                id,
                name,
                image_url
              )
            ),
            payment_groups!left (
              id,
              payment_status,
              payment_proof,
              payment_method_id,
              total_amount,
              admin_fee,
              total_shipping_cost
            )
          ''').eq('buyer_id', userId).order('created_at', ascending: false);

      print('Orders with payment groups: $response'); // Debug print
      orders.assignAll(response);
    } catch (e) {
      print('Error fetching orders: $e');
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

  void filterOrders(String status) {
    if (status == 'all') {
      fetchOrders();
    } else {
      final filtered =
          orders.where((order) => order['status'] == status).toList();
      orders.assignAll(filtered);
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
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not logged in');

      // Siapkan data pesanan sesuai struktur tabel yang benar
      final orderPayload = {
        'buyer_id': userId,
        'payment_method_id': orderData['payment_method_id'],
        'shipping_address': orderData['shipping_address'],
        'total_amount': orderData['total_amount'],
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      };

      // Insert ke tabel orders
      final orderResponse = await _supabase
          .from('orders')
          .insert(orderPayload)
          .select('id')
          .single();

      final orderId = orderResponse['id'];

      // Insert order items
      final orderItems = orderData['items']
          .map((item) => {
                'order_id': orderId,
                'product_id': item['products']['id'],
                'quantity': item['quantity'],
                'price': item['products']['price'],
              })
          .toList();

      await _supabase.from('order_items').insert(orderItems);

      print('Order created successfully with ID: $orderId');
    } catch (e) {
      print('Error creating order: $e');
      throw e;
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

  Future<void> createSeparateOrders(
      Map<String, dynamic> cartData, double adminFee) async {
    try {
      isLoading(true);

      // 1. Kelompokkan items berdasarkan merchant
      Map<String, List<Map<String, dynamic>>> itemsByMerchant = {};
      double totalAmount = 0;

      for (var item in cartData['items']) {
        String merchantId = item['products']['seller_id'];
        if (!itemsByMerchant.containsKey(merchantId)) {
          itemsByMerchant[merchantId] = [];
        }
        itemsByMerchant[merchantId]!.add(item);

        // Hitung total amount
        totalAmount += (item['products']['price'] * item['quantity']);
      }

      // 2. Buat payment group untuk menampung total pembayaran
      final paymentGroupResponse = await _supabase
          .from('payment_groups')
          .insert({
            'buyer_id': _supabase.auth.currentUser!.id,
            'total_amount': totalAmount,
            'admin_fee': adminFee,
            'payment_method_id': cartData['payment_method_id'],
            'payment_status': 'pending'
          })
          .select()
          .single();

      final paymentGroupId = paymentGroupResponse['id'];

      // 3. Buat order untuk setiap merchant
      for (var merchantId in itemsByMerchant.keys) {
        var merchantItems = itemsByMerchant[merchantId]!;

        // Hitung total untuk merchant ini
        double merchantTotal = merchantItems.fold(
            0.0,
            (sum, item) =>
                sum + (item['products']['price'] * item['quantity']));

        // Buat order baru untuk merchant ini
        final orderResponse = await _supabase
            .from('orders')
            .insert({
              'buyer_id': _supabase.auth.currentUser!.id,
              'merchant_id': merchantId,
              'status': 'pending',
              'total_amount': merchantTotal,
              'shipping_address': cartData['shipping_address'],
              'payment_method_id': cartData['payment_method_id'],
              'payment_group_id': paymentGroupId
            })
            .select()
            .single();

        final orderId = orderResponse['id'];

        // 4. Masukkan items ke order_items
        for (var item in merchantItems) {
          await _supabase.from('order_items').insert({
            'order_id': orderId,
            'product_id': item['product_id'],
            'quantity': item['quantity'],
            'price': item['products']['price']
          });
        }
      }

      Get.snackbar(
        'Sukses',
        'Pesanan berhasil dibuat',
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      print('Error creating orders: $e');
      Get.snackbar(
        'Error',
        'Gagal membuat pesanan',
        snackPosition: SnackPosition.TOP,
      );
      throw e;
    } finally {
      isLoading(false);
    }
  }

  Future<void> fetchHotelBookings() async {
    try {
      isLoadingHotel.value = true;
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase.from('hotel_bookings').select('''
            *,
            hotels (
              name
            )
          ''').eq('user_id', userId).order('created_at', ascending: false);

      hotelBookings.assignAll(response);
    } catch (e) {
      print('Error fetching hotel bookings: $e');
    } finally {
      isLoadingHotel.value = false;
    }
  }

  void filterHotelBookings(String status) {
    if (status == 'all') {
      fetchHotelBookings();
    } else {
      final filtered = hotelBookings
          .where((booking) => booking['status'] == status)
          .toList();
      hotelBookings.assignAll(filtered);
    }
  }
}
