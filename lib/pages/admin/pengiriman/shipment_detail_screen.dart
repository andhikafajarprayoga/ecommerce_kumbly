import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

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
  final TextEditingController adminNoteController = TextEditingController();
  String? merchantAddress;
  List<Map<String, dynamic>> orderItems = [];
  String? selectedAdminNote = 'Terima'; // Default value

  @override
  void initState() {
    super.initState();
    print('Debug - Initial Order Data: $orderData');
    selectedStatus = orderData['status'];
    fetchOrderDetails();
    checkCancellationRequest();
    fetchMerchantAddress();
    fetchOrderItems();
  }

  Future<void> fetchOrderDetails() async {
    try {
      final response = await supabase
          .from('orders')
          .select('*, name_courier')
          .eq('id', orderData['id'])
          .single();

      print('Debug - Fetched Order Details: $response');

      setState(() {
        orderData.addAll(response); // Update orderData dengan data terbaru
      });
    } catch (e) {
      print('Error fetching order details: $e');
    }
  }

  Future<void> checkCancellationRequest() async {
    try {
      final response = await supabase
          .from('order_cancellations')
          .select()
          .eq('order_id', orderData['id'])
          .eq('status', 'pending')
          .maybeSingle();

      setState(() {
        hasCancellationRequest = response != null;
        cancellationData = response;
      });
    } catch (e) {
      print('Error checking cancellation: $e');
      setState(() {
        hasCancellationRequest = false;
        cancellationData = null;
      });
    }
  }

  Future<void> processCancellation(bool isApproved) async {
    try {
      final currentUser = supabase.auth.currentUser;

      // Update cancellation status
      await supabase.from('order_cancellations').update({
        'status': isApproved ? 'approved' : 'rejected',
        'processed_by': currentUser?.id,
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', cancellationData?['id']);

      // If approved, update order status to cancelled
      if (isApproved) {
        await supabase
            .from('orders')
            .update({'status': 'cancelled'}).eq('id', orderData['id']);

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

  Future<void> fetchMerchantAddress() async {
    try {
      final orderId = orderData['id'];
      print('Debug - Order ID: $orderId');

      // Ambil merchant_id dari tabel orders
      final orderResponse = await supabase
          .from('orders')
          .select('merchant_id')
          .eq('id', orderId)
          .single();

      print('Debug - Order Response: $orderResponse');
      final merchantId = orderResponse['merchant_id'];
      print('Debug - Merchant ID from DB: $merchantId');

      if (merchantId != null) {
        final response = await supabase
            .from('merchants')
            .select('store_address')
            .eq('id', merchantId)
            .single();

        print('Debug - Raw Response: $response');

        if (response['store_address'] != null) {
          // Parse JSON string menjadi Map
          final addressData = json.decode(response['store_address']);
          print('Debug - Parsed Address Data: $addressData');

          // Format alamat lengkap
          final fullAddress = [
            addressData['address'],
            addressData['district'],
            addressData['city'],
            addressData['province'],
            addressData['postal_code'],
          ].where((e) => e != null && e.isNotEmpty).join(', ');

          print('Debug - Full Address: $fullAddress');

          setState(() {
            merchantAddress = fullAddress;
          });
        } else {
          print('Debug - Store address is null');
          setState(() {
            merchantAddress = 'Alamat toko tidak tersedia';
          });
        }
      } else {
        print('Debug - Merchant ID is null');
        setState(() {
          merchantAddress = 'Merchant ID tidak ditemukan';
        });
      }
    } catch (e) {
      print('Error fetching merchant address: $e');
      setState(() {
        merchantAddress = 'Alamat tidak tersedia';
      });
    }
  }

  Future<void> fetchOrderItems() async {
    try {
      final response = await supabase
          .from('order_items')
          .select('*, products(name)')
          .eq('order_id', orderData['id']);

      setState(() {
        orderItems = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error fetching order items: $e');
    }
  }

  Future<void> updateAdminNote(String note) async {
    try {
      final currentUser = supabase.auth.currentUser;

      if (currentUser == null) {
        throw Exception('User tidak terautentikasi');
      }

      String newStatus;
      if (note == 'Terima') {
        newStatus = 'processing'; // atau status lain sesuai flow Anda
      } else {
        newStatus = 'cancelled';
      }

      await supabase
          .from('orders')
          .update({
            'admin_acc_note': note,
            'status': newStatus,
          })
          .eq('id', orderData['id'])
          .select('id, admin_acc_note, status');

      setState(() {
        orderData['status'] = newStatus;
      });

      Get.snackbar(
        'Sukses',
        'Status pesanan: ${note == 'Terima' ? 'Diterima' : 'Ditolak'}',
        backgroundColor: note == 'Terima' ? Colors.green : Colors.red,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error updating admin note: $e');
      Get.snackbar(
        'Error',
        'Gagal memperbarui status: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.grey.shade50],
          ),
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
                      color: Colors.black87,
                    ),
                  ),
                  _buildStatusChip(orderData['status']),
                ],
              ),
              Divider(height: 32, thickness: 1),
              _buildShippingSection(),
              SizedBox(height: 16),
              _buildStoreSection(),
              SizedBox(height: 16),
              _buildAdminNoteSection(),
              SizedBox(height: 8),
              Text(
                'Daftar Produk',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...orderItems.map((item) => _buildOrderItemTile(item)),
              Divider(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShippingSection() {
    print('Debug - Full Order Data: $orderData');
    print('Debug - Courier Name: ${orderData['name_courier']}');

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_shipping, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Informasi Pengiriman',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          Divider(height: 16),
          Text(
            'Alamat Pengiriman:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(orderData['shipping_address'] ?? 'Tidak ada alamat'),
          SizedBox(height: 8),
          Text(
            'Biaya Pengiriman:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
              'Rp ${NumberFormat('#,###').format(orderData['shipping_cost'] ?? 0)}'),
          SizedBox(height: 8),
          Text(
            'Kurir:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Container(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              orderData['name_courier']?.toString().isNotEmpty == true
                  ? orderData['name_courier']
                  : 'Belum ada kurir jemput',
              style: TextStyle(
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Colors.green),
              SizedBox(width: 8),
              Text(
                'Informasi Toko',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade900,
                ),
              ),
            ],
          ),
          Divider(height: 16),
          Text(
            'Alamat Toko:',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(merchantAddress ?? 'Alamat toko tidak tersedia'),
        ],
      ),
    );
  }

  Widget _buildAdminNoteSection() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: selectedAdminNote,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Status Pesanan',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              DropdownMenuItem(value: 'Terima', child: Text('Terima Pesanan')),
              DropdownMenuItem(value: 'Tolak', child: Text('Tolak Pesanan')),
            ],
            onChanged: (value) {
              setState(() {
                selectedAdminNote = value;
              });
            },
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              if (selectedAdminNote != null) {
                updateAdminNote(selectedAdminNote!);
              }
            },
            icon: Icon(Icons.send, color: Colors.white),
            label: Text('Kirim Status', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  selectedAdminNote == 'Terima' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 45), // full width button
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
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

  Widget _buildStatusChip(String status) {
    Color chipColor;
    switch (status) {
      case 'pending':
        chipColor = Colors.blue;
        break;
      case 'pending_cancellation':
        chipColor = Colors.orange;
        break;
      case 'processing':
        chipColor = Colors.amber;
        break;
      case 'transit':
        chipColor = Colors.indigo;
        break;
      case 'shipping':
        chipColor = Colors.purple;
        break;
      case 'delivered':
        chipColor = Colors.teal;
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Colors.red.shade50],
          ),
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
              Text(
                  'Diminta pada: ${DateTime.parse(cancellationData?['requested_at']).toLocal()}'),
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
      ),
    );
  }

  Widget _buildOrderItemTile(Map<String, dynamic> item) {
    final productName = item['products'] != null && item['products']['name'] != null
        ? item['products']['name']
        : 'Produk tidak ditemukan';
    return ListTile(
      title: Text(productName),
      subtitle: Text('Rp ${item['price']} x ${item['quantity']}'),
      trailing: Text('Rp ${item['price'] * item['quantity']}'),
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
            child: Text('Batal', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.pop(context);
              deleteOrder();
            },
          ),
        ],
      ),
    );
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
        await supabase
            .from('order_cancellations')
            .delete()
            .eq('order_id', orderId);
      }

      // Hapus notifikasi_seller jika masih ada
      final notifications = await supabase
          .from('notifikasi_seller')
          .select()
          .eq('order_id', orderId);

      if (notifications.isNotEmpty) {
        await supabase
            .from('notifikasi_seller')
            .delete()
            .eq('order_id', orderId);
      }

      // Hapus order_items jika masih ada
      final orderItems =
          await supabase.from('order_items').select().eq('order_id', orderId);

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

  String _getStatusIndonesia(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'pending_cancellation':
        return 'Menunggu Pembatalan';
      case 'processing':
        return 'Diproses';
      case 'transit':
        return 'Transit';
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
