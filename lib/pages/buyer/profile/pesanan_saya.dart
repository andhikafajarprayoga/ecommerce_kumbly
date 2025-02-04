import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';
import '../../../../pages/buyer/profile/detail_pesanan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class PesananSayaScreen extends StatefulWidget {
  const PesananSayaScreen({super.key});

  @override
  State<PesananSayaScreen> createState() => _PesananSayaScreenState();
}

class _PesananSayaScreenState extends State<PesananSayaScreen> {
  final OrderController orderController = Get.put(OrderController());

  @override
  void initState() {
    super.initState();
    orderController.fetchOrders();
  }

  String formatDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
  }

  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      return NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(amount);
    } catch (e) {
      print('Error formatting currency: $e');
      return 'Rp 0';
    }
  }

  double calculateTotalPayment(Map<String, dynamic> order) {
    try {
      final totalAmount =
          double.tryParse(order['total_amount'].toString()) ?? 0.0;
      final shippingCost =
          double.tryParse(order['shipping_cost'].toString()) ?? 0.0;
      return totalAmount + shippingCost;
    } catch (e) {
      print('Error calculating total payment: $e');
      return 0.0;
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pending_cancellation':
        return Colors.orange.shade700;
      case 'processing':
        return Colors.blue;
      case 'shipped':
        return Colors.green;
      case 'delivered':
        return Colors.green.shade700;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatOrderId(String orderId) {
    if (orderId.length > 6) {
      return '#${orderId.substring(orderId.length - 6)}';
    }
    return '#$orderId';
  }

  void _showCancelDialog(Map<String, dynamic> order) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Batalkan Pesanan',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apakah Anda yakin ingin membatalkan pesanan ini?',
              style: AppTheme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Pembatalan akan diproses setelah mendapat persetujuan admin.',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
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
            onPressed: () => _requestCancellation(order['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCancellation(String orderId) async {
    try {
      // 1. Insert ke order_cancellations dengan status pending
      await supabase.from('order_cancellations').insert({
        'order_id': orderId,
        'status': 'pending', // Menunggu persetujuan admin
        'requested_at': DateTime.now().toIso8601String(),
        'requested_by': supabase.auth.currentUser!.id,
      });

      // 2. Update status order menjadi pending_cancellation
      await supabase
          .from('orders')
          .update({'status': 'pending_cancellation'}).eq('id', orderId);

      Get.back(); // Tutup dialog
      Get.snackbar(
        'Berhasil',
        'Permintaan pembatalan telah dikirim dan menunggu persetujuan admin',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // 3. Refresh data pesanan
      orderController.fetchOrders();
    } catch (e) {
      print('Error requesting cancellation: $e');
      Get.back();
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat memproses permintaan pembatalan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Tambahkan fungsi untuk menghapus pesanan
  void _showDeleteDialog(Map<String, dynamic> order) {
    Get.dialog(
      AlertDialog(
        title: Text(
          'Hapus Pesanan',
          style: AppTheme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus pesanan ini?',
          style: AppTheme.textTheme.bodyMedium,
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
            onPressed: () => _deleteOrder(order['id']),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteOrder(String orderId) async {
    try {
      // Hapus order_cancellations terlebih dahulu
      await supabase
          .from('order_cancellations')
          .delete()
          .eq('order_id', orderId);

      // Kemudian hapus order
      await supabase.from('orders').delete().eq('id', orderId);

      Get.back(); // Tutup dialog
      Get.snackbar(
        'Berhasil',
        'Pesanan telah dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Refresh data pesanan
      orderController.fetchOrders();
    } catch (e) {
      print('Error deleting order: $e');
      Get.back();
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat menghapus pesanan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Di dalam ListView.builder, tambahkan tombol batalkan jika status pending
  Widget _buildCancelButton(Map<String, dynamic> order) {
    if (order['status'].toString().toLowerCase() != 'pending') {
      return const SizedBox.shrink();
    }

    return TextButton.icon(
      onPressed: () => _showCancelDialog(order),
      icon: const Icon(
        Icons.cancel_outlined,
        color: Colors.red,
        size: 18,
      ),
      label: Text(
        'Batalkan Pesanan',
        style: AppTheme.textTheme.bodySmall?.copyWith(
          color: Colors.red,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Update fungsi untuk build action buttons
  Widget _buildOrderActions(Map<String, dynamic> order) {
    final status = order['status'].toString().toLowerCase();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (status == 'pending')
          _buildCancelButton(order)
        else if (status == 'pending_cancellation')
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Menunggu Persetujuan Admin',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else if (status == 'cancelled')
          TextButton.icon(
            onPressed: () => _showDeleteDialog(order),
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: 18,
            ),
            label: Text(
              'Hapus Pesanan',
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        TextButton(
          onPressed: () {
            Get.to(() => DetailPesananScreen(order: order));
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
          ),
          child: Row(
            children: [
              Text(
                'Lihat Detail',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: AppTheme.primary,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F5F5), // Warna background khas e-commerce
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: Text(
          'Pesanan Saya',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Obx(() {
        if (orderController.isLoading.value) {
          return Center(
              child: CircularProgressIndicator(
            color: AppTheme.primary,
          ));
        }

        if (orderController.orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 80,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada pesanan',
                  style: AppTheme.textTheme.titleLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yuk mulai belanja!',
                  style: AppTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textHint,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: orderController.orders.length,
          itemBuilder: (context, index) {
            final order = orderController.orders[index];
            final totalPayment = calculateTotalPayment(order);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 16,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Order ${formatOrderId(order['id'])}',
                              style: AppTheme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: getStatusColor(order['status'])
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            order['status'].toUpperCase(),
                            style: AppTheme.textTheme.bodySmall?.copyWith(
                              color: getStatusColor(order['status']),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          Icons.calendar_today_outlined,
                          'Tanggal Pesanan',
                          formatDate(order['created_at']),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1),
                        ),
                        _buildInfoRow(
                          Icons.payments_outlined,
                          'Total Pembayaran',
                          formatCurrency(totalPayment),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1),
                        ),
                        _buildInfoRow(
                          Icons.location_on_outlined,
                          'Alamat Pengiriman',
                          order['shipping_address'],
                        ),
                      ],
                    ),
                  ),

                  // Tombol Detail
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: _buildOrderActions(order),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
