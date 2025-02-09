import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../../theme/app_theme.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client; // Deklarasi supabase di level file

class DetailPesananHotelScreen extends StatelessWidget {
  final Map<String, dynamic> booking;

  const DetailPesananHotelScreen({Key? key, required this.booking})
      : super(key: key);

  String formatDate(String date) {
    final DateTime dateTime = DateTime.parse(date);
    return DateFormat('dd MMM yyyy').format(dateTime);
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

  Future<void> _uploadPaymentProof() async {
    try {
      // Pilih gambar dari galeri
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image == null) return;

      // Upload gambar ke storage dengan path yang benar
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(image.path)}';
      final String storagePath =
          'payment_proofs/$fileName'; // Tambahkan folder payment_proofs

      // Gunakan nama bucket yang tepat sesuai di Supabase (dengan dash)
      final storageResponse = await supabase.storage
          .from('hotel-bookings') // Gunakan dash sesuai nama bucket di Supabase
          .upload(storagePath, File(image.path));

      // Dapatkan URL gambar dengan path yang benar
      final String imageUrl =
          supabase.storage.from('hotel-bookings').getPublicUrl(storagePath);

      // Update booking dengan URL bukti pembayaran
      await supabase.from('hotel_bookings').update({
        'image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', booking['id']);

      Get.back(); // Kembali ke halaman sebelumnya
      Get.snackbar(
        'Berhasil',
        'Bukti pembayaran berhasil diunggah',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error uploading payment proof: $e');
      Get.snackbar(
        'Gagal',
        'Terjadi kesalahan saat mengunggah bukti pembayaran',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primary,
        title: Text(
          'Detail Pesanan Hotel',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.normal),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Card
            Container(
              color: AppTheme.primary,
              padding: EdgeInsets.all(16),
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Booking ID',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '#${booking['id'].toString().substring(0, 8)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildStatusChip(booking['status']),
                  ],
                ),
              ),
            ),

            // Upload Bukti Pembayaran Button
            if (booking['image_url'] == null && booking['status'] == 'pending')
              Container(
                margin: EdgeInsets.all(16),
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploadPaymentProof,
                  icon: Icon(Icons.upload_file, color: Colors.white),
                  label: Text(
                    'Upload Bukti Pembayaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

            // Detail Sections
            _buildSection(
              'Detail Hotel',
              [
                _buildDetailRow('Nama Hotel',
                    booking['hotels']?['name'] ?? 'Unknown Hotel'),
                _buildDetailRow('Tipe Kamar', booking['room_type'] ?? '-'),
                _buildDetailRow('Check-in', formatDate(booking['check_in'])),
                _buildDetailRow('Check-out', formatDate(booking['check_out'])),
                _buildDetailRow(
                    'Jumlah Malam', '${booking['total_nights']} malam'),
                if (booking['hotels']?['address'] != null)
                  _buildDetailRow('Alamat', booking['hotels']['address']),
              ],
            ),

            _buildSection(
              'Detail Tamu',
              [
                _buildDetailRow('Nama Tamu', booking['guest_name']),
                _buildDetailRow('Telepon', booking['guest_phone']),
                if (booking['special_requests'] != null)
                  _buildDetailRow(
                      'Permintaan Khusus', booking['special_requests']),
              ],
            ),

            _buildSection(
              'Detail Pembayaran',
              [
                _buildDetailRow(
                    'Total Pembayaran', formatCurrency(booking['total_price'])),
                _buildDetailRow(
                    'Biaya Admin', formatCurrency(booking['admin_fee'])),
                _buildDetailRow(
                    'Biaya Aplikasi', formatCurrency(booking['app_fee'])),
                Divider(height: 24),
                _buildDetailRow(
                  'Total yang Harus Dibayar',
                  formatCurrency(booking['total_price'] +
                      (booking['admin_fee'] ?? 0) +
                      (booking['app_fee'] ?? 0)),
                  isTotal: true,
                ),
              ],
            ),

            // Bukti Pembayaran Section
            if (booking['image_url'] != null)
              _buildSection(
                'Bukti Pembayaran',
                [
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(booking['image_url']),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                color: isTotal ? AppTheme.primary : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color statusColor;
    String statusText;

    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Menunggu Pembayaran';
        break;
      case 'confirmed':
        statusColor = Colors.green;
        statusText = 'Dikonfirmasi';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'Selesai';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Dibatalkan';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status.toUpperCase();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: statusColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
