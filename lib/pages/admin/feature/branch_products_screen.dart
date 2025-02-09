import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
        title: Text('Daftar Cabang'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (controller.branches.isEmpty) {
          return Center(child: Text('Tidak ada data cabang'));
        }

        return ListView.builder(
          itemCount: controller.branches.length,
          itemBuilder: (context, index) {
            final branch = controller.branches[index];
            final address = Map<String, dynamic>.from(branch['address']);

            return Card(
              margin: EdgeInsets.all(8),
              child: ListTile(
                title: Text(branch['name']),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alamat: ${address['street']}, ${address['city']}'),
                    Text('Telepon: ${branch['phone']}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEditDialog(context, branch),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        Get.defaultDialog(
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
                        );
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Get.to(() => BranchDetailScreen(
                        branchId: branch['id'],
                        branchName: branch['name'],
                      ));
                },
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
      ),
      body: Obx(() {
        if (isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        if (branchProducts.isEmpty) {
          return Center(child: Text('Tidak ada data produk untuk cabang ini'));
        }

        return ListView.builder(
          itemCount: branchProducts.length,
          itemBuilder: (context, index) {
            final item = branchProducts[index];
            final product = item['products'] ?? {};
            final order = item['orders'] ?? {};
            final buyer = order['buyer'] ?? {};
            final paymentMethod = order['payment_methods'];

            return Card(
              margin: EdgeInsets.all(8),
              child: ExpansionTile(
                title: Text(product['name'] ?? 'Tidak ada nama'),
                subtitle: Text('Status Order: ${order['status'] ?? 'N/A'}'),
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Informasi Produk:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Harga: Rp${product['price'] ?? 0}'),
                        Text('Jumlah: ${item['quantity'] ?? 0}'),
                        SizedBox(height: 8),
                        Text('Informasi Order:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Order ID: ${order['id'] ?? 'N/A'}'),
                        if (order['created_at'] != null)
                          Text(
                              'Tanggal Order: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.parse(order['created_at']))}'),
                        Text(
                            'Total Pembayaran: Rp${order['total_amount'] ?? 0}'),
                        Text(
                            'Biaya Pengiriman: Rp${order['shipping_cost'] ?? 0}'),
                        Text('Status: ${order['status'] ?? 'N/A'}'),
                        if (order['keterangan'] != null)
                          Text('Keterangan: ${order['keterangan']}'),
                        SizedBox(height: 8),
                        Text('Informasi Pembeli:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Nama: ${buyer['full_name'] ?? 'N/A'}'),
                        Text('Email: ${buyer['email'] ?? 'N/A'}'),
                        Text('Telepon: ${buyer['phone'] ?? 'N/A'}'),
                        if (buyer['address'] != null) ...[
                          Text(
                              'Alamat: ${(buyer['address'] as Map)['street'] ?? ''}, ${(buyer['address'] as Map)['city'] ?? ''}'),
                        ],
                        Text(
                            'Alamat Pengiriman: ${order['shipping_address'] ?? 'N/A'}'),
                        SizedBox(height: 8),
                        Text('Informasi Pembayaran:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        if (paymentMethod != null) ...[
                          Text('Metode: ${paymentMethod['name'] ?? 'N/A'}'),
                          Text(
                              'Deskripsi: ${paymentMethod['description'] ?? 'N/A'}'),
                        ],
                        if (item['courier_id'] != null) ...[
                          SizedBox(height: 8),
                          Text('Informasi Pengiriman:',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Kurir: ${item['name_courier'] ?? 'N/A'}'),
                          if (order['transit'] != null)
                            Text(
                                'Transit: ${(order['transit'] as List).join(", ")}'),
                          if (order['courier_handover_photo'] != null)
                            Text('Foto Serah Terima: Ada'),
                          if (order['shipping_proofs'] != null)
                            Text('Bukti Pengiriman: Ada'),
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
}
