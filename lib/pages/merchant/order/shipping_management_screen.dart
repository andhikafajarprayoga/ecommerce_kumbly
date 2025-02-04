import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class ShippingManagementScreen extends StatefulWidget {
  const ShippingManagementScreen({Key? key}) : super(key: key);

  @override
  _ShippingManagementScreenState createState() =>
      _ShippingManagementScreenState();
}

class _ShippingManagementScreenState extends State<ShippingManagementScreen> {
  final supabase = Supabase.instance.client;
  final orders = <Map<String, dynamic>>[].obs;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      final response = await supabase
          .from('orders')
          .select('*')
          .eq('merchant_id', currentUserId)
          .or('status.eq.pending,status.eq.processing,status.eq.shipping')
          .order('created_at', ascending: false);

      orders.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching orders: $e');
    }
  }

  Future<void> _updateOrderStatus(String orderId, String currentStatus) async {
    try {
      String newStatus;
      switch (currentStatus) {
        case 'pending':
          newStatus = 'processing';
          break;
        case 'processing':
          newStatus = 'shipping';
          break;
        default:
          return;
      }

      await supabase
          .from('orders')
          .update({'status': newStatus}).eq('id', orderId);

      Get.snackbar(
        'Sukses',
        'Status pesanan berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      _fetchOrders(); // Refresh data
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal memperbarui status pesanan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manajemen Pengiriman'),
      ),
      body: Obx(() => ListView.builder(
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title:
                      Text('Order #${order['id'].toString().substring(0, 8)}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status: ${order['status']}'),
                      Text('Alamat: ${order['shipping_address']}'),
                      Text(
                          'Total: Rp${order['total_amount'].toStringAsFixed(0)}'),
                    ],
                  ),
                  trailing: _buildActionButton(order),
                ),
              );
            },
          )),
    );
  }

  Widget _buildActionButton(Map<String, dynamic> order) {
    String buttonText;
    bool canUpdate = true;

    switch (order['status']) {
      case 'pending':
        buttonText = 'Proses Pesanan';
        break;
      case 'processing':
        buttonText = 'Kirim Pesanan';
        break;
      case 'shipping':
        buttonText = 'Sedang Dikirim';
        canUpdate = false;
        break;
      default:
        buttonText = 'Tidak Tersedia';
        canUpdate = false;
    }

    return ElevatedButton(
      onPressed: canUpdate
          ? () => _showConfirmationDialog(order['id'], order['status'])
          : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: canUpdate ? AppTheme.primary : Colors.grey,
      ),
      child: Text(buttonText),
    );
  }

  Future<void> _showConfirmationDialog(String orderId, String currentStatus) {
    String actionText = currentStatus == 'pending' ? 'memproses' : 'mengirim';

    return Get.dialog(
      AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text('Apakah Anda yakin ingin $actionText pesanan ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _updateOrderStatus(orderId, currentStatus);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );
  }
}
