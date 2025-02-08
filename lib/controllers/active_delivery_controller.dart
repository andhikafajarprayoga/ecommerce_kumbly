import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/active_delivery.dart';
import 'package:flutter/material.dart';

class ActiveDeliveryController extends GetxController {
  final _supabase = Supabase.instance.client;
  final RxList<ActiveDelivery> activeDeliveries = <ActiveDelivery>[].obs;
  final RxList<ActiveDelivery> pendingDeliveries = <ActiveDelivery>[].obs;
  final RxList<ActiveDelivery> processingDeliveries = <ActiveDelivery>[].obs;
  final RxList<ActiveDelivery> shippingDeliveries = <ActiveDelivery>[].obs;
  final RxList<ActiveDelivery> deliveredDeliveries = <ActiveDelivery>[].obs;
  final RxList<ActiveDelivery> completedDeliveries = <ActiveDelivery>[].obs;
  final RxList<ActiveDelivery> cancelledDeliveries = <ActiveDelivery>[].obs;
  final RxList<ActiveDelivery> pendingCancellationDeliveries =
      <ActiveDelivery>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchActiveDeliveries();
  }

  Future<void> fetchActiveDeliveries() async {
    try {
      isLoading.value = true;

      // Ambil data orders dengan join ke users untuk data pembeli
      final response = await _supabase.from('orders').select('''
            *,
            buyer:users!buyer_id (
              full_name,
              phone
            )
          ''').order('created_at', ascending: false);

      // Ambil data merchants untuk setiap order
      final List<ActiveDelivery> deliveries = [];
      for (var order in response) {
        // Ambil data merchant untuk setiap order
        final merchantResponse = await _supabase
            .from('merchants')
            .select('*')
            .eq('id', order['merchant_id'])
            .single();

        deliveries.add(ActiveDelivery(
          id: order['id'],
          status: order['status'],
          totalAmount: (order['total_amount'] as num).toDouble(),
          shippingCost: (order['shipping_cost'] as num).toDouble(),
          shippingAddress: order['shipping_address'],
          buyerId: order['buyer_id'],
          buyerName: order['buyer']['full_name'],
          merchantId: order['merchant_id'],
          createdAt: DateTime.parse(order['created_at']),
          merchantName: merchantResponse['store_name'],
          merchantAddress: merchantResponse['store_address'],
          merchantPhone: merchantResponse['store_phone'],
        ));
      }

      // Update RxLists berdasarkan status
      pendingDeliveries.value =
          deliveries.where((d) => d.status == 'pending').toList();
      processingDeliveries.value =
          deliveries.where((d) => d.status == 'processing').toList();
      shippingDeliveries.value =
          deliveries.where((d) => d.status == 'shipping').toList();
      deliveredDeliveries.value =
          deliveries.where((d) => d.status == 'delivered').toList();
      completedDeliveries.value =
          deliveries.where((d) => d.status == 'completed').toList();
      cancelledDeliveries.value =
          deliveries.where((d) => d.status == 'cancelled').toList();
      pendingCancellationDeliveries.value =
          deliveries.where((d) => d.status == 'pending_cancellation').toList();
    } catch (e) {
      print('Error fetching deliveries: $e');
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
