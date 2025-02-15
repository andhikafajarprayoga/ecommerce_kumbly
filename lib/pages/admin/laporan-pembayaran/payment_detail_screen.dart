import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../controllers/reports_controller.dart';

class PaymentDetailScreen extends StatefulWidget {
  final PaymentGroup payment;

  PaymentDetailScreen({required this.payment});

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final supabase = Supabase.instance.client;
  bool isCOD = false;

  @override
  void initState() {
    super.initState();
    _checkPaymentMethod();
  }

  Future<void> _checkPaymentMethod() async {
    try {
      final response = await supabase
          .from('payment_methods')
          .select('name')
          .eq('id', widget.payment.paymentMethodId.toString())
          .single();

      setState(() {
        isCOD = response['name'].toString().toLowerCase().contains('cod');
      });
    } catch (e) {
      print('Error checking payment method: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pembayaran'),
        elevation: 0,
        actions: [
          if (widget.payment.paymentStatus == 'pending')
            IconButton(
              icon: Icon(Icons.check_circle_outline, color: Colors.green),
              onPressed: () => _confirmPayment(),
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _showDeleteConfirmation(),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              SizedBox(height: 16),
              if (!isCOD && widget.payment.paymentProof != null)
                _buildPaymentProof(),
              if (isCOD)
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade50, Colors.white],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.local_shipping, color: Colors.blue),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Pembayaran dilakukan saat barang sampai (COD)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              height: 1.5,
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

  Widget _buildInfoCard() {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('ID Pembayaran', widget.payment.id),
            Divider(height: 16),
            _buildInfoRow(
                'Status', _buildStatusChip(widget.payment.paymentStatus)),
            Divider(height: 16),
            _buildInfoRow('Pembeli', widget.payment.buyerName),
            _buildInfoRow('Email', widget.payment.buyerEmail),
            Divider(height: 16),
            _buildInfoRow(
                'Total', currencyFormatter.format(widget.payment.totalAmount)),
            _buildInfoRow('Biaya Admin',
                currencyFormatter.format(widget.payment.adminFee)),
            _buildInfoRow('Biaya Pengiriman',
                currencyFormatter.format(widget.payment.shippingCost)),
            Divider(height: 16),
            _buildInfoRow(
                'Tanggal',
                DateFormat('dd MMM yyyy HH:mm')
                    .format(widget.payment.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentProof() {
    if (isCOD ||
        widget.payment.paymentProof == null ||
        widget.payment.paymentProof == 'COD' ||
        !widget.payment.paymentProof!.startsWith('http')) {
      return SizedBox.shrink();
    }

    return Card(
      elevation: 2,
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
                color: Colors.blue.shade700,
              ),
            ),
            SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.payment.paymentProof!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            child: value is Widget
                ? value
                : Text(
                    value.toString(),
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String statusText;
    switch (status.toLowerCase()) {
      case 'success':
        color = Colors.green;
        statusText = 'SUKSES';
        break;
      case 'pending':
        color = Colors.orange;
        statusText = 'MENUNGGU';
        break;
      case 'failed':
        color = Colors.red;
        statusText = 'GAGAL';
        break;
      default:
        color = Colors.grey;
        statusText = status.toUpperCase();
    }

    return GestureDetector(
      onTap: () => _showStatusChangeDialog(status),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              statusText,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 12,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusChangeDialog(String currentStatus) {
    String? newStatus = currentStatus;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ubah Status Pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: Text('Menunggu'),
              value: 'pending',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
            RadioListTile<String>(
              title: Text('Menunggu Pembatalan'),
              value: 'pending_cancellation',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
            RadioListTile<String>(
              title: Text('Diproses'),
              value: 'processing',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
            RadioListTile<String>(
              title: Text('Transit'),
              value: 'transit',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
            RadioListTile<String>(
              title: Text('Pengiriman'),
              value: 'shipping',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
            RadioListTile<String>(
              title: Text('Terkirim'),
              value: 'delivered',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
            RadioListTile<String>(
              title: Text('Selesai'),
              value: 'completed',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
            RadioListTile<String>(
              title: Text('Dibatalkan'),
              value: 'cancelled',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
            RadioListTile<String>(
              title: Text('Ke Cabang'),
              value: 'to_branch',
              groupValue: newStatus,
              onChanged: (value) => setState(() => newStatus = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await supabase
                    .from('orders')
                    .update({'status': newStatus}).eq('id', widget.payment.id);

                Get.back(result: true);

                Get.snackbar(
                  'Sukses',
                  'Status pesanan berhasil diperbarui',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              } catch (e) {
                print('Error updating order status: $e');
                Get.snackbar(
                  'Error',
                  'Gagal memperbarui status pesanan',
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmPayment() async {
    try {
      await supabase
          .from('payment_groups')
          .update({'payment_status': 'success'}).eq('id', widget.payment.id);

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Status pembayaran berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal memperbarui status pembayaran',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showDeleteConfirmation() {
    Get.dialog(
      AlertDialog(
        title: Text('Hapus Pembayaran'),
        content: Text('Yakin ingin menghapus data pembayaran ini?'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              _deletePayment();
            },
            child: Text(
              'Hapus',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePayment() async {
    try {
      await supabase
          .from('payment_groups')
          .delete()
          .eq('id', widget.payment.id);

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Data pembayaran berhasil dihapus',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal menghapus data pembayaran',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
