import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

class ShippingPaymentScreen extends StatefulWidget {
  final Map<String, dynamic> shippingData;
  final Map<String, dynamic> paymentMethod;

  const ShippingPaymentScreen({
    required this.shippingData,
    required this.paymentMethod,
    Key? key,
  }) : super(key: key);

  @override
  State<ShippingPaymentScreen> createState() => _ShippingPaymentScreenState();
}

class _ShippingPaymentScreenState extends State<ShippingPaymentScreen> {
  final supabase = Supabase.instance.client;
  String? paymentProofUrl;
  bool isUploading = false;

  Future<void> _uploadPaymentProof() async {
    try {
      setState(() => isUploading = true);

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final fileName = 'shipping_${widget.shippingData['id']}_${DateTime.now().millisecondsSinceEpoch}.png';

        print('Debug: Uploading file: $fileName');
        print('Debug: File size: ${bytes.length} bytes');

        // Upload ke storage bucket
        final uploadResponse = await supabase.storage
            .from('payment-proofs')
            .uploadBinary(fileName, bytes);

        print('Debug: Upload response: $uploadResponse');

        final String publicUrl =
            supabase.storage.from('payment-proofs').getPublicUrl(fileName);

        print('Debug: Public URL: $publicUrl');

        setState(() => paymentProofUrl = publicUrl);

        // Update shipping_requests dengan bukti pembayaran
        final updateResponse = await supabase
            .from('shipping_requests')
            .update({
              'payment_proof': paymentProofUrl, 
              'status': 'waiting_verification'
            })
            .eq('id', widget.shippingData['id'])
            .select();

        print('Debug: Update response: $updateResponse');

        Get.snackbar(
          'Sukses',
          'Bukti pembayaran berhasil diupload',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      print('Error uploading payment proof: $e');
      
      // Pesan error yang lebih spesifik
      String errorMessage = 'Gagal mengupload bukti pembayaran';
      if (e.toString().contains('storage')) {
        errorMessage = 'Gagal menyimpan file. Periksa koneksi internet.';
      } else if (e.toString().contains('shipping_requests')) {
        errorMessage = 'Gagal memperbarui status pembayaran.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Tidak memiliki izin untuk mengupload file.';
      }
      
      Get.snackbar(
        'Error',
        errorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: Duration(seconds: 5),
      );
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCOD = widget.paymentMethod['name'].toString().toLowerCase().contains('cod');
    final total = widget.shippingData['estimated_cost'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pembayaran Pengiriman', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Header Total Pembayaran
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        'Rp ${NumberFormat('#,###').format(total)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Detail Pengiriman
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_shipping, color: AppTheme.primary, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Detail Pengiriman',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      Divider(height: 20),
                      _buildDetailRow('Nama Barang', widget.shippingData['item_name'] ?? '-'),
                      _buildDetailRow('Layanan Pengiriman', widget.shippingData['shipping_method_name'] ?? '-'),
                      _buildDetailRow('Metode Pembayaran', widget.paymentMethod['name'] ?? '-'),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),

              if (!isCOD) ...[
                // Instruksi Pembayaran untuk non-COD
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Instruksi Pembayaran',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              _buildPaymentDetailRow('Bank', widget.paymentMethod['name']),
                              if (widget.paymentMethod['account_number'] != null) ...[
                                Divider(height: 20),
                                _buildPaymentDetailRow('No. Rekening', widget.paymentMethod['account_number']),
                              ],
                              if (widget.paymentMethod['account_name'] != null) ...[
                                Divider(height: 20),
                                _buildPaymentDetailRow('Atas Nama', widget.paymentMethod['account_name']),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catatan Penting:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '• Transfer sesuai nominal yang tertera\n'
                                '• Simpan bukti pembayaran dengan baik\n'
                                '• Konfirmasi pembayaran diproses dalam 1x24 jam\n'
                                '• Hubungi admin jika ada kendala',
                                style: TextStyle(fontSize: 13, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Upload Bukti Pembayaran
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.upload_file, color: AppTheme.primary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Upload Bukti Pembayaran',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        if (paymentProofUrl != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              paymentProofUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'Bukti Pembayaran Berhasil Diupload',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    fontSize: 16,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Mohon tunggu verifikasi dari admin',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.green.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (paymentProofUrl == null) ...[
                          Container(
                            width: double.infinity,
                            height: 150,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade50,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 48, color: Colors.grey.shade400),
                                SizedBox(height: 8),
                                Text(
                                  'Pilih foto bukti pembayaran',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: isUploading ? null : _uploadPaymentProof,
                              icon: isUploading
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(Icons.camera_alt, color: Colors.white),
                              label: Text(
                                isUploading ? 'Mengupload...' : 'Upload Bukti Pembayaran',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                        if (paymentProofUrl != null) ...[
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => Get.offAll(() => BuyerHomeScreen()),
                              icon: Icon(Icons.home, color: Colors.white),
                              label: Text(
                                'Kembali ke Beranda',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              
              // Tombol untuk COD
              if (isCOD)
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.handshake, size: 48, color: AppTheme.primary),
                        SizedBox(height: 12),
                        Text(
                          'Pembayaran Cash on Delivery (COD)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Pembayaran akan dilakukan saat barang sampai di tujuan',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () => Get.offAll(() => BuyerHomeScreen()),
                            icon: Icon(Icons.check_circle, color: Colors.white),
                            label: Text(
                              'Konfirmasi COD & Kembali ke Beranda',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Text(': ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13)),
        Row(
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (label == 'No. Rekening')
              IconButton(
                icon: Icon(Icons.copy, color: AppTheme.primary),
                onPressed: () {
                  // Salin nomor rekening
                  Clipboard.setData(ClipboardData(text: value)).then((_) {
                    Get.snackbar(
                      'Sukses',
                      'Nomor rekening disalin ke clipboard',
                      backgroundColor: Colors.green,
                      colorText: Colors.white,
                    );
                  });
                },
              ),
          ],
        ),
      ],
    );
  }
}
