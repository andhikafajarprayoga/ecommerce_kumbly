import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../../../pages/buyer/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class PaymentScreen extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final Map<String, dynamic> paymentMethod;

  PaymentScreen({
    required this.orderData,
    required this.paymentMethod,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final supabase = Supabase.instance.client;
  String? paymentProofUrl;
  bool isUploading = false;
  List<Map<String, dynamic>> orderItems = [];

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    try {
      // Ambil order items berdasarkan payment_group_id
      final response = await supabase
        .from('orders')
        .select('''
          *,
          order_items!inner (
            id,
            quantity,
            price,
            product:products (
              id,
              name,
              image_url,
              description
            )
          )
        ''')
        .eq('payment_group_id', widget.orderData['payment_group_id']);

      setState(() {
        orderItems = List<Map<String, dynamic>>.from(response);
      });
      
      print('Debug: Order items fetched: $orderItems');
    } catch (e) {
      print('Error fetching order details: $e');
    }
  }

  // Widget untuk menampilkan daftar produk
  Widget _buildOrderItems() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detail Pesanan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            ...orderItems.expand((order) {
              final items = List<Map<String, dynamic>>.from(order['order_items']);
              return items.map((item) {
                final product = item['product'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Foto Produk
                      if (product['image_url'] != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            product['image_url'],
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[200],
                                child: Icon(Icons.image_not_supported, 
                                  color: Colors.grey[400]),
                              );
                            },
                          ),
                        ),
                      SizedBox(width: 12),
                      
                      // Detail Produk
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] ?? 'Produk',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${item['quantity']} x Rp${NumberFormat('#,###').format(item['price'])}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Total: Rp${NumberFormat('#,###').format(item['quantity'] * item['price'])}',
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              });
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPaymentProof() async {
    try {
      setState(() => isUploading = true);

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final bytes = await image.readAsBytes();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.png';

        // Upload bukti pembayaran ke storage bucket
        await supabase.storage
            .from('payment-proofs')
            .uploadBinary(fileName, bytes);

        final String publicUrl =
            supabase.storage.from('payment-proofs').getPublicUrl(fileName);

        setState(() => paymentProofUrl = publicUrl);

        // Insert ke tabel payment_groups
        final response = await supabase.from('payment_groups').insert({
          'buyer_id': supabase.auth.currentUser!.id,
          'total_amount': widget.orderData['total_amount'],
          'payment_method_id': widget.paymentMethod['id'],
          'payment_status': 'pending',
          'payment_proof': paymentProofUrl,
          'admin_fee': 0,
        }).select();

        print('Payment group created: $response'); // Untuk debugging

        Get.snackbar(
          'Sukses',
          'Bukti pembayaran berhasil diupload',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      print('Error uploading payment proof: $e');
      Get.snackbar(
        'Error',
        'Gagal mengupload bukti pembayaran',
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
        title: Text('Pembayaran', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              // Total Pembayaran
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        'Rp ${NumberFormat('#,###').format(widget.orderData['total_amount'])}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Detail Pesanan
              _buildOrderItems(),
              SizedBox(height: 12),

              // Instruksi Pembayaran
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Instruksi Pembayaran',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildPaymentDetailRow(
                                'Bank', widget.paymentMethod['name']),
                            Divider(height: 16),
                            _buildPaymentDetailRow('No. Rekening',
                                widget.paymentMethod['account_number']),
                            Divider(height: 16),
                            _buildPaymentDetailRow('Atas Nama',
                                widget.paymentMethod['account_name']),
                          ],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text('Catatan:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(height: 4),
                      Text(
                        '1. Transfer sesuai nominal yang tertera\n'
                        '2. Simpan bukti pembayaran\n'
                        '3. Konfirmasi diproses dalam 1x24 jam',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),

              // Upload Bukti Pembayaran
              Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Bukti Pembayaran',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      if (paymentProofUrl != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            paymentProofUrl!,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Bukti Pembayaran Diterima',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Mohon tunggu konfirmasi dari penjual',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (paymentProofUrl == null) ...[
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: isUploading ? null : _uploadPaymentProof,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isUploading)
                                Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                ),
                              Text(
                                isUploading
                                    ? 'Mengupload...'
                                    : 'Upload Bukti Pembayaran',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (paymentProofUrl != null) ...[
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => Get.offAll(() => BuyerHomeScreen()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Kembali ke Beranda',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget untuk detail pembayaran
  Widget _buildPaymentDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13)),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }
}
