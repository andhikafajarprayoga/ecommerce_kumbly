import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddressController extends GetxController {
  final SupabaseClient _supabase = Supabase.instance.client;
  final RxBool isLoading = false.obs;
  final RxList addresses = <dynamic>[].obs;

  @override
  void onInit() {
    super.onInit();
    fetchAddresses(); // Ambil alamat saat controller diinisialisasi
  }

  Future<void> fetchAddresses() async {
    try {
      isLoading.value = true;

      final userId = _supabase.auth.currentUser?.id; // Ambil userId dari auth
      if (userId == null) return; // Pastikan userId tidak null

      final response = await _supabase
          .from('address') // Ganti dengan nama tabel yang sesuai
          .select()
          .eq('user_id', userId); // Filter berdasarkan userId

      addresses.value =
          List<Map<String, dynamic>>.from(response); // Simpan data alamat
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat alamat: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteAddress(int id) async {
    try {
      isLoading.value = true;
      await _supabase.from('address').delete().eq('id', id);
      addresses.removeWhere((address) => address['id'] == id);
      Get.snackbar('Sukses', 'Alamat berhasil dihapus');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menghapus alamat: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addAddress(Map<String, dynamic> data) async {
    try {
      isLoading.value = true;
      await _supabase.from('address').insert(data);
      Get.snackbar('Sukses', 'Alamat berhasil ditambahkan');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menambahkan alamat: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
