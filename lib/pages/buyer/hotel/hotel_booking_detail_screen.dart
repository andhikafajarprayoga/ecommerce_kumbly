import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
            .select('name')
            .eq('id', widget.booking['payment_method_id'])
            .single();
        setState(() {
          paymentMethodName = response['name'];
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

      // Upload ke bucket 'hotel-bookings'
      await supabase.storage.from('hotel-bookings').upload(path, file);

      // Dapatkan public URL yang benar
      final String publicUrl =
          supabase.storage.from('hotel-bookings').getPublicUrl(path);

      // Update booking record
      await supabase
          .from('hotel_bookings')
          .update({'image_url': publicUrl}).eq('id', widget.booking['id']);

      // Update local state
      setState(() {
        widget.booking['image_url'] = publicUrl;
      });

      Get.snackbar(
        'Sukses',
        'Bukti pembayaran berhasil diunggah',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error uploading payment proof: $e'); // Tambahkan log error
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
        title: Text('Detail Booking'),
        backgroundColor: AppTheme.primary,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking Berhasil!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Booking ID: ${widget.booking['id']}',
                      style: TextStyle(fontSize: 16),
                    ),
                    Divider(height: 24),
                    _buildDetailRow(
                        'Check-in',
                        DateFormat('dd MMM yyyy').format(
                            DateTime.parse(widget.booking['check_in']))),
                    _buildDetailRow(
                        'Check-out',
                        DateFormat('dd MMM yyyy').format(
                            DateTime.parse(widget.booking['check_out']))),
                    _buildDetailRow('Jumlah Malam',
                        '${widget.booking['total_nights']} malam'),
                    _buildDetailRow(
                        'Total Pembayaran',
                        NumberFormat.currency(
                          locale: 'id',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(widget.booking['total_price'])),
                    _buildDetailRow(
                        'Status', widget.booking['status'].toUpperCase()),
                    if (paymentMethodName != null)
                      _buildDetailRow('Metode Pembayaran', paymentMethodName!),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Payment Proof Section
            Card(
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
                    if (widget.booking['image_url'] != null)
                      Image.network(
                        widget.booking['image_url'],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(
                        height: 200,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: Center(
                          child: Text('Belum ada bukti pembayaran'),
                        ),
                      ),
                    SizedBox(height: 16),
                    if (widget.booking['status'] == 'pending')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isUploading ? null : _uploadPaymentProof,
                          icon: Icon(Icons.upload),
                          label: Text(isUploading
                              ? 'Mengunggah...'
                              : 'Upload Bukti Pembayaran'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),
            Card(
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
                    SizedBox(height: 8),
                    _buildDetailRow('Nama', widget.booking['guest_name']),
                    _buildDetailRow('Telepon', widget.booking['guest_phone']),
                    if (widget.booking['special_requests'] != null &&
                        widget.booking['special_requests'].isNotEmpty)
                      _buildDetailRow('Permintaan Khusus',
                          widget.booking['special_requests']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
