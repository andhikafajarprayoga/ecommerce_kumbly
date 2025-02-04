import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../theme/app_theme.dart';

class DetailPesananScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const DetailPesananScreen({super.key, required this.order});

  @override
  State<DetailPesananScreen> createState() => _DetailPesananScreenState();
}

class _DetailPesananScreenState extends State<DetailPesananScreen> {
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

  double calculateSubtotal(List items) {
    return items.fold(0.0, (sum, item) {
      final quantity = item['total_amount'] ?? 0;
      final price = double.tryParse(item['price'].toString()) ?? 0.0;
      return sum + (quantity * price);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.order['items'] ?? [];
    final status = widget.order['status'] ?? 'pending';
    final shippingAddress =
        widget.order['shipping_address'] ?? 'Alamat tidak tersedia';
    final shippingCost =
        double.tryParse(widget.order['shipping_cost'].toString()) ?? 0.0;
    final totalAmount =
        double.tryParse(widget.order['total_amount'].toString()) ?? 0.0;
    final subtotal = totalAmount;
    final totalPayment = totalAmount + shippingCost;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primary,
        title: Text(
          'Detail Pesanan',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Pesanan
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'Status Pesanan',
                    style: AppTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        color: getStatusColor(status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Produk yang Dipesan
            if (items.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
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
                    Text(
                      'Produk yang Dipesan',
                      style: AppTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final product = item['product'] ?? {};
                        final productName =
                            product['name'] ?? 'Produk tidak tersedia';
                        final productImage = product['image_url'] ?? '';
                        final quantity = item['quantity'] ?? 0;
                        final price =
                            double.tryParse(item['price'].toString()) ?? 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Gambar Produk
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: productImage.isNotEmpty
                                    ? Image.network(
                                        productImage,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                value: loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return _buildImageError();
                                        },
                                      )
                                    : _buildImageError(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: AppTheme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$quantity x Rp ${NumberFormat('#,###').format(price)}',
                                      style: AppTheme.textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total: Rp ${NumberFormat('#,###').format(quantity * price)}',
                                      style: AppTheme.textTheme.bodyMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

            // Informasi Pengiriman
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'Informasi Pengiriman',
                    style: AppTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow('Alamat', shippingAddress),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                      'Kurir',
                      widget.order['shipping_method'] ??
                          'Kurir tidak tersedia'),
                ],
              ),
            ),

            // Rincian Pembayaran
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
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
                  Text(
                    'Rincian Pembayaran',
                    style: AppTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentRow('Subtotal Produk', subtotal),
                  const SizedBox(height: 8),
                  _buildPaymentRow('Biaya Pengiriman', shippingCost),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(),
                  ),
                  _buildPaymentRow('Total Pembayaran', totalPayment,
                      isTotal: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageError() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_not_supported,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(String label, num amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          'Rp ${NumberFormat('#,###').format(amount)}',
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            color: isTotal ? AppTheme.primary : null,
          ),
        ),
      ],
    );
  }
}
