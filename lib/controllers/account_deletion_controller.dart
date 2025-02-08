import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account_deletion_request.dart';
import 'package:flutter/material.dart';

class AccountDeletionController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxList<AccountDeletionRequest> deletionRequests =
      <AccountDeletionRequest>[].obs;
  final RxBool isLoading = false.obs;
  final RxString searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchDeletionRequests();
  }

  Future<void> fetchDeletionRequests() async {
    isLoading.value = true;
    try {
      final response = await _supabase
          .from('account_deletion_requests')
          .select()
          .order('created_at', ascending: false);

      // Ubah query untuk mengambil data dari tabel users
      final userIds =
          response.map((r) => r['user_id'].toString()).toSet().toList();
      final usersResponse = await _supabase
          .from('users')
          .select('id, full_name')
          .inFilter('id', userIds);

      final userMap = {
        for (var user in usersResponse) user['id'].toString(): user
      };

      final enrichedResponse = response.map((request) {
        final userData = userMap[request['user_id'].toString()];
        return {
          ...request,
          'user_profile': {'full_name': userData?['full_name']},
        };
      }).toList();

      deletionRequests.value = enrichedResponse
          .map<AccountDeletionRequest>(
              (json) => AccountDeletionRequest.fromJson(json))
          .toList();
    } catch (e, stackTrace) {
      print('Error fetching data: $e');
      print('Stack trace: $stackTrace');
      Get.snackbar('Error', 'Gagal memuat data',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  List<AccountDeletionRequest> get filteredRequests {
    if (searchQuery.value.isEmpty) {
      return deletionRequests;
    }
    return deletionRequests
        .where((request) => (request.userName
                ?.toLowerCase()
                .contains(searchQuery.value.toLowerCase()) ??
            false))
        .toList();
  }

  Future<void> processRequest(String id, String status, String? notes) async {
    try {
      await _supabase.from('account_deletion_requests').update({
        'status': status,
        'processed_at': DateTime.now().toIso8601String(),
        'processed_by': _supabase.auth.currentUser!.id,
        'admin_notes': notes,
      }).eq('id', id);

      await fetchDeletionRequests();
      Get.back(); // Close dialog if any
      Get.snackbar(
        'Sukses',
        'Status permintaan berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Gagal memperbarui status',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
