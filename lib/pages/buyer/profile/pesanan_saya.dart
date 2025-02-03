import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/controllers/order_controller.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';

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

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
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
                          'Rp ${NumberFormat('#,###').format(order['total_amount'])}',
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
