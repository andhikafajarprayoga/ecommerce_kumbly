import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShipmentDetailScreen extends StatefulWidget {
  @override
  State<ShipmentDetailScreen> createState() => _ShipmentDetailScreenState();
}

class _ShipmentDetailScreenState extends State<ShipmentDetailScreen> {
  final supabase = Supabase.instance.client;
  final Map<String, dynamic> orderData = Get.arguments;
  String selectedStatus = '';
  bool hasCancellationRequest = false;
  Map<String, dynamic>? cancellationData;

  @override
  void initState() {
    super.initState();
    selectedStatus = orderData['status'];
    checkCancellationRequest();
  }

  Future<void> checkCancellationRequest() async {
    try {
      final response = await supabase
          .from('order_cancellations')
          .select()
          .eq('order_id', orderData['id'])
          .eq('status', 'pending')
          .single();
      
      setState(() {
        hasCancellationRequest = response != null;
        cancellationData = response;
      });
    } catch (e) {
      print('Error checking cancellation: $e');
    }
  }

  Future<void> processCancellation(bool isApproved) async {
    try {
      final currentUser = supabase.auth.currentUser;
      
      // Update cancellation status
      await supabase
          .from('order_cancellations')
          .update({
            'status': isApproved ? 'approved' : 'rejected',
            'processed_by': currentUser?.id,
            'processed_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cancellationData?['id']);

      // If approved, update order status to cancelled
      if (isApproved) {
        await supabase
            .from('orders')
            .update({'status': 'cancelled'})
            .eq('id', orderData['id']);
        
        setState(() {
          orderData['status'] = 'cancelled';
          selectedStatus = 'cancelled';
        });
      }

      setState(() {
        hasCancellationRequest = false;
        cancellationData = null;
      });

      Get.snackbar(
        'Sukses',
        isApproved ? 'Pembatalan disetujui' : 'Pembatalan ditolak',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal memproses pembatalan: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> updateStatus(String newStatus) async {
    try {
      await supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderData['id']);
      
      setState(() {
        orderData['status'] = newStatus; // Update local state
      });
      
      Get.snackbar(
        'Sukses',
        'Status pesanan berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      
      Get.back(result: true);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal memperbarui status: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> deleteOrder() async {
  try {
    final orderId = orderData['id'];

    // Cek apakah order_id masih direferensikan sebelum menghapus
    final cancellations = await supabase
        .from('order_cancellations')
        .select()
        .eq('order_id', orderId);

    if (cancellations.isNotEmpty) {
      await supabase.from('order_cancellations').delete().eq('order_id', orderId);
    }

    // Hapus order_items jika masih ada
    final orderItems = await supabase
        .from('order_items')
        .select()
        .eq('order_id', orderId);

    if (orderItems.isNotEmpty) {
      await supabase.from('order_items').delete().eq('order_id', orderId);
    }

    // Setelah memastikan referensi dihapus, hapus order
    await supabase.from('orders').delete().eq('id', orderId);

    Get.snackbar(
      'Sukses',
      'Pesanan berhasil dihapus',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );

    // Tunggu snackbar selesai sebelum kembali
    await Future.delayed(Duration(seconds: 2));
    Get.back(result: true);

    // Tampilkan snackbar di halaman sebelumnya
    Get.snackbar(
      'Informasi',
      'Data pesanan telah dihapus dari sistem',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  } catch (e) {
    print('Error deleting order: $e');
    Get.snackbar(
      'Error',
      'Gagal menghapus pesanan: $e',
      backgroundColor: Colors.red,
      colorText: Colors.white,
      duration: Duration(seconds: 3),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pengiriman',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () => _showDeleteConfirmation(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasCancellationRequest) _buildCancellationRequest(),
            _buildOrderInfo(),
            SizedBox(height: 16),
            if (!hasCancellationRequest && orderData['status'] != 'cancelled')
              _buildStatusUpdate(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Informasi Pesanan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(orderData['status']),
              ],
            ),
            Divider(height: 32),
            _buildInfoItem(
              icon: Icons.numbers,
              title: 'ID Pesanan',
              value: orderData['id'],
            ),
            _buildInfoItem(
              icon: Icons.location_on_outlined,
              title: 'Alamat Pengiriman',
              value: orderData['shipping_address'],
            ),
            _buildInfoItem(
              icon: Icons.payments_outlined,
              title: 'Total Pembayaran',
              value: 'Rp ${orderData['total_amount']}',
            ),
            _buildInfoItem(
              icon: Icons.local_shipping_outlined,
              title: 'Biaya Pengiriman',
              value: 'Rp ${orderData['shipping_cost']}',
            ),
            _buildInfoItem(
              icon: Icons.calendar_today_outlined,
              title: 'Tanggal Pemesanan',
              value: DateTime.parse(orderData['created_at'])
                          .toLocal()
                          .toString()
                          .split('.')[0],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusUpdate() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: InputDecoration(
                labelText: 'Status Pesanan',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                'pending',
                'pending_cancellation',
                'processing',
                'shipping',
                'delivered',
                'completed',
                'cancelled',
              ].map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(_getStatusIndonesia(status)),
                  )).toList(),
              onChanged: (value) {
                setState(() {
                  selectedStatus = value!;
                });
              },
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => updateStatus(selectedStatus),
                child: Text(
                  'Update Status',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status) {
      case 'pending':
        chipColor = Colors.blue;
        break;
      case 'processing':
        chipColor = Colors.orange;
        break;
      case 'shipping':
        chipColor = Colors.purple;
        break;
      case 'completed':
        chipColor = Colors.green;
        break;
      case 'cancelled':
        chipColor = Colors.red;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _getStatusIndonesia(status),
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCancellationRequest() {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permintaan Pembatalan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 16),
            Text('Catatan: ${cancellationData?['notes'] ?? '-'}'),
            Text('Diminta pada: ${DateTime.parse(cancellationData?['requested_at']).toLocal()}'),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => processCancellation(true),
                    child: Text('Setujui Pembatalan'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => processCancellation(false),
                    child: Text('Tolak'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Konfirmasi Hapus'),
        content: Text('Yakin ingin menghapus pesanan ini?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        actions: [
          TextButton(
            child: Text('Batal',
                style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Hapus',
                style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              deleteOrder();
            },
          ),
        ],
      ),
    );
  }

  String _getStatusIndonesia(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'pending_cancellation':
        return 'Menunggu Pembatalan';
      case 'processing':
        return 'Diproses';
      case 'shipping':
        return 'Dikirim';
      case 'delivered':
        return 'Terkirim';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }
} 