import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatsController extends GetxController {
  final _supabase = Supabase.instance.client;

  final RxInt totalUsers = 0.obs;
  final RxInt totalStores = 0.obs;
  final _todayOrders = 0.obs;
  int get todayOrders => _todayOrders.value;

  @override
  void onInit() {
    super.onInit();
    fetchStats();
    fetchTodayOrders();
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

  Future<void> fetchTodayOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select('id')
          .gte(
              'created_at',
              DateTime.now()
                      .toUtc()
                      .subtract(Duration(
                          hours: 8)) // Menyesuaikan dengan WITA (UTC+8)
                      .toString()
                      .substring(0, 10) +
                  ' 00:00:00')
          .lte(
              'created_at',
              DateTime.now()
                      .toUtc()
                      .subtract(Duration(hours: 8))
                      .toString()
                      .substring(0, 10) +
                  ' 23:59:59');

      _todayOrders.value = (response as List).length;
    } catch (e) {
      print('Error fetching today orders: $e');
      _todayOrders.value = 0;
    }
  }
}
