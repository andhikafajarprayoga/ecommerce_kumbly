import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kumbly_ecommerce/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BranchProductsController extends GetxController {
  final SupabaseClient supabase = Supabase.instance.client;
  final RxList<dynamic> branches = <dynamic>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchBranches();
  }

  Future<void> fetchBranches() async {
    try {
      isLoading(true);
      final response = await supabase.from('branches').select('''
            id,
            name,
            address,
            phone,
            created_at
          ''').order('name');

      print('Response: $response'); // untuk debugging
      branches.assignAll(response);
    } catch (e) {
      print('Error: $e');
      Get.snackbar('Error', 'Gagal mengambil data cabang');
    } finally {
      isLoading(false);
    }
  }

  Future<void> deleteBranch(String id) async {
    try {
      await supabase.from('branches').delete().match({'id': id});
      Get.snackbar('Sukses', 'Data cabang berhasil dihapus');
      fetchBranches(); // Refresh data setelah menghapus
    } catch (e) {
      print('Error: $e');
      Get.snackbar('Error', 'Gagal menghapus data cabang');
    }
  }

  Future<void> updateBranch(String id, Map<String, dynamic> data) async {
    try {
      await supabase.from('branches').update(data).match({'id': id});
      Get.snackbar('Sukses', 'Data cabang berhasil diperbarui');
      fetchBranches(); // Refresh data setelah update
    } catch (e) {
      print('Error: $e');
      Get.snackbar('Error', 'Gagal memperbarui data cabang');
    }
  }
}

class BranchProductsScreen extends StatelessWidget {
  final controller = Get.put(BranchProductsController());

  void _showEditDialog(BuildContext context, Map<String, dynamic> branch) {
    final nameController = TextEditingController(text: branch['name']);
    final phoneController = TextEditingController(text: branch['phone']);
    final streetController =
        TextEditingController(text: branch['address']['street']);
    final cityController =
        TextEditingController(text: branch['address']['city']);

    Get.dialog(
      AlertDialog(
        title: Text('Edit Cabang'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Nama Cabang'),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Telepon'),
              ),
              TextField(
                controller: streetController,
                decoration: InputDecoration(labelText: 'Alamat (Jalan)'),
              ),
              TextField(
                controller: cityController,
                decoration: InputDecoration(labelText: 'Kota'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedData = {
                'name': nameController.text,
                'phone': phoneController.text,
                'address': {
                  'street': streetController.text,
                  'city': cityController.text,
                }
              };
              controller.updateBranch(branch['id'], updatedData);
              Get.back();
            },
            child: Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Daftar Cabang',
          style: TextStyle(
            fontWeight: FontWeight.normal,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primary,
        elevation: 2,
        foregroundColor: Colors.white,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (controller.branches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Tidak ada data cabang',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: controller.branches.length,
          itemBuilder: (context, index) {
            final branch = controller.branches[index];
            final address = Map<String, dynamic>.from(branch['address']);

            return Card(
              elevation: 3,
              margin: EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Get.to(() => BranchDetailScreen(
                        branchId: branch['id'],
                        branchName: branch['name'],
                      ));
                },
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.store, color: Colors.blue[700]),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              branch['name'],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          PopupMenuButton(
                            icon: Icon(Icons.more_vert),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                child: ListTile(
                                  leading: Icon(Icons.edit, color: Colors.blue),
                                  title: Text('Edit'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onTap: () => Future.delayed(
                                  Duration.zero,
                                  () => _showEditDialog(context, branch),
                                ),
                              ),
                              PopupMenuItem(
                                child: ListTile(
                                  leading:
                                      Icon(Icons.delete, color: Colors.red),
                                  title: Text('Hapus'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onTap: () => Future.delayed(
                                  Duration.zero,
                                  () => Get.defaultDialog(
                                    title: 'Konfirmasi',
                                    middleText:
                                        'Apakah Anda yakin ingin menghapus cabang ini?',
                                    textConfirm: 'Ya',
                                    textCancel: 'Tidak',
                                    confirmTextColor: Colors.white,
                                    onConfirm: () {
                                      controller.deleteBranch(branch['id']);
                                      Get.back();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Divider(height: 24),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              color: Colors.grey[600], size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${address['street']}, ${address['city']}',
                              style: TextStyle(color: Colors.grey[700]),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, color: Colors.grey[600], size: 20),
                          SizedBox(width: 8),
                          Text(
                            branch['phone'],
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class BranchDetailScreen extends StatelessWidget {
  final String branchId;
  final String branchName;
  final SupabaseClient supabase = Supabase.instance.client;
  final RxList<dynamic> branchProducts = <dynamic>[].obs;
  final RxBool isLoading = false.obs;

  BranchDetailScreen({required this.branchId, required this.branchName});

  Future<void> fetchBranchProducts() async {
    try {
      isLoading(true);
      final response = await supabase.from('branch_products').select('''
            id,
            quantity,
            status,
            shipping_status,
            courier_id,
            name_courier,
            created_at,
            products:product_id (
              name,
              price,
              description
            ),
            orders:order_id (
              id,
              status,
              total_amount,
              shipping_address,
              created_at,
              shipping_cost,
              courier_handover_photo,
              shipping_proofs,
              transit,
              keterangan,
              buyer:buyer_id (
                email,
                full_name,
                phone,
                address
              ),
              payment_methods:payment_method_id (
                name,
                description
              )
            )
          ''').eq('branch_id', branchId).order('created_at', ascending: false);

      print('Branch Products Response: $response');
      branchProducts.assignAll(response);
    } catch (e) {
      print('Error: $e');
      Get.snackbar('Error', 'Gagal mengambil data produk cabang');
    } finally {
      isLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    fetchBranchProducts();

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Cabang: $branchName'),
        elevation: 2,
      ),
      body: Obx(() {
        if (isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (branchProducts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Tidak ada data produk untuk cabang ini',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(12),
          itemCount: branchProducts.length,
          itemBuilder: (context, index) {
            final item = branchProducts[index];
            final product = item['products'] ?? {};
            final order = item['orders'] ?? {};
            final buyer = order['buyer'] ?? {};
            final paymentMethod = order['payment_methods'];

            return Card(
              margin: EdgeInsets.only(bottom: 12),
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                title: Text(
                  product['name'] ?? 'Tidak ada nama',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order['status']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Status: ${order['status'] ?? 'N/A'}',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoSection(
                          'Informasi Produk',
                          [
                            _buildInfoRow(
                                'Harga', 'Rp${product['price'] ?? 0}'),
                            _buildInfoRow('Jumlah', '${item['quantity'] ?? 0}'),
                          ],
                        ),
                        Divider(height: 24),
                        _buildInfoSection(
                          'Informasi Order',
                          [
                            _buildInfoRow(
                                'Order ID', '${order['id'] ?? 'N/A'}'),
                            if (order['created_at'] != null)
                              _buildInfoRow(
                                'Tanggal Order',
                                DateFormat('dd MMM yyyy HH:mm').format(
                                  DateTime.parse(order['created_at']),
                                ),
                              ),
                            _buildInfoRow('Total Pembayaran',
                                'Rp${order['total_amount'] ?? 0}'),
                            _buildInfoRow('Biaya Pengiriman',
                                'Rp${order['shipping_cost'] ?? 0}'),
                            if (order['keterangan'] != null)
                              _buildInfoRow(
                                  'Keterangan', '${order['keterangan']}'),
                          ],
                        ),
                        Divider(height: 24),
                        _buildInfoSection(
                          'Informasi Pembeli',
                          [
                            _buildInfoRow(
                                'Nama', '${buyer['full_name'] ?? 'N/A'}'),
                            _buildInfoRow(
                                'Email', '${buyer['email'] ?? 'N/A'}'),
                            _buildInfoRow(
                                'Telepon', '${buyer['phone'] ?? 'N/A'}'),
                            if (buyer['address'] != null)
                              _buildInfoRow(
                                'Alamat',
                                '${(buyer['address'] as Map)['street'] ?? ''}, ${(buyer['address'] as Map)['city'] ?? ''}',
                              ),
                            _buildInfoRow('Alamat Pengiriman',
                                '${order['shipping_address'] ?? 'N/A'}'),
                          ],
                        ),
                        if (paymentMethod != null) ...[
                          Divider(height: 24),
                          _buildInfoSection(
                            'Informasi Pembayaran',
                            [
                              _buildInfoRow('Metode',
                                  '${paymentMethod['name'] ?? 'N/A'}'),
                              _buildInfoRow('Deskripsi',
                                  '${paymentMethod['description'] ?? 'N/A'}'),
                            ],
                          ),
                        ],
                        if (item['courier_id'] != null) ...[
                          Divider(height: 24),
                          _buildInfoSection(
                            'Informasi Pengiriman',
                            [
                              _buildInfoRow(
                                  'Kurir', '${item['name_courier'] ?? 'N/A'}'),
                              if (order['transit'] != null)
                                _buildInfoRow('Transit',
                                    '${(order['transit'] as List).join(", ")}'),
                              if (order['courier_handover_photo'] != null)
                                _buildInfoRow('Foto Serah Terima', 'Ada'),
                              if (order['shipping_proofs'] != null)
                                _buildInfoRow('Bukti Pengiriman', 'Ada'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[800],
          ),
        ),
        SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'processing':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
