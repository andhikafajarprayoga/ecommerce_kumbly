import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/reports_controller.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../pages/admin/laporan-pembayaran/payment_detail_screen.dart';
import 'withdrawal_screen.dart';
import '../../../theme/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ReportsController controller = Get.put(ReportsController());
  final currencyFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ');
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeRealtime();
  }

  void _initializeRealtime() {
    final supabase = Supabase.instance.client;

    // Initial fetch
    controller.fetchPayments();

    // Setup realtime subscription
    final _subscription = supabase.realtime
        .channel('public:payment_groups')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payment_groups',
          callback: (payload) {
            // Refresh data when changes occur
            controller.fetchPayments();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit Pesanan',
          style: TextStyle(
              color: const Color.fromARGB(221, 255, 255, 255),
              fontWeight: FontWeight.normal),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 0,
        iconTheme:
            IconThemeData(color: const Color.fromARGB(221, 255, 255, 255)),
      ),
      body: Container(
        color: Colors.grey[100],
        child: Column(
          children: [
            _buildFilterSection(),
            SizedBox(height: 16),
            _buildWithdrawalButton(),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return Center(child: CircularProgressIndicator());
                }

                if (controller.payments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Tidak ada data pembayaran',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return _buildPaymentList();
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      margin: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateRangePicker(),
                ),
                SizedBox(width: 8),
                _buildStatusFilter(),
              ],
            ),
          ],
        ),
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

  Widget _buildPaymentList() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: controller.payments.length,
      itemBuilder: (context, index) {
        final payment = controller.payments[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () async {
              final result =
                  await Get.to(() => PaymentDetailScreen(payment: payment));
              if (result == true) {
                controller.fetchPayments();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ID: ${payment.id.substring(0, 8)}...',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      _buildStatusChip(payment.paymentStatus),
                    ],
                  ),
                  SizedBox(height: 8),
                  _buildInfoRow(
                      Icons.person_outline, 'Pembeli', payment.buyerName),
                  SizedBox(height: 4),
                  _buildInfoRow(
                    Icons.payments_outlined,
                    'Total',
                    currencyFormatter.format(payment.totalAmount),
                  ),
                  SizedBox(height: 4),
                  _buildInfoRow(
                    Icons.calendar_today_outlined,
                    'Tanggal',
                    DateFormat('dd MMM yyyy HH:mm').format(payment.createdAt),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        SizedBox(width: 4),
        Text(
          '$label: $value',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawalButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
