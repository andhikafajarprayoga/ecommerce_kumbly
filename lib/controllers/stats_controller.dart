import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatsController extends GetxController {
  final _supabase = Supabase.instance.client;

  final RxInt totalUsers = 0.obs;
  final RxInt totalStores = 0.obs;

  @override
  void onInit() {
    super.onInit();
    fetchStats();
  }

  Future<void> fetchStats() async {
    try {
      // Hitung total pengguna (buyer + seller)
      final usersCount = await _supabase
          .from('users')
          .count()
          .inFilter('role', ['buyer', 'seller']);

      // Hitung total toko (seller)
      final storesCount =
          await _supabase.from('users').count().eq('role', 'seller');

      totalUsers.value = usersCount;
      totalStores.value = storesCount;
    } catch (e) {
      print('Error fetching stats: $e');
    }
  }
}
