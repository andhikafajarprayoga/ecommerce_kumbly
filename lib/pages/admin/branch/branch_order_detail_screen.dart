import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';

class BranchOrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  final supabase = Supabase.instance.client;
  final RxString currentStatus = ''.obs;
  final RxMap<String, dynamic> orderData = RxMap<String, dynamic>();

  BranchOrderDetailScreen({required this.order}) {
    currentStatus.value = order['status'];
    orderData.value = Map<String, dynamic>.from(order);
  }

  @override
  Widget build(BuildContext context) {
    final shippingDetails = order['branch_shipping_details'][0];
    final orderItems =
        List<Map<String, dynamic>>.from(order['branch_order_items']);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pesanan Branch'),
        backgroundColor: AppTheme.primary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildOrderInfo(),
            _buildShippingDetails(shippingDetails),
            _buildOrderItems(orderItems),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Pesanan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(),
            _buildInfoRow(
                'Order ID', '#${order['id'].toString().substring(0, 8)}'),
            Obx(() =>
                _buildInfoRow('Status', _getStatusLabel(currentStatus.value))),
            _buildInfoRow('Branch', order['branches']['name']),
            _buildInfoRow(
              'Total',
              'Rp${NumberFormat('#,###').format(order['total_amount'])}',
            ),
            _buildInfoRow(
              'Tanggal',
              DateFormat('dd MMM yyyy HH:mm')
                  .format(DateTime.parse(order['created_at'])),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingDetails(Map<String, dynamic> details) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Pengiriman',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(),
            _buildAddressSection('Pengirim', details),
            SizedBox(height: 16),
            _buildAddressSection('Penerima', details, isRecipient: true),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(List<Map<String, dynamic>> items) {
    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daftar Produk',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(),
            ...items.map((item) => _buildItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Obx(() => Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              if (currentStatus.value == 'pending')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus('processing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Proses Pesanan',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              if (currentStatus.value == 'processing') ...[
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus('shipping'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Kirim Pesanan',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
              if (currentStatus.value == 'shipping')
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _updateOrderStatus('completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Selesaikan',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
            ],
          ),
        ));
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAddressSection(String title, Map<String, dynamic> details,
      {bool isRecipient = false}) {
    final prefix = isRecipient ? 'recipient_' : 'sender_';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        SizedBox(height: 4),
        Text(details['${prefix}name'] ?? ''),
        Text(details['${prefix}phone'] ?? ''),
        Text(details['${prefix}address']['full_address'] ?? ''),
      ],
    );
  }

  Widget _buildItemRow(Map<String, dynamic> item) {
    final product = item['products'];
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Produk tidak tersedia',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4),
                Text(
                  '${item['quantity']} x Rp${NumberFormat('#,###').format(item['price'])}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  'Total: Rp${NumberFormat('#,###').format(item['price'] * item['quantity'])}',
                  style: TextStyle(
                      color: AppTheme.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(String status) async {
    try {
      final validTransition = {
        'pending': 'processing',
        'processing': 'shipping',
        'shipping': 'completed'
      };

      if (validTransition[currentStatus.value] != status) {
        throw 'Invalid status transition';
      }

      await supabase.from('branch_orders').update({
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', order['id']);

      currentStatus.value = status;
      orderData['status'] = status;
      orderData['updated_at'] = DateTime.now().toIso8601String();

      Get.snackbar(
        'Sukses',
        'Status pesanan berhasil diupdate menjadi ${_getStatusLabel(status)}',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.back(result: orderData);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengupdate status pesanan: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print('Error: ${e.toString()}');
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'processing':
        return 'Diproses';
      case 'shipping':
        return 'Dikirim';
      case 'completed':
        return 'Selesai';
      default:
        return status;
    }
  }
}
