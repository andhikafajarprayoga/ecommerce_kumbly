import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:convert';

class PickupBranchOrdersScreen extends StatefulWidget {
  const PickupBranchOrdersScreen({Key? key}) : super(key: key);

  @override
  State<PickupBranchOrdersScreen> createState() =>
      _PickupBranchOrdersScreenState();
}

class _PickupBranchOrdersScreenState extends State<PickupBranchOrdersScreen> {
  final _supabase = Supabase.instance.client;
  final RxMap<String, List<Map<String, dynamic>>> branchProducts =
      <String, List<Map<String, dynamic>>>{}.obs;
  final RxBool isLoading = true.obs;

  @override
  void initState() {
    super.initState();
    _fetchBranchProducts();
  }

  Future<void> _fetchBranchProducts() async {
    try {
      isLoading.value = true;

      final response = await _supabase
          .from('branch_products')
          .select('''
            *,
            branch:branches (
              id,
              name,
              address,
              phone
            ),
            product:products (
              id,
              name,
              price
            ),
            order:orders!inner (
              *,
              buyer:users (
                id,
                full_name
              )
            )
          ''')
          .eq('status', 'received')
          .filter('courier_id', 'is', null)
          .order('created_at', ascending: false);

      print('=== DEBUG RESPONSE ===');
      print('Raw response: $response');
      if (response.isNotEmpty) {
        print('=== First Order Data ===');
        print('Order details: ${response.first['order']}');
      }

      final groupedProducts = <String, List<Map<String, dynamic>>>{};
      for (var product in response) {
        final branchId = product['branch']['id'];
        if (!groupedProducts.containsKey(branchId)) {
          groupedProducts[branchId] = [];
        }
        groupedProducts[branchId]!.add(product);
      }

      branchProducts.value = groupedProducts;
    } catch (e) {
      print('Error fetching branch products: $e');
      Get.snackbar(
        'Error',
        'Gagal memuat data produk cabang',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jemput Paket Cabang'),
        elevation: 0,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.blue,
            ),
          );
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
                  'Tidak ada paket yang perlu dijemput',
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
              final branchId = branchProducts.keys.elementAt(index);
              final products = branchProducts[branchId]!;
              final branch = products.first['branch'];

              // Parse alamat branch dari JSON
              final address = Map<String, dynamic>.from(branch['address']);
              final formattedAddress = [
                address['street'],
                address['village'],
                address['district'],
                address['city'],
                address['province'],
              ].where((e) => e != null).join(', ');

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.white,
                          child: Icon(Icons.store, color: Colors.blue),
                        ),
                        title: Text(
                          branch['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alamat: $formattedAddress',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              'Telepon: ${branch['phone']}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, productIndex) {
                        final product = products[productIndex];

                        // Ambil alamat langsung dari shipping_address
                        String shippingAddress = '';
                        try {
                          final orderData = product['order'];
                          shippingAddress = orderData['shipping_address'] ?? '';
                        } catch (e) {
                          print('Error getting shipping address: $e');
                          print('Order data: ${product['order']}');
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.inventory,
                                        color: Colors.blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        product['product']['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16),
                                _buildInfoRow(
                                  Icons.numbers,
                                  'Order ID:',
                                  '#${product['order']['id'].toString().substring(0, 8)}',
                                ),
                                _buildInfoRow(
                                  Icons.person_outline,
                                  'Pembeli:',
                                  product['order']['buyer']['full_name'],
                                ),
                                if (shippingAddress.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  _buildInfoRow(
                                    Icons.location_on_outlined,
                                    'Alamat Pengiriman:',
                                    shippingAddress,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        // Dapatkan ID kurir yang sedang login
                                        final courierId =
                                            _supabase.auth.currentUser!.id;

                                        // Update courier_id saja di tabel branch_products
                                        await _supabase
                                            .from('branch_products')
                                            .update({'courier_id': courierId})
                                            .eq('id', product['id'])
                                            .eq('status', 'received');

                                        await _fetchBranchProducts();

                                        Get.snackbar(
                                          'Sukses',
                                          'Berhasil mengambil paket dari cabang',
                                          backgroundColor: Colors.green,
                                          colorText: Colors.white,
                                        );
                                      } catch (e) {
                                        print('Error taking product: $e');
                                        Get.snackbar(
                                          'Error',
                                          'Gagal mengambil paket',
                                          backgroundColor: Colors.red,
                                          colorText: Colors.white,
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.delivery_dining),
                                    label: const Text('Ambil Paket'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: Colors.grey[800]),
                children: [
                  TextSpan(
                    text: '$label ',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
