import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentGroup {
  final String id;
  final String buyerName;
  final double totalAmount;
  final double adminFee;
  final double shippingCost;
  final String status;
  final DateTime createdAt;
  final String? paymentProof;

  PaymentGroup({
    required this.id,
    required this.buyerName,
    required this.totalAmount,
    required this.adminFee,
    required this.shippingCost,
    required this.status,
    required this.createdAt,
    this.paymentProof,
  });

  factory PaymentGroup.fromJson(Map<String, dynamic> json) {
    return PaymentGroup(
      id: json['id'],
      buyerName: json['buyer']['email'] ?? 'Unknown',
      totalAmount: (json['total_amount'] as num).toDouble(),
      adminFee: (json['admin_fee'] as num).toDouble(),
      shippingCost: (json['total_shipping_cost'] as num).toDouble(),
      status: json['payment_status'],
      createdAt: DateTime.parse(json['created_at']),
      paymentProof: json['payment_proof'],
    );
  }
}

class ReportsController extends GetxController {
  final _supabase = Supabase.instance.client;

  var startDate = DateTime.now().subtract(Duration(days: 30)).obs;
  var endDate = DateTime.now().obs;
  var selectedStatus = 'Semua'.obs;

  var payments = <PaymentGroup>[].obs;
  var isLoading = false.obs;

  var totalTransactions = 0.obs;
  var totalIncome = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    isLoading.value = true;
    try {
      var query = _supabase
          .from('payment_groups')
          .select('''
            id,
            total_amount,
            admin_fee,
            total_shipping_cost,
            payment_status,
            payment_proof,
            created_at,
            profiles:buyer_id (
              email
            )
          ''')
          .gte('created_at', startDate.value.toIso8601String())
          .lte('created_at', endDate.value.toIso8601String());

      if (selectedStatus.value != 'Semua') {
        query = query.eq('payment_status', selectedStatus.value);
      }

      final response = await query;

      payments.value = (response as List).map((data) {
        return PaymentGroup(
          id: data['id'],
          buyerName: data['profiles']?['email'] ?? 'Unknown',
          totalAmount: (data['total_amount'] as num).toDouble(),
          adminFee: (data['admin_fee'] as num).toDouble(),
          shippingCost: (data['total_shipping_cost'] as num).toDouble(),
          status: data['payment_status'],
          createdAt: DateTime.parse(data['created_at']),
          paymentProof: data['payment_proof'],
        );
      }).toList();

      totalTransactions.value = payments.length;
      totalIncome.value = payments
          .where((p) => p.status == 'success')
          .fold(0.0, (sum, payment) => sum + payment.totalAmount);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengambil data pembayaran: $e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void updateDateRange(DateTime start, DateTime end) {
    startDate.value = start;
    endDate.value = end;
    fetchPayments();
  }

  void updateStatus(String status) {
    selectedStatus.value = status;
    fetchPayments();
  }
}
