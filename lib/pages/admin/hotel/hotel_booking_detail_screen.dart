import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';

class HotelBookingDetailScreen extends StatelessWidget {
  final Map<String, dynamic> booking;

  const HotelBookingDetailScreen({Key? key, required this.booking})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Debug print untuk memastikan data diterima dengan benar
    print('Debug - Booking Data:');
    print('Total Price: ${booking['total_price']}');
    print('Admin Fee: ${booking['admin_fee']}');
    print('App Fee: ${booking['app_fee']}');

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Booking'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('ID Booking', booking['id']),
            _buildDetailRow('Hotel', booking['hotels']?['name'] ?? 'Unknown'),
            _buildDetailRow('Hotel ID', booking['hotel_id']),
            _buildDetailRow('User ID', booking['user_id']),
            _buildDetailRow('Tipe Kamar', booking['room_type']),
            _buildDetailRow('Nama Tamu', booking['guest_name']),
            _buildDetailRow('Telepon', booking['guest_phone']),
            _buildDetailRow(
                'Check-in',
                DateFormat('dd MMM yyyy')
                    .format(DateTime.parse(booking['check_in']))),
            _buildDetailRow(
                'Check-out',
                DateFormat('dd MMM yyyy')
                    .format(DateTime.parse(booking['check_out']))),
            _buildDetailRow('Total Malam', '${booking['total_nights']} malam'),
            _buildDetailRow('Total Harga',
                'Rp ${NumberFormat('#,###').format(booking['total_price'])}'),
            _buildDetailRow('Admin Fee',
                'Rp ${NumberFormat('#,###').format(booking['admin_fee'])}'),
            _buildDetailRow('App Fee',
                'Rp ${NumberFormat('#,###').format(booking['app_fee'])}'),
            Divider(thickness: 1),
            _buildTotalSummary(),
            _buildDetailRow('Status', booking['status']),
            _buildDetailRow('Metode Pembayaran',
                booking['payment_methods']?['name'] ?? 'Unknown'),
            if (booking['special_requests'] != null)
              _buildDetailRow('Permintaan Khusus', booking['special_requests']),
            _buildDetailRow(
                'Dibuat pada',
                DateFormat('dd MMM yyyy HH:mm')
                    .format(DateTime.parse(booking['created_at']))),
            SizedBox(height: 16),
            Text('Bukti Pembayaran:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            if (booking['image_url'] != null)
              GestureDetector(
                onTap: () => _showImagePreview(context, booking['image_url']),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      booking['image_url'],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(Icons.error, color: Colors.red),
                        );
                      },
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.image_not_supported, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Belum ada bukti pembayaran',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    Get.dialog(
      Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Bukti Pembayaran'),
              backgroundColor: Colors.green,
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Get.back(),
              ),
            ),
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(Icons.error, color: Colors.red),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalSummary() {
    // Ubah tipe data menjadi double
    double totalPrice = (booking['total_price'] ?? 0).toDouble();
    double adminFee = (booking['admin_fee'] ?? 0).toDouble();
    double appFee = (booking['app_fee'] ?? 0).toDouble();
    double grandTotal = totalPrice + adminFee + appFee;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            'Ringkasan Pembayaran',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Harga Kamar:'),
              Text(
                'Rp ${NumberFormat('#,###').format(totalPrice)}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Biaya Admin:'),
              Text(
                'Rp ${NumberFormat('#,###').format(adminFee)}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Biaya Aplikasi:'),
              Text(
                'Rp ${NumberFormat('#,###').format(appFee)}',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Pembayaran:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Rp ${NumberFormat('#,###').format(grandTotal)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
