import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/auth_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/app_theme.dart';

class ReceivePackageScreen extends StatefulWidget {
  const ReceivePackageScreen({super.key});

  @override
  State<ReceivePackageScreen> createState() => _ReceivePackageScreenState();
}

class _ReceivePackageScreenState extends State<ReceivePackageScreen> {
  final supabase = Supabase.instance.client;
  final RxSet<String> receivedOrderIds = <String>{}.obs;
  final RxSet<String> returnedOrderIds = <String>{}.obs;
  final RxString filterStatus = 'all'.obs;
  final AuthController authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _loadReceivedOrders();
  }

  Future<void> _loadReceivedOrders() async {
    try {
      // Ambil branch_id dari tabel branches berdasarkan user_id
      final branchData = await supabase
          .from('branches')
          .select('id')
          .eq('user_id', authController.currentUser.value!.id)
          .single();

      final receivedOrders = await supabase
          .from('branch_products')
          .select('order_id, status')
          .eq('branch_id', branchData['id'])
          .inFilter('status', const ['received', 'returned']);

      receivedOrderIds.clear();
      returnedOrderIds.clear();

      for (var order in receivedOrders) {
        if (order['status'] == 'received') {
          receivedOrderIds.add(order['order_id']);
        } else if (order['status'] == 'returned') {
          returnedOrderIds.add(order['order_id']);
        }
      }
    } catch (e) {
      print('Error loading received orders: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terima Paket'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Obx(() => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Semua'),
                        selected: filterStatus.value == 'all',
                        onSelected: (bool selected) {
                          if (selected) {
                            filterStatus.value = 'all';
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Diterima'),
                        selected: filterStatus.value == 'received',
                        onSelected: (bool selected) {
                          if (selected) {
                            filterStatus.value = 'received';
                            setState(() {});
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Ditolak'),
                        selected: filterStatus.value == 'returned',
                        onSelected: (bool selected) {
                          if (selected) {
                            filterStatus.value = 'returned';
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )),
        ),
      ),
      body: FutureBuilder<String>(
        future: _getBranchId(),
        builder: (context, branchSnapshot) {
          if (!branchSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase
                .from('branch_products')
                .stream(primaryKey: ['id'])
                .eq('branch_id', branchSnapshot.data!)
                .order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var filteredOrders = [...snapshot.data!];
              if (filterStatus.value != 'all') {
                filteredOrders = filteredOrders
                    .where((order) => order['status'] == filterStatus.value)
                    .toList();
              }

              if (filteredOrders.isEmpty) {
                return const Center(
                  child: Text('Tidak ada paket yang ditemukan'),
                );
              }

              return ListView.builder(
                itemCount: filteredOrders.length,
                itemBuilder: (context, index) {
                  final order = filteredOrders[index];
                  return _buildOrderCard(order);
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<String> _getBranchId() async {
    try {
      final branchData = await supabase
          .from('branches')
          .select('id')
          .eq('user_id', authController.currentUser.value!.id)
          .single();

      print('Branch ID: ${branchData['id']}'); // Debug print
      return branchData['id'];
    } catch (e) {
      print('Error getting branch ID: $e');
      rethrow;
    }
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Text('Order #${order['order_id'].toString().substring(0, 8)}'),
        subtitle: Text('Status: ${order['status'] ?? 'Menunggu'}'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<Map<String, dynamic>>(
              future: supabase.from('orders').select('''
                    *,
                    users:buyer_id(
                      id,
                      full_name,
                      phone,
                      address
                    )
                  ''').eq('id', order['order_id']).single(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Text('Loading...');
                final orderData = snapshot.data!;
                final userData = orderData['users'];
                final address = userData['address'] as Map;

                // Format alamat lengkap
                final fullAddress = [
                  address['street'],
                  address['village'],
                  address['district'],
                  address['city'],
                  address['province'],
                  address['postal_code'],
                ].where((e) => e != null && e.isNotEmpty).join(', ');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pembeli: ${userData['full_name']}'),
                    const SizedBox(height: 8),
                    Text('No. HP: ${userData['phone']}'),
                    const SizedBox(height: 8),
                    Text('Alamat: $fullAddress'),
                    const SizedBox(height: 16),
                    if (order['status'] == null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => _showActionDialog(order['id']),
                            child: const Text('Proses Paket'),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
        trailing: order['status'] == null
            ? const Icon(Icons.chevron_right)
            : Chip(
                label: Text(
                  order['status'] == 'received' ? 'Diterima' : 'Ditolak',
                ),
                backgroundColor:
                    order['status'] == 'received' ? Colors.green : Colors.red,
                labelStyle: const TextStyle(color: Colors.white),
              ),
      ),
    );
  }

  void _showActionDialog(String orderId) {
    Get.dialog(
      AlertDialog(
        title: const Text('Konfirmasi'),
        content: const Text('Pilih tindakan untuk paket ini'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
              _processPackageReturn(orderId);
            },
            child: const Text('Tolak', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _processPackageReceival(orderId);
            },
            child: const Text('Terima'),
          ),
        ],
      ),
    );
  }

  Future<void> _processPackageReceival(String orderId) async {
    try {
      print('Updating order $orderId to received'); // Log sebelum update
      final response = await supabase
          .from('branch_products')
          .update({'status': 'received'})
          .eq('id', orderId)
          .select();
      print('Update response: $response'); // Log response

      receivedOrderIds.add(orderId);
      await _loadReceivedOrders();

      Get.snackbar(
        'Sukses',
        'Paket berhasil diterima',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error receiving package: $e');
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _processPackageReturn(String orderId) async {
    try {
      print('Updating order $orderId to returned'); // Log sebelum update
      final response = await supabase
          .from('branch_products')
          .update({'status': 'returned'})
          .eq('id', orderId)
          .select();
      print('Update response: $response'); // Log response

      returnedOrderIds.add(orderId);
      await _loadReceivedOrders();

      Get.snackbar(
        'Info',
        'Paket ditolak',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error returning package: $e');
      Get.snackbar(
        'Error',
        e.toString(),
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
