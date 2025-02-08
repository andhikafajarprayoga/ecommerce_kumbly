import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MyPackagesScreen extends StatefulWidget {
  const MyPackagesScreen({Key? key}) : super(key: key);

  @override
  State<MyPackagesScreen> createState() => _MyPackagesScreenState();
}

class _MyPackagesScreenState extends State<MyPackagesScreen> {
  final _supabase = Supabase.instance.client;
  final RxList<Map<String, dynamic>> packages = <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchMyPackages();
  }

  Future<void> _fetchMyPackages() async {
    try {
      isLoading.value = true;
      final courierId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('orders')
          .select('''
            *,
            buyer:users!buyer_id (
              full_name,
              phone
            )
          ''')
          .eq('courier_id', courierId)
          .inFilter('status', ['processing', 'shipping'])
          .order('created_at', ascending: false);

      packages.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching packages: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data paket',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paket Saya'),
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (packages.isEmpty) {
          return const Center(
            child: Text('Tidak ada paket yang sedang dibawa'),
          );
        }

        return RefreshIndicator(
          onRefresh: _fetchMyPackages,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: packages.length,
            itemBuilder: (context, index) {
              final package = packages[index];
              final buyer = package['buyer'] as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Order #${package['id'].toString().substring(0, 8)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          _buildStatusChip(package['status']),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow('Pembeli', buyer['full_name'] ?? 'N/A'),
                      _buildInfoRow('Telepon', buyer['phone'] ?? 'N/A'),
                      _buildInfoRow('Alamat', package['shipping_address']),
                      _buildInfoRow(
                        'Total',
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(package['total_amount']),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'processing':
        color = Colors.orange;
        text = 'Diproses';
        break;
      case 'shipping':
        color = Colors.blue;
        text = 'Dikirim';
        break;
      default:
        color = Colors.grey;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
