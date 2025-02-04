import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/reports_controller.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatelessWidget {
  final ReportsController controller = Get.put(ReportsController());
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');

  ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Laporan Pembayaran',
          style: TextStyle(color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          _buildSummaryCards(),
          Expanded(
            child: _buildPaymentList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildDateRangePicker(),
          ),
          SizedBox(width: 8),
          _buildStatusFilter(),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Obx(() => OutlinedButton.icon(
          icon: Icon(Icons.date_range),
          label: Text(
            '${DateFormat('dd/MM/yyyy').format(controller.startDate.value)} - '
            '${DateFormat('dd/MM/yyyy').format(controller.endDate.value)}',
          ),
          onPressed: () async {
            DateTimeRange? result = await showDateRangePicker(
              context: Get.context!,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              currentDate: DateTime.now(),
            );
            if (result != null) {
              controller.updateDateRange(result.start, result.end);
            }
          },
        ));
  }

  Widget _buildStatusFilter() {
    return Obx(() => DropdownButton<String>(
          value: controller.selectedStatus.value,
          items: ['Semua', 'pending', 'success', 'failed']
              .map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  ))
              .toList(),
          onChanged: (value) {
            controller.updateStatus(value ?? 'Semua');
          },
        ));
  }

  Widget _buildSummaryCards() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Obx(() => Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Transaksi',
                  controller.totalTransactions.toString(),
                  Icons.receipt_long,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Total Pendapatan',
                  currencyFormatter.format(controller.totalIncome.value),
                  Icons.payments,
                  Colors.green,
                ),
              ),
            ],
          )),
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentList() {
    return Obx(() {
      if (controller.isLoading.value) {
        return Center(child: CircularProgressIndicator());
      }
      return ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: controller.payments.length,
        itemBuilder: (context, index) {
          final payment = controller.payments[index];
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text('ID: ${payment.id.substring(0, 8)}...'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pembeli: ${payment.buyerName}'),
                  Text(
                    'Total: ${currencyFormatter.format(payment.totalAmount)}',
                  ),
                ],
              ),
              trailing: _buildStatusChip(payment.status),
              onTap: () => _showPaymentDetails(payment),
            ),
          );
        },
      );
    });
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
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

    return Chip(
      label: Text(
        status,
        style: TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }

  void _showPaymentDetails(PaymentGroup payment) {
    Get.dialog(
      AlertDialog(
        title: Text('Detail Pembayaran'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ID: ${payment.id}'),
              Text('Pembeli: ${payment.buyerName}'),
              Text('Total: ${currencyFormatter.format(payment.totalAmount)}'),
              Text(
                  'Biaya Admin: ${currencyFormatter.format(payment.adminFee)}'),
              Text(
                'Biaya Pengiriman: ${currencyFormatter.format(payment.shippingCost)}',
              ),
              Text('Status: ${payment.status}'),
              Text(
                'Tanggal: ${DateFormat('dd/MM/yyyy HH:mm').format(payment.createdAt)}',
              ),
              if (payment.paymentProof != null) ...[
                SizedBox(height: 8),
                Text('Bukti Pembayaran:'),
                Image.network(
                  payment.paymentProof!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Tutup'),
          ),
        ],
      ),
    );
  }
}
