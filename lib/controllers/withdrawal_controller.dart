import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/withdrawal_request.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

class WithdrawalController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxList<WithdrawalRequest> withdrawalRequests =
      <WithdrawalRequest>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchWithdrawalRequests();
  }

  Future<void> fetchWithdrawalRequests() async {
    isLoading.value = true;
    try {
      final response = await _supabase.from('withdrawal_requests').select('''
            id, 
            amount, 
            status, 
            created_at, 
            fee_amount, 
            transfer_proof_url,
            merchant_id,
            bank_account_id,
            merchants (
              store_name
            ),
            bank_accounts:bank_account_id (
              bank_name,
              account_number,
              account_holder,
              is_active
            )
          ''').order('created_at', ascending: false);

      print('Response data: $response'); // Untuk debugging

      withdrawalRequests.value = response
          .map<WithdrawalRequest>((json) => WithdrawalRequest.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching data: $e'); // Untuk debugging
      Get.snackbar(
        'Error',
        'Gagal memuat data pencairan',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updateWithdrawalStatus(String id, String status) async {
    try {
      await _supabase
          .from('withdrawal_requests')
          .update({'status': status}).eq('id', id);

      await fetchWithdrawalRequests();
      Get.snackbar(
        'Sukses',
        'Status pencairan berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Gagal memperbarui status');
    }
  }

  Future<void> uploadTransferProof(String id, XFile image) async {
    try {
      final String path = 'withdrawal/${id}.${image.path.split('.').last}';
      final bytes = await image.readAsBytes();

      await _supabase.storage.from('payment-proofs').uploadBinary(path, bytes);

      final String publicUrl =
          _supabase.storage.from('payment-proofs').getPublicUrl(path);

      await _supabase
          .from('withdrawal_requests')
          .update({'transfer_proof_url': publicUrl}).eq('id', id);

      await fetchWithdrawalRequests();
      Get.snackbar(
        'Sukses',
        'Bukti transfer berhasil diupload',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal mengupload bukti transfer: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  double getTotalAmount() {
    return withdrawalRequests.fold(0, (sum, request) => sum + request.amount);
  }

  double getApprovedAmount() {
    return withdrawalRequests
        .where((request) => request.status.toLowerCase() == 'approved')
        .fold(0, (sum, request) => sum + request.amount);
  }

  double getPendingAmount() {
    return withdrawalRequests
        .where((request) => request.status.toLowerCase() == 'pending')
        .fold(0, (sum, request) => sum + request.amount);
  }

  double getRejectedAmount() {
    return withdrawalRequests
        .where((request) => request.status.toLowerCase() == 'rejected')
        .fold(0, (sum, request) => sum + request.amount);
  }

  List<WithdrawalRequest> get filteredRequests {
    if (searchQuery.value.isEmpty) {
      return withdrawalRequests;
    }
    return withdrawalRequests
        .where((request) =>
            request.merchantId
                .toLowerCase()
                .contains(searchQuery.value.toLowerCase()) ||
            (request.merchantName
                    ?.toLowerCase()
                    .contains(searchQuery.value.toLowerCase()) ??
                false))
        .toList();
  }

  void updateSearchQuery(String query) {
    searchQuery.value = query;
  }
}
