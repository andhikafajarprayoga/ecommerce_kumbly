import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentGroup {
  final String id;
  final String buyerId;
  final double totalAmount;
  final int? paymentMethodId;
  final String paymentStatus;
  final String? paymentProof;
  final DateTime createdAt;
  final double adminFee;
  final double shippingCost;
  final Map<String, dynamic>? profiles;

  PaymentGroup({
    required this.id,
    required this.buyerId,
    required this.totalAmount,
    this.paymentMethodId,
    required this.paymentStatus,
    this.paymentProof,
    required this.createdAt,
    required this.adminFee,
    required this.shippingCost,
    this.profiles,
  });

  String get buyerName => profiles?['full_name'] ?? 'Unknown';
  String get buyerEmail => profiles?['email'] ?? 'No email';

  factory PaymentGroup.fromJson(Map<String, dynamic> json) {
    return PaymentGroup(
      id: json['id'],
      buyerId: json['buyer_id'],
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentMethodId: json['payment_method_id'],
      paymentStatus: json['payment_status'] ?? 'pending',
      paymentProof: json['payment_proof'],
      createdAt: DateTime.parse(json['created_at']),
      adminFee: (json['admin_fee'] as num?)?.toDouble() ?? 0.0,
      shippingCost: (json['total_shipping_cost'] as num?)?.toDouble() ?? 0.0,
      profiles: json['profiles'],
    );
  }
}

class ReportsController extends GetxController {
  final supabase = Supabase.instance.client;
  final payments = <PaymentGroup>[].obs;
  final isLoading = false.obs;
  final startDate = DateTime.now().subtract(Duration(days: 30)).obs;
  final endDate = DateTime.now().obs;
  final selectedStatus = 'Semua'.obs;
  final totalTransactions = 0.obs;
  final totalIncome = 0.0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchPayments();
  }

  Future<void> fetchPayments() async {
    try {
      isLoading.value = true;

      // Ambil semua transaksi
      final paymentResponse = await supabase
          .from('payment_groups')
          .select('*') // Ambil semua data tanpa join
          .gte('created_at', startDate.value.toIso8601String())
          .lte('created_at', endDate.value.toIso8601String());

      List<PaymentGroup> fetchedPayments = [];
      double income = 0.0;
      int transactions = 0;

      for (var payment in paymentResponse as List) {
        // Ambil data user berdasarkan buyer_id
        final profileResponse = await supabase
            .from('users') // Ganti dengan tabel user yang benar
            .select('full_name, email')
            .eq('id', payment['buyer_id'])
            .maybeSingle(); // Jika tidak ada, hasilnya null

        // Gabungkan data
        fetchedPayments.add(PaymentGroup.fromJson({
          ...payment,
          'profiles': profileResponse, // Tambahkan data user
        }));

        // Hitung total transaksi dan total pendapatan
        income += (payment['total_amount'] as num).toDouble();
        transactions++;
      }

      payments.value = fetchedPayments;
      totalIncome.value = income;
      totalTransactions.value = transactions;
    } catch (e) {
      print('Error fetching payments: $e');
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
