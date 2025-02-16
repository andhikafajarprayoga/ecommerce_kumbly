import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/screens/home_screen.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../home_screen.dart';

class HotelBookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const HotelBookingDetailScreen({
    Key? key,
    required this.booking,
  }) : super(key: key);

  @override
  State<HotelBookingDetailScreen> createState() =>
      _HotelBookingDetailScreenState();
}

class _HotelBookingDetailScreenState extends State<HotelBookingDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isUploading = false;
  String? paymentMethodName;
  String? accountNumber;

  @override
  void initState() {
    super.initState();
    fetchPaymentMethodName();
  }

  Future<void> fetchPaymentMethodName() async {
    try {
      if (widget.booking['payment_method_id'] != null) {
        final response = await supabase
            .from('payment_methods')
            .select('name, account_number')
            .eq('id', widget.booking['payment_method_id'])
            .single();
        setState(() {
          paymentMethodName = response['name'];
          accountNumber = response['account_number'];
        });
      }
    } catch (e) {
      print('Error fetching payment method: $e');
    }
  }

  Future<void> _uploadPaymentProof() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => isUploading = true);

      // Upload image to storage
      final String path =
          'payment_proofs/${widget.booking['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File file = File(image.path);

      await supabase.storage.from('hotel-bookings').upload(path, file);

      final String publicUrl =
          supabase.storage.from('hotel-bookings').getPublicUrl(path);

      await supabase
          .from('hotel_bookings')
          .update({'image_url': publicUrl}).eq('id', widget.booking['id']);

      setState(() {
        widget.booking['image_url'] = publicUrl;
      });

      Get.snackbar(
        'Sukses',
        'Bukti pembayaran berhasil diunggah',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Tambahkan delay sebentar sebelum kembali ke BuyerHomeScreen
      await Future.delayed(Duration(seconds: 2));

      // Kembali ke BuyerHomeScreen dengan tab hotel (index 2)
      Get.off(() => BuyerHomeScreen(), arguments: {'selectedIndex': 2});
    } catch (e) {
      print('Error uploading payment proof: $e');
      Get.snackbar(
        'Error',
        'Gagal mengunggah bukti pembayaran: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detail Booking',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Booking Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: AppTheme.primary,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Booking Berhasil!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildDetailRow('Booking ID', widget.booking['id']),
                    Divider(height: 24),
                    _buildDetailRow(
                      'Check-in',
                      DateFormat('dd MMM yyyy').format(
                        DateTime.parse(widget.booking['check_in']),
                      ),
                      icon: Icons.calendar_today,
                    ),
                    _buildDetailRow(
                      'Check-out',
                      DateFormat('dd MMM yyyy').format(
                        DateTime.parse(widget.booking['check_out']),
                      ),
                      icon: Icons.calendar_today,
                    ),
                    _buildDetailRow(
                      'Jumlah Malam',
                      '${widget.booking['total_nights']} malam',
                      icon: Icons.nights_stay,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Payment Info Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDetailRow(
                      'Total Harga Kamar',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(widget.booking['total_price']),
                      icon: Icons.hotel,
                    ),
                    _buildDetailRow(
                      'Biaya Admin',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(widget.booking['admin_fee']),
                      icon: Icons.payment,
                    ),
                    _buildDetailRow(
                      'Biaya Aplikasi',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(widget.booking['app_fee']),
                      icon: Icons.apps,
                    ),
                    Divider(height: 16),
                    _buildDetailRow(
                      'Total Pembayaran',
                      NumberFormat.currency(
                        locale: 'id',
                        symbol: 'Rp ',
                        decimalDigits: 0,
                      ).format(((widget.booking['total_price'] as num?) ?? 0)
                              .toDouble() +
                          ((widget.booking['admin_fee'] as num?) ?? 0)
                              .toDouble() +
                          ((widget.booking['app_fee'] as num?) ?? 0)
                              .toDouble()),
                      icon: Icons.payments,
                      isHighlighted: true,
                    ),
                    _buildDetailRow(
                      'Status',
                      widget.booking['status'].toUpperCase(),
                      icon: Icons.info,
                      statusColor: _getStatusColor(widget.booking['status']),
                    ),
                    if (paymentMethodName != null)
                      Column(
                        children: [
                          _buildDetailRow(
                            'Metode Pembayaran',
                            paymentMethodName!,
                            icon: Icons.payment,
                          ),
                          if (accountNumber != null)
                            _buildDetailRow(
                              'Nomor Rekening',
                              accountNumber!,
                              icon: Icons.account_balance,
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Payment Proof Card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bukti Pembayaran',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: widget.booking['image_url'] != null
                          ? Image.network(
                              widget.booking['image_url'],
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Belum ada bukti pembayaran',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (widget.booking['status'] == 'pending')
                      Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: ElevatedButton.icon(
                          onPressed: isUploading ? null : _uploadPaymentProof,
                          icon: Icon(
                            Icons.upload_file,
                            color: Colors.white,
                          ),
                          label: Text(
                            isUploading
                                ? 'Mengunggah...'
                                : 'Upload Bukti Pembayaran',
                            style: TextStyle(
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            minimumSize: Size(double.infinity, 45),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Guest Info Card
            SizedBox(height: 16),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Tamu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildDetailRow(
                      'Nama',
                      widget.booking['guest_name'],
                      icon: Icons.person,
                    ),
                    _buildDetailRow(
                      'Telepon',
                      widget.booking['guest_phone'],
                      icon: Icons.phone,
                    ),
                    if (widget.booking['special_requests'] != null &&
                        widget.booking['special_requests'].isNotEmpty)
                      _buildDetailRow(
                        'Permintaan Khusus',
                        widget.booking['special_requests'],
                        icon: Icons.note,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDetailRow(String label, String value,
      {IconData? icon, bool isHighlighted = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 20,
              color: statusColor ??
                  (isHighlighted ? AppTheme.primary : Colors.grey[600]),
            ),
            SizedBox(width: 8),
          ],
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
