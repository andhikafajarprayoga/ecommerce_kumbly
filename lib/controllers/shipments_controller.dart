import 'package:get/get.dart';
import 'package:kumbly_ecommerce/pages/admin/pengiriman/shipment_detail_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import 'package:flutter/material.dart';

class ShipmentsController extends GetxController {
  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();
  final orders = <Map<String, dynamic>>[].obs;
  final filteredOrders = <Map<String, dynamic>>[].obs;
  final selectedStatus = 'Semua'.obs;

  @override
  void onInit() {
    fetchOrders();
    super.onInit();
  }

  // Ambil data dari Supabase
  Future<void> fetchOrders() async {
    try {
      final response = await supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false);
      
      orders.value = List<Map<String, dynamic>>.from(response);
      filterShipments(); // Reapply current filters
    } catch (e) {
      Get.snackbar("Error", "Gagal mengambil data pengiriman: $e");
      print("Error Fetching Orders: $e");
    }
  }

  // Filter berdasarkan status
  void filterByStatus(String status) {
    selectedStatus.value = status;
    if (status == 'Semua') {
      filteredOrders.assignAll(orders);
    } else {
      filteredOrders.assignAll(orders
          .where((order) => getStatusIndonesia(order['status']) == status)
          .toList());
    }
  }

  // Filter berdasarkan pencarian
  void filterShipments() {
    String keyword = searchController.text.toLowerCase();
    filteredOrders.assignAll(
      orders
          .where(
            (order) =>
                order['id'].toLowerCase().contains(keyword) ||
                order['shipping_address'].toLowerCase().contains(keyword),
          )
          .toList(),
    );
  }

  // Ubah status dari bahasa Inggris ke bahasa Indonesia
  String getStatusIndonesia(String status) {
    Map<String, String> statusMapping = {
      'pending': 'Menunggu',
      'pending_cancellation': 'Menunggu Pembatalan',
      'processing': 'Diproses',
      'shipping': 'Dikirim',
      'delivered': 'Terkirim',
      'cancelled': 'Dibatalkan',
      'completed': 'Selesai',
    };
    return statusMapping[status] ?? status;
  }

  // Navigasi ke halaman detail
  void goToDetail(Map<String, dynamic> order) {
  Get.to(
    () => ShipmentDetailScreen(),
    arguments: {
      'id': order['id'],
      'status': order['status'],
      'shipping_address': order['shipping_address'],
      'total_amount': order['total_amount'],
      'buyer_id': order['buyer_id'],
      'created_at': order['created_at'],
      'shipping_cost': order['shipping_cost'],
      'courier_handover_photo': order['courier_handover_photo'],
    },
  );
}

}
