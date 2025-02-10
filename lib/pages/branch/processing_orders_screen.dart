import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';

class ProcessingOrdersScreen extends StatefulWidget {
  const ProcessingOrdersScreen({super.key});

  @override
  State<ProcessingOrdersScreen> createState() => _ProcessingOrdersScreenState();
}

class _ProcessingOrdersScreenState extends State<ProcessingOrdersScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesanan Masuk'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: supabase
              .from('orders')
              .stream(primaryKey: ['id'])
              .eq('status', 'processing')
              .execute(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final orders = snapshot.data!;
            if (orders.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Belum ada pesanan masuk',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return _buildOrderCard(order);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order['id'].toString().substring(0, 8)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildStatusChip('Processing'),
              ],
            ),
            const Divider(height: 24),
            FutureBuilder<Map<String, dynamic>>(
              future: order['seller_id'] != null
                  ? supabase
                      .from('users')
                      .select()
                      .eq('id', order['seller_id'])
                      .maybeSingle() as Future<Map<String, dynamic>>
                  : Future.value({'name': 'Unknown Seller'})
                      as Future<Map<String, dynamic>>,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _buildInfoRow('Seller', 'Error loading seller');
                }

                if (!snapshot.hasData) {
                  return _buildInfoRow('Seller', 'Loading...');
                }

                final sellerName = snapshot.data?['name'] ?? 'Unknown Seller';
                return _buildInfoRow('Seller', sellerName);
              },
            ),
            const SizedBox(height: 8),
            _buildInfoRow('Tanggal', _formatDate(order['created_at'] ?? '')),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showReceiveDialog(order),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                minimumSize: const Size(double.infinity, 45),
              ),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Terima & Masukkan ke Inventory'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: AppTheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showReceiveDialog(Map<String, dynamic> order) {
    Get.dialog(
      AlertDialog(
        title: const Text('Konfirmasi Penerimaan'),
        content: const Text(
          'Pastikan barang sudah diperiksa dan sesuai. Barang akan dimasukkan ke inventory cabang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Batal',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => _processReceival(order),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
            ),
            child: const Text('Terima & Proses'),
          ),
        ],
      ),
    );
  }

  Future<void> _processReceival(Map<String, dynamic> order) async {
    try {
      print('\nDEBUG: Getting complete order data...');
      print('  - Initial Order ID: ${order['id']}');

      // Get current branch ID
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) throw 'User tidak ditemukan';

      final branchData = await supabase
          .from('branches')
          .select()
          .eq('user_id', currentUser.id)
          .single();

      final branchId = branchData['id'];
      if (branchId == null) throw 'Branch ID tidak ditemukan';

      // Ambil data order lengkap beserta order_items
      final completeOrder = await supabase
          .from('orders')
          .select('*, order_items!inner(*)')
          .eq('id', order['id'])
          .single();

      print('\nDEBUG: Processing complete order:');
      print('  - Order ID: ${completeOrder['id']}');
      print('  - Branch ID: $branchId');
      print('  - Product ID: ${completeOrder['order_items'][0]['product_id']}');
      print('  - Quantity: ${completeOrder['order_items'][0]['quantity']}');
      print('  - Courier ID: ${completeOrder['courier_id']}');

      if (completeOrder['order_items'][0]['product_id'] == null) {
        throw 'Product ID tidak ditemukan';
      }

      Get.back(); // Tutup dialog
      Get.dialog(
        const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      // 1. Update status order ke 'delivered'
      await supabase
          .from('orders')
          .update({'status': 'delivered'}).eq('id', completeOrder['id']);

      // 2. Masukkan ke branch_products dengan status 'received'
      await supabase.from('branch_products').insert({
        'product_id': completeOrder['order_items'][0]['product_id'],
        'order_id': completeOrder['id'],
        'branch_id': branchId, // Gunakan branch ID dari user yang login
        'quantity': completeOrder['order_items'][0]['quantity'],
        'status': 'received',
        'created_at': DateTime.now().toIso8601String(),
        'courier_id': completeOrder['courier_id'],
        'shipping_status': null,
      }).select();

      Get.back();
      Get.snackbar(
        'Sukses',
        'Barang berhasil diterima dan dimasukkan ke inventory',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Gagal memproses penerimaan: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      print("Error gagal memproses penerimaan: $e");
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }
}
