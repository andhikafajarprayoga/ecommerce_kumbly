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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Pembayaran'),
        actions: [
          if (widget.payment.paymentStatus == 'pending')
            IconButton(
              icon: Icon(Icons.check_circle_outline),
              onPressed: () => _confirmPayment(),
            ),
          IconButton(
            icon: Icon(Icons.delete_outline),
            onPressed: () => _showDeleteConfirmation(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            SizedBox(height: 16),
            if (widget.payment.paymentProof != null) _buildPaymentProof(),
          ],
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
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('ID Pembayaran', widget.payment.id),
            _buildInfoRow(
                'Status', _buildStatusChip(widget.payment.paymentStatus)),
            _buildInfoRow('Pembeli', widget.payment.buyerName),
            _buildInfoRow('Email', widget.payment.buyerEmail),
            _buildInfoRow(
                'Total', currencyFormatter.format(widget.payment.totalAmount)),
            _buildInfoRow('Biaya Admin',
                currencyFormatter.format(widget.payment.adminFee)),
            _buildInfoRow('Biaya Pengiriman',
                currencyFormatter.format(widget.payment.shippingCost)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bukti Pembayaran',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            widget.payment.paymentProof!,
            fit: BoxFit.cover,
          ),
        ),
      ],
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
    switch (status.toLowerCase()) {
      case 'success':
        color = Colors.green;
        break;
      case 'pending':
        color = Colors.orange;
        break;
      case 'failed':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
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
