import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/active_delivery.dart';
import 'package:flutter/material.dart';

class ActiveDeliveryController extends GetxController {
  final _supabase = Supabase.instance.client;
  final RxList<ActiveDelivery> activeDeliveries = <ActiveDelivery>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchActiveDeliveries();
  }

  Future<void> fetchActiveDeliveries() async {
    isLoading.value = true;
    try {
      // Ambil semua orders dengan berbagai status
      final response =
          await _supabase.from('orders').select().inFilter('status', [
        'pending',
        'pending_cancellation',
        'processing',
        'shipping',
        'delivered',
        'cancelled',
        'completed'
      ]).order('created_at', ascending: false);

      print('Orders Response: $response');

      // Ambil data users (buyer dan merchant)
      final userIds = [
        ...response.map((r) => r['buyer_id'].toString()),
        ...response.map((r) => r['merchant_id'].toString()),
      ].toSet().toList();

      final usersResponse = await _supabase
          .from('users')
          .select('id, full_name')
          .inFilter('id', userIds);

      print('Users Response: $usersResponse');

      // Buat map untuk lookup user data
      final userMap = {
        for (var user in usersResponse) user['id'].toString(): user['full_name']
      };

      // Gabungkan data
      final enrichedResponse = response.map((order) {
        return {
          ...order,
          'buyer': {'full_name': userMap[order['buyer_id'].toString()]},
          'merchant': {'full_name': userMap[order['merchant_id'].toString()]},
        };
      }).toList();

      activeDeliveries.value = enrichedResponse
          .map<ActiveDelivery>((json) => ActiveDelivery.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching deliveries: $e');
      Get.snackbar('Error', 'Gagal memuat data pengiriman');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateDeliveryStatus(
      String orderId, String status, String? photoUrl) async {
    try {
      await _supabase.from('orders').update({
        'status': status,
        'courier_handover_photo': photoUrl,
      }).eq('id', orderId);

      fetchActiveDeliveries();
      Get.snackbar('Sukses', 'Status pengiriman berhasil diperbarui');
    } catch (e) {
      Get.snackbar('Error', 'Gagal memperbarui status');
    }
  }

  // Helper methods untuk memfilter deliveries berdasarkan status
  List<ActiveDelivery> getDeliveriesByStatus(String status) {
    return activeDeliveries.where((d) => d.status == status).toList();
  }

  List<ActiveDelivery> get pendingDeliveries =>
      getDeliveriesByStatus('pending');
  List<ActiveDelivery> get processingDeliveries =>
      getDeliveriesByStatus('processing');
  List<ActiveDelivery> get shippingDeliveries =>
      getDeliveriesByStatus('shipping');
  List<ActiveDelivery> get deliveredDeliveries =>
      getDeliveriesByStatus('delivered');
  List<ActiveDelivery> get completedDeliveries =>
      getDeliveriesByStatus('completed');
  List<ActiveDelivery> get cancelledDeliveries =>
      getDeliveriesByStatus('cancelled');
  List<ActiveDelivery> get pendingCancellationDeliveries =>
      getDeliveriesByStatus('pending_cancellation');

  Future<void> assignCourier(String orderId) async {
    try {
      final courierId = _supabase.auth.currentUser!.id;

      print('Assigning courier: $courierId to order: $orderId'); // Debug log

      await _supabase.rpc('assign_courier', params: {
        'p_order_id': orderId,
        'p_courier_id': courierId,
      });

      await fetchActiveDeliveries();
      Get.snackbar('Sukses', 'Berhasil menerima order');
    } catch (e) {
      print('Error assigning courier: $e');
      Get.snackbar(
        'Error',
        'Gagal menerima order',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
