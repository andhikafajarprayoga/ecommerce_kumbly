import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class BranchProductsScreen extends StatefulWidget {
  const BranchProductsScreen({Key? key}) : super(key: key);

  @override
  State<BranchProductsScreen> createState() => _BranchProductsScreenState();
}

class _BranchProductsScreenState extends State<BranchProductsScreen> {
  final _supabase = Supabase.instance.client;
  final RxList<Map<String, dynamic>> branchProducts =
      <Map<String, dynamic>>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchBranchProducts();
  }

  Future<void> _fetchBranchProducts() async {
    try {
      isLoading.value = true;
      final courierId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('branch_products')
          .select('''
            *,
            product:products (
              name,
              description,
              price
            ),
            branch:branches (
              name,
              address,
              phone
            ),
            order:orders (
              shipping_address,
              total_amount,
              buyer:users!buyer_id (
                full_name,
                phone
              )
            )
          ''')
          .eq('courier_id', courierId)
          .order('created_at', ascending: false);

      branchProducts.value = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching branch products: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data produk cabang',
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
        title: const Text('Paket dari Cabang'),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (branchProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Tidak ada paket dari cabang',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _fetchBranchProducts,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: branchProducts.length,
            itemBuilder: (context, index) {
              final item = branchProducts[index];
              final product = item['product'] as Map<String, dynamic>;
              final branch = item['branch'] as Map<String, dynamic>;
              final order = item['order'] as Map<String, dynamic>;
              final buyer = order['buyer'] as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'Order #${item['order_id'].toString().substring(0, 8)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  product['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusBadge(item['status']),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(height: 1),
                      ),
                      _buildInfoRow('Cabang', branch['name'], Icons.store),
                      _buildInfoRow('Jumlah', '${item['quantity']} unit',
                          Icons.shopping_basket),
                      _buildInfoRow(
                          'Pembeli', buyer['full_name'], Icons.person),
                      _buildInfoRow(
                          'Telepon Pembeli', buyer['phone'], Icons.phone),
                      _buildInfoRow('Alamat Pengiriman',
                          order['shipping_address'], Icons.location_on),
                      _buildInfoRow(
                        'Total Pesanan',
                        NumberFormat.currency(
                          locale: 'id_ID',
                          symbol: 'Rp ',
                          decimalDigits: 0,
                        ).format(order['total_amount']),
                        Icons.payment,
                      ),
                      _buildInfoRow(
                        'Tanggal',
                        DateFormat('dd MMM yyyy HH:mm').format(
                          DateTime.parse(item['created_at']),
                        ),
                        Icons.calendar_today,
                      ),
                      const SizedBox(height: 16),
                      if (item['status'] == 'received') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _startDelivery(item['id']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.local_shipping),
                            label: const Text('Mulai Pengiriman'),
                          ),
                        ),
                      ] else if (item['status'] == 'shipping') ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _completeDelivery(
                              orderId: item['order_id'],
                              branchProductId: item['id'],
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Selesai Pengiriman'),
                          ),
                        ),
                      ],
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

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
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
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;
    String text;
    IconData icon;

    switch (status) {
      case 'received':
        backgroundColor = Colors.orange.withOpacity(0.1);
        textColor = Colors.orange;
        text = 'Diterima';
        icon = Icons.inbox;
        break;
      case 'shipping':
        backgroundColor = Colors.blue.withOpacity(0.1);
        textColor = Colors.blue;
        text = 'Dikirim';
        icon = Icons.local_shipping;
        break;
      case 'delivered':
        backgroundColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        text = 'Terkirim';
        icon = Icons.check_circle;
        break;
      default:
        backgroundColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
        text = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDelivery(String branchProductId) async {
    try {
      // Update status di branch_products
      await _supabase
          .from('orders')
          .update({'status': 'delivered'}).eq('id', branchProductId);

      // Update status di orders
      final branchProduct =
          branchProducts.firstWhere((item) => item['id'] == branchProductId);
      await _supabase
          .from('orders')
          .update({'status': 'delivered'}).eq('id', branchProduct['order_id']);

      await _fetchBranchProducts();

      Get.snackbar(
        'Sukses',
        'Pengiriman dimulai',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error starting delivery: $e');
      Get.snackbar(
        'Error',
        'Gagal memulai pengiriman',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _completeDelivery({
    required String orderId,
    required String branchProductId,
  }) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);

      if (image == null) {
        Get.snackbar(
          'Error',
          'Mohon ambil foto bukti pengiriman',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      // Upload bukti pengiriman
      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final file = File(image.path);

      await _supabase.storage
          .from('products')
          .upload('shipping-proofs/$fileName', file);

      // Update status order dan branch product
      await _supabase.from('orders').update({
        'status': 'delivered',
        'shipping_proof': fileName,
      }).eq('id', orderId);

      await _supabase
          .from('branch_products')
          .update({'status': 'delivered'}).eq('id', branchProductId);

      await _fetchBranchProducts();

      Get.snackbar(
        'Sukses',
        'Pengiriman selesai',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error completing delivery: $e');
      Get.snackbar(
        'Error',
        'Gagal menyelesaikan pengiriman',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
