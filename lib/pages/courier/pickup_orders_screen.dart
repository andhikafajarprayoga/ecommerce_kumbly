import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

// Model
class ActiveDelivery {
  final String id;
  final String? status;
  final String? courierId;
  final double totalAmount;
  final double shippingCost;
  final String shippingAddress;
  final DateTime createdAt;
  final List<String>? transit;
  final String? keterangan;
  final Map<String, dynamic>? merchantData;

  ActiveDelivery({
    required this.id,
    this.status,
    this.courierId,
    required this.totalAmount,
    required this.shippingCost,
    required this.shippingAddress,
    required this.createdAt,
    this.transit,
    this.keterangan,
    this.merchantData,
  });

  factory ActiveDelivery.fromJson(Map<String, dynamic> json) {
    return ActiveDelivery(
      id: json['id'],
      status: json['status'],
      courierId: json['courier_id'],
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      shippingCost: (json['shipping_cost'] ?? 0).toDouble(),
      shippingAddress: json['shipping_address'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      transit:
          json['transit'] != null ? List<String>.from(json['transit']) : null,
      keterangan: json['keterangan'],
      merchantData: json['merchant'],
    );
  }
}

// Controller
class PickupOrdersController extends GetxController {
  final _supabase = Supabase.instance.client;
  var isLoading = false.obs;
  var processingDeliveries = <ActiveDelivery>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchProcessingDeliveries();
  }

  Future<void> fetchProcessingDeliveries() async {
    try {
      isLoading.value = true;

      final data = await _supabase
          .from('orders')
          .select('''
            *,
            buyer:buyer_id(*)
          ''')
          .eq('status', 'processing')
          .eq('keterangan', 'ready')
          .order('created_at', ascending: false);

      for (var order in data) {
        if (order['merchant_id'] != null) {
          final merchantData = await _supabase
              .from('merchants')
              .select()
              .eq('id', order['merchant_id'])
              .single();
          order['merchant'] = merchantData;
        }
      }

      processingDeliveries.value = (data as List)
          .map<ActiveDelivery>((json) => ActiveDelivery.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      print('❌ Error fetching orders: $e');
      print('🔍 StackTrace: $stackTrace');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> assignCourier(String orderId) async {
    try {
      final currentUserId = _supabase.auth.currentUser!.id;

      await _supabase
          .from('orders')
          .update({'courier_id': currentUserId, 'status': 'shipping'}).eq(
              'id', orderId);

      await fetchProcessingDeliveries();
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(content: Text('Pesanan berhasil diterima')),
      );
    } catch (e) {
      print('Error assigning courier: $e');
      ScaffoldMessenger.of(Get.context!).showSnackBar(
        const SnackBar(content: Text('Gagal menerima pesanan')),
      );
    }
  }
}

class PickupOrdersScreen extends GetView<PickupOrdersController> {
  PickupOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(PickupOrdersController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jemput Paket'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        // Hapus filter yang tidak diperlukan dan gunakan data langsung
        final availableOrders = controller.processingDeliveries;

        if (availableOrders.isEmpty) {
          return const Center(
            child: Text('Tidak ada paket yang perlu dijemput'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: availableOrders.length,
          itemBuilder: (context, index) {
            final order = availableOrders[index];

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Order #${order.id.substring(0, 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Menunggu Pickup',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSimpleInfoRow(
                      icon: Icons.store_outlined,
                      label: 'Penjual',
                      value:
                          order.merchantData?['store_name'] ?? "Tidak tersedia",
                      isUnavailable: order.merchantData == null,
                    ),
                    _buildSimpleInfoRow(
                      icon: Icons.location_on_outlined,
                      label: 'Alamat Penjemputan',
                      value: _formatMerchantAddress(
                          order.merchantData?['store_address']),
                      isUnavailable: order.merchantData == null,
                    ),
                    _buildSimpleInfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Telepon',
                      value: order.merchantData?['store_phone'] ??
                          "Tidak tersedia",
                      isUnavailable: order.merchantData == null,
                    ),
                    _buildSimpleInfoRow(
                      icon: Icons.local_shipping_outlined,
                      label: 'Alamat Pengiriman',
                      value: order.shippingAddress,
                      isUnavailable: false,
                    ),
                    _buildSimpleInfoRow(
                      icon: Icons.payment_outlined,
                      label: 'Total',
                      value: NumberFormat.currency(
                        locale: 'id_ID',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(order.totalAmount),
                      isUnavailable: false,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await controller.assignCourier(order.id);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Terima Pesanan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildSimpleInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isUnavailable,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    color: isUnavailable ? Colors.grey : Colors.black87,
                    fontWeight:
                        isUnavailable ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatMerchantAddress(String? jsonAddress) {
    if (jsonAddress == null) return "Tidak tersedia";

    try {
      final addressMap = jsonDecode(jsonAddress);
      return [
        addressMap['street'],
        addressMap['village'],
        addressMap['district'],
        addressMap['city'],
        addressMap['province'],
        addressMap['postal_code'],
      ].where((e) => e != null && e.isNotEmpty).join(', ');
    } catch (e) {
      print('Error formatting address: $e');
      return "Format alamat tidak valid";
    }
  }
}
